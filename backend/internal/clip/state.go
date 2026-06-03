package clip

import (
	"context"
	"sync"
)

// JobStatus mewakili status sebuah job.
type JobStatus string

const (
	StatusProcessing JobStatus = "processing"
	StatusCompleted  JobStatus = "completed"
	StatusFailed     JobStatus = "failed"
)

// TranscriptChunk merepresentasikan potongan dari transcript penuh.
type TranscriptChunk struct {
	Text        string
	StartOffset int
	EndOffset   int
}

// ScoredChunk merepresentasikan chunk transcript yang sudah dinilai (heuristic).
type ScoredChunk struct {
	Chunk TranscriptChunk
	Score int
}

// Job menyimpan state untuk satu job.
type Job struct {
	ID           string             `json:"id"`
	OriginalURL  string             `json:"original_url"`
	Status       JobStatus          `json:"status"`
	VideoPaths   []string           `json:"video_paths,omitempty"`
	Error        string             `json:"error,omitempty"`
	SortedChunks []ScoredChunk      `json:"-"`
	NextChunkIdx int                `json:"-"`
	LayoutMode   string             `json:"-"`
	Cancel       context.CancelFunc `json:"-"`
}

// JobStore mengelola state pekerjaan secara aman untuk concurrent access.
type JobStore struct {
	mu   sync.RWMutex
	jobs map[string]*Job
}

// NewJobStore membuat dan menginisialisasi JobStore baru.
func NewJobStore() *JobStore {
	return &JobStore{
		jobs: make(map[string]*Job),
	}
}

// CreateJob mendaftarkan job baru ke dalam store dengan status "processing".
func (s *JobStore) CreateJob(id string, originalUrl string, cancel context.CancelFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.jobs[id] = &Job{
		ID:          id,
		OriginalURL: originalUrl,
		Status:      StatusProcessing,
		Cancel:      cancel,
	}
}

// GetJob mengembalikan salinan Job berdasarkan ID untuk mencegah race condition.
func (s *JobStore) GetJob(id string) (*Job, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	job, exists := s.jobs[id]
	if !exists {
		return nil, false
	}

	// Mengembalikan salinan (copy) struct
	jobCopy := *job
	return &jobCopy, true
}

// AddVideoPath menambahkan video path ke dalam job secara dinamis meskipun status masih processing.
func (s *JobStore) AddVideoPath(id string, videoPath string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.VideoPaths = append(job.VideoPaths, videoPath)
	}
}

// CompleteJob memperbarui status job menjadi "completed".
func (s *JobStore) CompleteJob(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.Status = StatusCompleted
	}
}

// FailJob memperbarui status job menjadi "failed" dan menyimpan pesan error.
func (s *JobStore) FailJob(id string, errMsg string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.Status = StatusFailed
		job.Error = errMsg
	}
}

// CancelJob triggers the context cancellation and marks the job as failed if it's still processing.
func (s *JobStore) CancelJob(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		if job.Cancel != nil {
			job.Cancel()
		}
		if job.Status == StatusProcessing {
			job.Status = StatusFailed
			job.Error = "Proses dibatalkan oleh pengguna"
		}
	}
}

// UpdateJobChunks menyimpan daftar chunk yang telah disortir dan mengatur indeks selanjutnya.
func (s *JobStore) UpdateJobChunks(id string, chunks []ScoredChunk, nextIdx int, layoutMode string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.SortedChunks = chunks
		job.NextChunkIdx = nextIdx
		job.LayoutMode = layoutMode
	}
}

// SetProcessing mengembalikan status job menjadi processing (saat di-resume).
func (s *JobStore) SetProcessing(id string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.Status = StatusProcessing
		job.Error = ""
	}
}

// IncrementNextChunkIdx menambahkan index chunk selanjutnya jika masih tersedia.
func (s *JobStore) IncrementNextChunkIdx(id string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		if job.NextChunkIdx < len(job.SortedChunks) {
			job.NextChunkIdx++
			return true
		}
	}
	return false
}
