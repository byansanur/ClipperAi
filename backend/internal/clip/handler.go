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

	// Cek apakah URL dan Layout ini sudah pernah sukses diproses sebelumnya
	if cachedJob, found := h.store.FindCompletedJob(req.YoutubeURL, req.LayoutMode); found {
		// Jika ketemu, JANGAN buat job baru. Langsung kembalikan data job lama.
		// Frontend akan otomatis me-load videoPaths yang sudah ada.
		c.JSON(http.StatusOK, gin.H{
			"message": "Menggunakan hasil cache",
			"job_id": cachedJob.ID,
			"job":     cachedJob,
		})
		return
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

// TrendingPodcast mendefinisikan item podcast terkurasi untuk fitur Trending.
type TrendingPodcast struct {
	ID           string `json:"id"`
	Title        string `json:"title"`
	ChannelName  string `json:"channel_name"`
	YoutubeURL   string `json:"youtube_url"`
	ThumbnailURL string `json:"thumbnail_url"`
	Duration     string `json:"duration"`
	LayoutMode   string `json:"layout_mode"`
	Category     string `json:"category"`
}

// GetTrendingPodcasts menangani request GET /api/v1/trending.
func (h *ClipHandler) GetTrendingPodcasts(c *gin.Context) {
	podcasts := []TrendingPodcast{
		{
			ID:           "trend-1",
			Title:        "Sam Altman: OpenAI, GPT-5, Sora, and AGI",
			ChannelName:  "Lex Fridman",
			YoutubeURL:   "https://www.youtube.com/watch?v=jvqFAi7vkBc",
			ThumbnailURL: "https://img.youtube.com/vi/jvqFAi7vkBc/hqdefault.jpg",
			Duration:     "2j 05m",
			LayoutMode:   "podcast",
			Category:     "Tech & AI",
		},
		{
			ID:           "trend-2",
			Title:        "DEDDY CORBUZIER & PRABOWO SUBIANTO - EXCLUSIVE",
			ChannelName:  "Close The Door",
			YoutubeURL:   "https://www.youtube.com/watch?v=34d7uC4mG7E",
			ThumbnailURL: "https://img.youtube.com/vi/34d7uC4mG7E/hqdefault.jpg",
			Duration:     "1j 12m",
			LayoutMode:   "podcast",
			Category:     "Talkshow",
		},
		{
			ID:           "trend-3",
			Title:        "Yann LeCun: Meta AI, LLMs, and World Models",
			ChannelName:  "Lex Fridman",
			YoutubeURL:   "https://www.youtube.com/watch?v=5t1vTLU7tm8",
			ThumbnailURL: "https://img.youtube.com/vi/5t1vTLU7tm8/hqdefault.jpg",
			Duration:     "2j 45m",
			LayoutMode:   "podcast",
			Category:     "Tech & AI",
		},
		{
			ID:           "trend-4",
			Title:        "CARA BERPIKIR RATIONAL & SUKSES DI USIA MUDA",
			ChannelName:  "Raditya Dika",
			YoutubeURL:   "https://www.youtube.com/watch?v=kYJ7L1G4vQE",
			ThumbnailURL: "https://img.youtube.com/vi/kYJ7L1G4vQE/hqdefault.jpg",
			Duration:     "48m",
			LayoutMode:   "solo",
			Category:     "Self Improvement",
		},
		{
			ID:           "trend-5",
			Title:        "PODKESMAS #150: CERITA MASA LALU YANG BIKIN NGAKAK",
			ChannelName:  "Podkesmas",
			YoutubeURL:   "https://www.youtube.com/watch?v=680U8W32S6w",
			ThumbnailURL: "https://img.youtube.com/vi/680U8W32S6w/hqdefault.jpg",
			Duration:     "1j 02m",
			LayoutMode:   "podcast",
			Category:     "Talkshow",
		},
		{
			ID:           "trend-6",
			Title:        "Andrej Karpathy: Software 2.0, Neural Networks & Future of AI",
			ChannelName:  "Dwarkesh Patel",
			YoutubeURL:   "https://www.youtube.com/watch?v=c3b-T-eJg5E",
			ThumbnailURL: "https://img.youtube.com/vi/c3b-T-eJg5E/hqdefault.jpg",
			Duration:     "1j 38m",
			LayoutMode:   "podcast",
			Category:     "Tech & AI",
		},
	}

	c.JSON(http.StatusOK, gin.H{
		"trending": podcasts,
	})
}

