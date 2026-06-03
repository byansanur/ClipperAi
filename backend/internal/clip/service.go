package clip

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/sgo-byan/clipperai/internal/pkg/ffmpeg"
	"github.com/sgo-byan/clipperai/internal/pkg/ollama"
)

// (Moved TranscriptChunk and ScoredChunk to state.go)

// Membatasi proses berat (LLM & FFmpeg) maksimal 1 dalam satu waktu
var processingSemaphore = make(chan struct{}, 1)

// ClipService menangani orchestrasi pemrosesan clip.
type ClipService struct {
	store        *JobStore
	ollamaClient *ollama.Client
	outputDir    string
}

// NewClipService membuat instance ClipService baru.
func NewClipService(store *JobStore, ollamaClient *ollama.Client, outputDir string) *ClipService {
	if outputDir == "" {
		outputDir = "outputs"
	}
	return &ClipService{
		store:        store,
		ollamaClient: ollamaClient,
		outputDir:    outputDir,
	}
}

// ProcessClip adalah fungsi utama untuk memproses video YouTube menjadi clip.
// Dijalankan di goroutine secara asynchronous.
func (s *ClipService) ProcessClip(ctx context.Context, cancel context.CancelFunc, jobID string, youtubeURL string, layoutMode string) {
	defer cancel() // Bebaskan resource context saat goroutine selesai

	// Wajib defer recover untuk mencegah server crash akibat panic.
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[SERVICE] Panic recovered in background job %s: %v", jobID, r)
			s.store.FailJob(jobID, humanizeError("Internal server error during processing"))
		}
	}()

	log.Printf("[SERVICE] Starting job %s for URL %s", jobID, youtubeURL)

	// 1. Masuk ke antrean (akan nge-block jika loket sedang dipakai)
	processingSemaphore <- struct{}{}

	// 2. Pastikan loket dilepas kembali saat fungsi selesai/gagal
	defer func() {
		<-processingSemaphore
	}()

	// Step 2: Fetch transcript
	transcript, err := ffmpeg.FetchTranscript(ctx, youtubeURL, s.outputDir)
	if err != nil {
		s.store.FailJob(jobID, humanizeError(fmt.Errorf("failed to fetch transcript: %w", err).Error()))
		return
	}

	// Step 3: Chunk transcript (5 menit = ~750 kata)
	chunks := chunkTranscript(transcript, 5)
	if len(chunks) == 0 {
		s.store.FailJob(jobID, humanizeError("transcript is empty or could not be chunked"))
		return
	}

	// Step 4: Score chunks
	scoredChunks := scoreChunks(chunks)

	// Step 5: Download video dengan yt-dlp sekali di awal
	tempPath := filepath.Join(s.outputDir, fmt.Sprintf("temp_%s.mp4", jobID))
	if err := ffmpeg.DownloadVideo(ctx, youtubeURL, tempPath); err != nil {
		s.store.FailJob(jobID, humanizeError(fmt.Errorf("failed to download video: %w", err).Error()))
		return
	}
	defer os.Remove(tempPath)

	// Simpan chunk untuk Generate More
	s.store.UpdateJobChunks(jobID, scoredChunks, 1, layoutMode) // index 1 karena 0 diproses sekarang

	successCount := 0

	// Proses index 0 saja
	topChunk := scoredChunks[0].Chunk.Text

	// Step 6: LLM call menggunakan Ollama
	clipTs, err := s.ollamaClient.FindTimestamps(ctx, topChunk)
	var safeFfmpegStart, safeFfmpegEnd string
	var startSec, endSec int

	if err != nil {
		log.Printf("[SERVICE] LLM failed to find timestamps for job %s: %v. Using fallback.", jobID, err)
		startSec = scoredChunks[0].Chunk.StartOffset
		endSec = scoredChunks[0].Chunk.StartOffset + 60
		safeFfmpegStart = secondsToFFmpegTime(startSec)
		safeFfmpegEnd = secondsToFFmpegTime(endSec)
	} else {
		// Step 7: Normalisasi Timestamp dan konversi format
		startSec, err = parseTimeToSeconds(clipTs.StartTime)
		if err != nil {
			startSec = scoredChunks[0].Chunk.StartOffset
		}
		endSec, err = parseTimeToSeconds(clipTs.EndTime)
		if err != nil {
			endSec = startSec + 60
		}

		// Validasi dan batasan durasi clip 60-90 detik
		duration := endSec - startSec
		if duration < 30 {
			endSec = startSec + 60
		} else if duration > 90 {
			endSec = startSec + 90
		}

		safeFfmpegStart = secondsToFFmpegTime(startSec)
		safeFfmpegEnd = secondsToFFmpegTime(endSec)
	}

	clipDuration := endSec - startSec
	if startSec < endSec && clipDuration >= 10 && clipDuration <= 120 {
		log.Printf("[SERVICE] Validated timestamps for chunk 0: %s to %s (duration: %ds)", safeFfmpegStart, safeFfmpegEnd, clipDuration)

		// Step 8: Slice & crop video menjadi 9:16 vertikal
		outputPath := filepath.Join(s.outputDir, fmt.Sprintf("output_clip_%s_0.mp4", jobID))
		if err := ffmpeg.SliceAndCrop(ctx, tempPath, outputPath, safeFfmpegStart, safeFfmpegEnd, layoutMode); err == nil {
			relativeURL := fmt.Sprintf("/outputs/output_clip_%s_0.mp4", jobID)
			s.store.AddVideoPath(jobID, relativeURL)
			successCount++
		} else {
			log.Printf("[SERVICE] failed to slice and crop video for job %s, chunk 0: %v", jobID, err)
		}
	}

	// Step 9: Update state menjadi completed
	if successCount > 0 {
		log.Printf("[SERVICE] Job %s initial clip completed successfully", jobID)
		s.store.CompleteJob(jobID)
	} else {
		s.store.FailJob(jobID, humanizeError("Failed to generate the initial clip"))
	}
}

// ProcessNextClip memproses chunk berikutnya dari job yang sudah ada.
func (s *ClipService) ProcessNextClip(ctx context.Context, jobID string, nextIdx int) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[SERVICE] Panic recovered in ProcessNextClip job %s: %v", jobID, r)
			s.store.FailJob(jobID, humanizeError("Internal server error during processing next clip"))
		}
	}()

	// 1. Masuk ke antrean (akan nge-block jika loket sedang dipakai)
	processingSemaphore <- struct{}{}
	defer func() {
		<-processingSemaphore
	}()

	job, exists := s.store.GetJob(jobID)
	if !exists {
		return // Job sudah tidak ada
	}

	if nextIdx >= len(job.SortedChunks) {
		s.store.FailJob(jobID, "Tidak ada momen menarik lagi")
		return
	}

	chunk := job.SortedChunks[nextIdx]
	layoutMode := job.LayoutMode
	if layoutMode == "" {
		layoutMode = "solo"
	}

	log.Printf("[SERVICE] Starting to generate next clip for job %s, index %d", jobID, nextIdx)

	// Step 1: LLM call menggunakan Ollama
	clipTs, err := s.ollamaClient.FindTimestamps(ctx, chunk.Chunk.Text)
	var safeFfmpegStart, safeFfmpegEnd string
	var startSec, endSec int

	if err != nil {
		log.Printf("[SERVICE] LLM failed to find timestamps for job %s next clip: %v. Using fallback.", jobID, err)
		startSec = chunk.Chunk.StartOffset
		endSec = chunk.Chunk.StartOffset + 60
		safeFfmpegStart = secondsToFFmpegTime(startSec)
		safeFfmpegEnd = secondsToFFmpegTime(endSec)
	} else {
		startSec, err = parseTimeToSeconds(clipTs.StartTime)
		if err != nil {
			startSec = chunk.Chunk.StartOffset
		}
		endSec, err = parseTimeToSeconds(clipTs.EndTime)
		if err != nil {
			endSec = startSec + 60
		}

		duration := endSec - startSec
		if duration < 30 {
			endSec = startSec + 60
		} else if duration > 90 {
			endSec = startSec + 90
		}

		safeFfmpegStart = secondsToFFmpegTime(startSec)
		safeFfmpegEnd = secondsToFFmpegTime(endSec)
	}

	clipDuration := endSec - startSec
	if startSec >= endSec || clipDuration < 10 || clipDuration > 120 {
		s.store.FailJob(jobID, "Durasi klip tidak valid dari hasil AI")
		return
	}

	// Step 2: Download ulang video master untuk clip ini agar menghemat disk space 
	// (trade-off: menggunakan lebih banyak bandwidth/waktu)
	tempPath := filepath.Join(s.outputDir, fmt.Sprintf("temp_%s_next_%d.mp4", jobID, nextIdx))
	if err := ffmpeg.DownloadVideo(ctx, job.OriginalURL, tempPath); err != nil {
		log.Printf("[SERVICE] Failed to redownload video for next clip job %s: %v", jobID, err)
		s.store.FailJob(jobID, "Gagal mengunduh ulang video dari YouTube")
		return
	}
	defer os.Remove(tempPath)

	// Step 3: Slice & crop video menjadi 9:16 vertikal
	outputPath := filepath.Join(s.outputDir, fmt.Sprintf("output_clip_%s_%d.mp4", jobID, nextIdx))
	if err := ffmpeg.SliceAndCrop(ctx, tempPath, outputPath, safeFfmpegStart, safeFfmpegEnd, layoutMode); err != nil {
		log.Printf("[SERVICE] failed to slice and crop video for job %s next clip: %v", jobID, err)
		s.store.FailJob(jobID, "Gagal memotong klip video")
		return
	}

	relativeURL := fmt.Sprintf("/outputs/output_clip_%s_%d.mp4", jobID, nextIdx)
	s.store.AddVideoPath(jobID, relativeURL)

	log.Printf("[SERVICE] Job %s next clip (%d) completed successfully", jobID, nextIdx)
	s.store.CompleteJob(jobID)
}
