package clip

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/sgo-byan/clipperai/internal/pkg/ffmpeg"
	"github.com/sgo-byan/clipperai/internal/pkg/ollama"
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
			s.store.FailJob(jobID, "Internal server error during processing")
		}
	}()

	log.Printf("[SERVICE] Starting job %s for URL %s", jobID, youtubeURL)

	// Step 2: Fetch transcript
	transcript, err := ffmpeg.FetchTranscript(ctx, youtubeURL, s.outputDir)
	if err != nil {
		s.store.FailJob(jobID, fmt.Errorf("failed to fetch transcript: %w", err).Error())
		return
	}

	// Step 3: Chunk transcript (5 menit = ~750 kata)
	chunks := chunkTranscript(transcript, 5)
	if len(chunks) == 0 {
		s.store.FailJob(jobID, "transcript is empty or could not be chunked")
		return
	}

	// Step 4: Score chunks dan ambil top 1
	scoredChunks := scoreChunks(chunks)
	topChunk := scoredChunks[0].Chunk.Text

	// Step 5: LLM call menggunakan Ollama
	clipTs, err := s.ollamaClient.FindTimestamps(ctx, topChunk)
	if err != nil {
		s.store.FailJob(jobID, fmt.Errorf("LLM failed to find timestamps: %w", err).Error())
		return
	}

	// Step 6: Konversi timestamp untuk FFmpeg
	startSec, err := parseTimeToSeconds(clipTs.StartTime)
	if err != nil {
		s.store.FailJob(jobID, fmt.Errorf("invalid start time from LLM: %w", err).Error())
		return
	}
	endSec, err := parseTimeToSeconds(clipTs.EndTime)
	if err != nil {
		s.store.FailJob(jobID, fmt.Errorf("invalid end time from LLM: %w", err).Error())
		return
	}

	safeFfmpegStart := secondsToFFmpegTime(startSec)
	safeFfmpegEnd := secondsToFFmpegTime(endSec)

	// Validasi: start harus lebih kecil dari end, durasi antara 10-120 detik
	clipDuration := endSec - startSec
	if startSec >= endSec {
		s.store.FailJob(jobID, fmt.Sprintf("invalid timestamps from LLM: start (%s) >= end (%s)", safeFfmpegStart, safeFfmpegEnd))
		return
	}
	if clipDuration < 10 || clipDuration > 120 {
		s.store.FailJob(jobID, fmt.Sprintf("clip duration %d seconds is out of range (10-120s), timestamps: %s to %s", clipDuration, safeFfmpegStart, safeFfmpegEnd))
		return
	}
	log.Printf("[SERVICE] Validated timestamps: %s to %s (duration: %ds)", safeFfmpegStart, safeFfmpegEnd, clipDuration)

	// Step 7: Download video dengan yt-dlp
	tempPath := filepath.Join(s.outputDir, fmt.Sprintf("temp_%s.mp4", jobID))
	if err := ffmpeg.DownloadVideo(ctx, youtubeURL, tempPath); err != nil {
		s.store.FailJob(jobID, fmt.Errorf("failed to download video: %w", err).Error())
		return
	}
	defer os.Remove(tempPath)

	// Step 8: Slice & crop video menjadi 9:16 vertikal
	outputPath := filepath.Join(s.outputDir, fmt.Sprintf("output_clip_%s.mp4", jobID))
	if err := ffmpeg.SliceAndCrop(ctx, tempPath, outputPath, safeFfmpegStart, safeFfmpegEnd, layoutMode); err != nil {
		s.store.FailJob(jobID, fmt.Errorf("failed to slice and crop video: %w", err).Error())
		return
	}

	// Step 9: Update state menjadi completed dengan URL relative
	log.Printf("[SERVICE] Job %s completed successfully", jobID)
	relativeURL := fmt.Sprintf("/outputs/output_clip_%s.mp4", jobID)
	s.store.CompleteJob(jobID, relativeURL)
}

// chunkTranscript memecah teks berdasarkan jumlah menit estimasi (1 menit = ~150 kata).
func chunkTranscript(transcript string, minutesPerChunk int) []TranscriptChunk {
	words := strings.Fields(transcript)
	wordsPerChunk := minutesPerChunk * 150

	var chunks []TranscriptChunk
	for i := 0; i < len(words); i += wordsPerChunk {
		end := i + wordsPerChunk
		if end > len(words) {
			end = len(words)
		}
		chunk := TranscriptChunk{
			Text: strings.Join(words[i:end], " "),
		}
		chunks = append(chunks, chunk)
	}
	return chunks
}

// scoreChunks memberi nilai heuristic ke setiap potongan transcript.
func scoreChunks(chunks []TranscriptChunk) []ScoredChunk {
	keywords := []string{"tapi", "masalahnya", "gila", "sebenarnya", "ternyata", "wow", "amazing", "shocking", "seriously", "actually", "honestly", "crazy"}
	var scored []ScoredChunk

	for _, chunk := range chunks {
		score := 0
		lowerText := strings.ToLower(chunk.Text)

		score += strings.Count(chunk.Text, "?") * 3
		score += strings.Count(chunk.Text, "!") * 2

		for _, kw := range keywords {
			score += strings.Count(lowerText, kw) * 2
		}

		scored = append(scored, ScoredChunk{
			Chunk: chunk,
			Score: score,
		})
	}

	// Sort secara descending (skor tertinggi pertama)
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})

	return scored
}

// parseTimeToSeconds mengubah string timestamp menjadi total detik integer.
func parseTimeToSeconds(timestamp string) (int, error) {
	// Support untuk format detik murni
	if sec, err := strconv.Atoi(timestamp); err == nil {
		return sec, nil
	}

	parts := strings.Split(timestamp, ":")
	if len(parts) == 3 {
		// Format HH:MM:SS
		h, _ := strconv.Atoi(parts[0])
		m, _ := strconv.Atoi(parts[1])
		s, _ := strconv.Atoi(parts[2])
		return h*3600 + m*60 + s, nil
	} else if len(parts) == 2 {
		// Format MM:SS
		m, _ := strconv.Atoi(parts[0])
		s, _ := strconv.Atoi(parts[1])
		return m*60 + s, nil
	}

	return 0, fmt.Errorf("invalid time format: %s", timestamp)
}

// secondsToFFmpegTime merubah integer total detik menjadi string HH:MM:SS.
func secondsToFFmpegTime(seconds int) string {
	h := seconds / 3600
	m := (seconds % 3600) / 60
	s := seconds % 60
	return fmt.Sprintf("%02d:%02d:%02d", h, m, s)
}
