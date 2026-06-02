package clip

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ClipRequest mendefinisikan payload untuk submit video.
type ClipRequest struct {
	YoutubeURL string `json:"youtube_url"`
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

	jobID := uuid.New().String()
	h.store.CreateJob(jobID)

	// Mulai pemrosesan di background
	go h.service.ProcessClip(jobID, req.YoutubeURL)

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
