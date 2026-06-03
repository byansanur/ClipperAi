package clip

import (
	"fmt"
	"sort"
	"strconv"
	"strings"
)

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
			Text:        strings.Join(words[i:end], " "),
			StartOffset: (i / 150) * 60,
			EndOffset:   (end / 150) * 60,
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
		score += len(chunk.Text) / 50 // Base Score berdasar kepadatan teks

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

// humanizeError menyaring pesan log CLI mentah menjadi pesan error manusia yang bisa dibaca.
func humanizeError(rawError string) string {
	errLower := strings.ToLower(rawError)
	
	if strings.Contains(errLower, "429") || strings.Contains(errLower, "too many requests") {
		return "Sistem YouTube membatasi akses sementara karena terlalu banyak permintaan. Silakan coba lagi dalam 10-15 menit."
	}
	if strings.Contains(errLower, "sign in to confirm your age") || strings.Contains(errLower, "age restricted") {
		return "Video ini memiliki batasan usia dan tidak dapat diproses oleh sistem kami."
	}
	if strings.Contains(errLower, "video unavailable") || strings.Contains(errLower, "private video") {
		return "Video tidak ditemukan atau bersifat privat."
	}
	if strings.Contains(errLower, "subtitles") && strings.Contains(errLower, "unable to download") {
		return "Gagal mengambil transkrip otomatis dari video ini. Pastikan video memiliki suara percakapan yang jelas."
	}
	if strings.Contains(errLower, "signal: killed") {
		return "Proses pemotongan video dihentikan karena memakan waktu terlalu lama. Silakan coba video dengan durasi lebih pendek."
	}
	
	// Fallback error umum
	return "Terjadi kendala teknis saat memproses video. Pastikan tautan YouTube valid dan coba beberapa saat lagi."
}
