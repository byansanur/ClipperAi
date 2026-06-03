package clip

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ClipRequest mendefinisikan payload untuk submit video.
type ClipRequest struct {
	YoutubeURL string `json:"youtube_url"`
	LayoutMode string `json:"layout_mode"` // default ke "solo" jika kosong
}

// ClipResponse mendefinisikan response ketika submit berhasil.
type ClipResponse struct {
	JobID string `json:"job_id"`
}

// ClipHandler menangani HTTP request terkait clips.
type ClipHandler struct {
	store   *JobStore
	service *ClipService
}

// NewClipHandler menginisialisasi handler dengan dependensi yang dibutuhkan.
func NewClipHandler(store *JobStore, service *ClipService) *ClipHandler {
	return &ClipHandler{
		store:   store,
		service: service,
	}
}

// SubmitClip menangani request POST /api/v1/clips.
func (h *ClipHandler) SubmitClip(c *gin.Context) {
	var req ClipRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON body"})
		return
	}

	if req.YoutubeURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "youtube_url is required"})
		return
	}

	if req.LayoutMode == "" {
		req.LayoutMode = "solo"
	}

	jobID := uuid.New().String()
	
	// Buat context dengan timeout 10 menit untuk proses keseluruhan
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	
	h.store.CreateJob(jobID, req.YoutubeURL, cancel)

	// Mulai pemrosesan di background dengan context
	go h.service.ProcessClip(ctx, cancel, jobID, req.YoutubeURL, req.LayoutMode)

	c.JSON(http.StatusAccepted, ClipResponse{
		JobID: jobID,
	})
}

// GetClipStatus menangani request GET /api/v1/clips/:id.
func (h *ClipHandler) GetClipStatus(c *gin.Context) {
	id := c.Param("id")

	job, exists := h.store.GetJob(id)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Job not found"})
		return
	}

	c.JSON(http.StatusOK, job)
}

// CancelClip menangani request DELETE /api/v1/clips/:id untuk membatalkan proses
func (h *ClipHandler) CancelClip(c *gin.Context) {
	id := c.Param("id")

	if _, exists := h.store.GetJob(id); !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Job not found"})
		return
	}

	h.store.CancelJob(id)
	c.JSON(http.StatusOK, gin.H{"message": "Job cancellation requested successfully"})
}

// GenerateNextClip menangani request POST /api/v1/clips/:id/next
func (h *ClipHandler) GenerateNextClip(c *gin.Context) {
	id := c.Param("id")

	job, exists := h.store.GetJob(id)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Job not found"})
		return
	}

	if job.NextChunkIdx >= len(job.SortedChunks) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Tidak ada momen menarik lagi"})
		return
	}

	// Ubah status kembali menjadi processing
	h.store.SetProcessing(id)

	// Buat context dengan timeout baru
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	
	// Simpan fungsi cancel yang baru (tapi saat ini di state.go fungsi SetProcessing tidak menimpa cancel, 
	// ideally cancel context perlu diupdate, tapi kita akan handle lewat context parameter)
	
	// Increment counter index
	if h.store.IncrementNextChunkIdx(id) {
		// Panggil service untuk memproses chunk ini di background
		go func() {
			defer cancel()
			// Kita passing NextChunkIdx yang lama (sebelum di-increment)
			h.service.ProcessNextClip(ctx, id, job.NextChunkIdx)
		}()
	} else {
		cancel()
	}

	c.JSON(http.StatusAccepted, gin.H{
		"message": "Processing next clip started",
	})
}
