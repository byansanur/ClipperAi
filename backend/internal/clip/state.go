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

// Job menyimpan state untuk satu job.
type Job struct {
	ID        string             `json:"id"`
	Status    JobStatus          `json:"status"`
	VideoPath string             `json:"video_path,omitempty"`
	Error     string             `json:"error,omitempty"`
	Cancel    context.CancelFunc `json:"-"`
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
func (s *JobStore) CreateJob(id string, cancel context.CancelFunc) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.jobs[id] = &Job{
		ID:     id,
		Status: StatusProcessing,
		Cancel: cancel,
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

// CompleteJob memperbarui status job menjadi "completed" dan menyimpan path video.
func (s *JobStore) CompleteJob(id string, videoPath string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if job, exists := s.jobs[id]; exists {
		job.Status = StatusCompleted
		job.VideoPath = videoPath
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
