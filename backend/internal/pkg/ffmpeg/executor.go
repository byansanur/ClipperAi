package ffmpeg

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/google/uuid"
)

// DownloadVideo mendownload video YouTube sebagai file MP4.
func DownloadVideo(ctx context.Context, youtubeURL string, outputPath string) error {
	log.Printf("[FFMPEG] Starting video download for %s to %s", youtubeURL, outputPath)

	cmd := exec.CommandContext(ctx, "yt-dlp",
		"-f", "best[ext=mp4]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best",
		"--merge-output-format", "mp4",
		"--no-playlist",
		"-o", outputPath,
		youtubeURL,
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("yt-dlp download failed: %w (output: %s)", err, string(output))
	}

	// Verifikasi file benar-benar ada dan berukuran > 0
	info, err := os.Stat(outputPath)
	if err != nil {
		return fmt.Errorf("downloaded video file not found at %s: %w", outputPath, err)
	}
	if info.Size() == 0 {
		return fmt.Errorf("downloaded video file is empty (0 bytes) at %s", outputPath)
	}

	log.Printf("[FFMPEG] Video downloaded successfully to %s (%d bytes)", outputPath, info.Size())
	return nil
}

// SliceAndCrop memotong video dan mengubah aspect ratio menjadi 9:16.
func SliceAndCrop(ctx context.Context, inputPath string, outputPath string, startTime string, endTime string, layoutMode string) error {
	log.Printf("[FFMPEG] Slicing video from %s to %s for %s with layout %s", startTime, endTime, inputPath, layoutMode)

	// Verifikasi input file ada dan berukuran wajar sebelum memulai ffmpeg
	info, err := os.Stat(inputPath)
	if err != nil {
		return fmt.Errorf("input video file not found at %s: %w", inputPath, err)
	}
	log.Printf("[FFMPEG] Input file size: %d bytes", info.Size())

	args := []string{"-y"}

	// 1. Hardware Acceleration (Hanya untuk macOS)
	if runtime.GOOS == "darwin" {
		args = append(args, "-hwaccel", "videotoolbox")
	}

	// 2. Input File & Timing
	args = append(args, "-ss", startTime, "-to", endTime, "-i", inputPath)

	// 3. Filter berdasarkan Layout Mode
	switch layoutMode {
	case "presentation":
		args = append(args, "-filter_complex", "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,scale=270:480,boxblur=10:10,scale=1080:1920[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,format=yuv420p")
	case "podcast":
		args = append(args, "-filter_complex", "[0:v]crop=iw/2:ih:0:0[left]; [0:v]crop=iw/2:ih:iw/2:0[right]; [left][right]vstack[stacked]; [stacked]scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,format=yuv420p")
	default: // solo
		args = append(args, "-vf", "crop=ih*9/16:ih,format=yuv420p")
	}

	// 4. Encoder Video Dinamis berdasarkan OS
	if runtime.GOOS == "darwin" {
		// Jalur Eksekutif: Akselerasi Hardware M1/M2/M3
		args = append(args,
			"-c:v", "h264_videotoolbox",
			"-b:v", "3M", // Bitrate 3 Mbps untuk kualitas Vertical Clip
		)
	} else {
		// Jalur Produksi Server: Linux VPS (Software Encoding)
		args = append(args,
			"-c:v", "libx264",
			"-crf", "23",
			"-preset", "veryfast", // Menghemat CPU agar tidak OOM/Timeout di VPS
		)
	}

	// 5. Audio & Output Final
	args = append(args,
		"-c:a", "aac",
		"-b:a", "128k",
		"-movflags", "+faststart",
		outputPath,
	)

	cmd := exec.CommandContext(ctx, "ffmpeg", args...)

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg slice and crop failed: %w (output: %s)", err, string(output))
	}

	// Verifikasi output
	outInfo, err := os.Stat(outputPath)
	if err != nil {
		return fmt.Errorf("output clip file not found after ffmpeg: %w", err)
	}
	if outInfo.Size() < 1000 {
		return fmt.Errorf("output clip file is suspiciously small (%d bytes), ffmpeg may have failed silently", outInfo.Size())
	}

	log.Printf("[FFMPEG] Video sliced and cropped successfully to %s (%d bytes)", outputPath, outInfo.Size())
	return nil
}

// FetchTranscript mengambil transcript video YouTube dalam bentuk plain text.
func FetchTranscript(ctx context.Context, youtubeURL string, outputDir string) (string, error) {
	log.Printf("[FFMPEG] Fetching transcript for %s", youtubeURL)

	tempUUID := uuid.New().String()
	basePath := filepath.Join(outputDir, "transcript_"+tempUUID)

	cmd := exec.CommandContext(ctx, "yt-dlp",
		"--write-auto-sub",
		"--sub-lang", "id,en",
		"--skip-download",
		"--sub-format", "vtt",
		"-o", basePath,
		youtubeURL,
	)

	output, err := cmd.CombinedOutput()
	// yt-dlp mungkin me-return error (contoh: HTTP 429 saat mencoba download bahasa ke-2)
	// tapi bahasa pertama mungkin sudah berhasil di-download. 
	// Kita simpan errornya, tapi tetap cek apakah ada file .vtt yang dihasilkan.
	var execErr error
	if err != nil {
		execErr = fmt.Errorf("yt-dlp transcript fetch returned error: %w (output: %s)", err, string(output))
		log.Printf("[FFMPEG] WARNING: %v", execErr)
	}

	// yt-dlp menambahkan extension bahasa, misal: transcript_xxx.id.vtt atau transcript_xxx.en.vtt
	// Kita cari file yang cocok
	files, err := os.ReadDir(outputDir)
	if err != nil {
		return "", fmt.Errorf("failed to read outputs directory: %w", err)
	}

	var vttFile string
	for _, f := range files {
		if strings.HasPrefix(f.Name(), "transcript_"+tempUUID) && strings.HasSuffix(f.Name(), ".vtt") {
			vttFile = filepath.Join(outputDir, f.Name())
			break
		}
	}

	// Jika file sama sekali tidak ditemukan dan tadi ada error dari eksekusi yt-dlp
	if vttFile == "" {
		if execErr != nil {
			return "", execErr
		}
		return "", fmt.Errorf("transcript file not found after yt-dlp execution")
	}

	defer os.Remove(vttFile) // bersihkan file setelah dibaca

	content, err := os.ReadFile(vttFile)
	if err != nil {
		return "", fmt.Errorf("failed to read transcript file: %w", err)
	}

	return parseVTT(string(content)), nil
}

// parseVTT membersihkan teks VTT dari noise sambil mempertahankan penanda waktu.
// Penanda waktu disisipkan secara inline agar LLM tahu posisi waktu sebenarnya dalam video.
// Contoh output: "[00:00:05] Eh namanya bule aja apa ya [00:00:12] terus dia bilang gila"
func parseVTT(vttContent string) string {
	lines := strings.Split(vttContent, "\n")
	var resultLines []string

	// Regex untuk menangkap baris timestamp VTT: "00:00:05.000 --> 00:00:08.500"
	timestampRegex := regexp.MustCompile(`^(\d{2}:\d{2}:\d{2})\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}`)
	indexRegex := regexp.MustCompile(`^\d+$`)
	tagRegex := regexp.MustCompile(`<[^>]+>`)

	var lastLine string
	var lastTimestamp string
	var currentTimestamp string

	for _, line := range lines {
		line = strings.TrimSpace(line)

		if line == "" {
			continue
		}
		// Skip header
		if strings.HasPrefix(line, "WEBVTT") || strings.HasPrefix(line, "Kind:") || strings.HasPrefix(line, "Language:") {
			continue
		}
		// Tangkap timestamp start dari baris cue timing, simpan untuk baris teks berikutnya
		if matches := timestampRegex.FindStringSubmatch(line); matches != nil {
			currentTimestamp = matches[1] // Ambil HH:MM:SS tanpa milidetik
			continue
		}
		// Skip baris angka index
		if indexRegex.MatchString(line) {
			continue
		}

		// Bersihkan HTML/XML tags
		cleanLine := tagRegex.ReplaceAllString(line, "")
		cleanLine = strings.TrimSpace(cleanLine)

		if cleanLine == "" {
			continue
		}

		// Deduplikasi baris berturut-turut
		if cleanLine == lastLine {
			continue
		}

		// Sisipkan penanda waktu jika timestamp berubah (menghindari spam penanda)
		if currentTimestamp != "" && currentTimestamp != lastTimestamp {
			cleanLine = "[" + currentTimestamp + "] " + cleanLine
			lastTimestamp = currentTimestamp
		}

		resultLines = append(resultLines, cleanLine)
		lastLine = cleanLine
	}

	return strings.Join(resultLines, " ")
}
