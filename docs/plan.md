# Local AI Clipper — Implementation Plan (Step-by-Step)

> **Tujuan dokumen ini**: Memberikan instruksi yang presisi dan terstruktur agar agent coding (model murah) dapat mengeksekusi setiap fase **tanpa ambiguitas**. Setiap fase harus diselesaikan secara berurutan. Jangan lompat ke fase berikutnya sebelum fase sebelumnya selesai dan diverifikasi.

> **PENTING:** Sebelum mengeksekusi fase apa pun di bawah ini, agen **WAJIB** membaca dan mematuhi seluruh aturan penulisan kode yang ada di file `/docs/code-convention.md`.

---

## Referensi Arsitektur

```
ClipperAi/
├── backend/
│   ├── api/
│   │   └── main.go                  # Entry point, Gin router setup
│   ├── internal/
│   │   ├── clip/
│   │   │   ├── handler.go           # HTTP handler (POST /api/v1/clips, GET /api/v1/clips/:id)
│   │   │   ├── service.go           # Orchestration: chunking, scoring, LLM call, media slicing
│   │   │   └── state.go             # Thread-safe in-memory job state manager
│   │   └── pkg/
│   │       ├── ollama/
│   │       │   └── client.go        # HTTP client wrapper untuk Ollama API
│   │       └── ffmpeg/
│   │           └── executor.go      # os/exec wrapper untuk yt-dlp dan ffmpeg
│   ├── outputs/                     # Folder output video clips
│   ├── go.mod
│   └── go.sum
├── docs/
│   ├── context.md               # Project context (sudah ada)
│   └── plan.md                  # File ini
└── frontend/
```

---

## FASE 0: Project Initialization

### Tugas:
1. Jalankan `go mod init github.com/sgo-byan/clipperai` di root project `/Users/sgo-byan/project/ClipperAi`.
2. Buat seluruh folder structure sesuai referensi arsitektur di atas. Buat folder: `api/`, `internal/clip/`, `internal/pkg/ollama/`, `internal/pkg/ffmpeg/`, `outputs/`.
3. Tambahkan file `.gitkeep` di dalam folder `outputs/` agar folder ter-track oleh git.
4. Install dependency Gin: jalankan `go get github.com/gin-gonic/gin`.
5. Install dependency UUID: jalankan `go get github.com/google/uuid`.

### Verifikasi:
- `go mod tidy` berjalan tanpa error.
- Semua folder sudah terbuat.

---

## FASE 1: State Manager (`internal/clip/state.go`)

### Deskripsi:
Buat thread-safe in-memory job state manager menggunakan `sync.RWMutex`.

### Spesifikasi:

```go
package clip

// JobStatus mewakili status sebuah job.
type JobStatus string

const (
    StatusProcessing JobStatus = "processing"
    StatusCompleted  JobStatus = "completed"
    StatusFailed     JobStatus = "failed"
)

// Job menyimpan state untuk satu job.
type Job struct {
    ID        string    `json:"id"`
    Status    JobStatus `json:"status"`
    VideoPath string    `json:"video_path,omitempty"`
    Error     string    `json:"error,omitempty"`
}
```

### Fungsi yang harus dibuat:

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `NewJobStore` | `func NewJobStore() *JobStore` | Constructor, return pointer ke JobStore yang berisi `map[string]*Job` dan `sync.RWMutex`. |
| `CreateJob` | `func (s *JobStore) CreateJob(id string)` | Buat job baru dengan status `processing`. Gunakan **write lock**. |
| `GetJob` | `func (s *JobStore) GetJob(id string) (*Job, bool)` | Ambil job by ID. Gunakan **read lock**. Return copy dari Job, bukan pointer langsung ke map. |
| `CompleteJob` | `func (s *JobStore) CompleteJob(id string, videoPath string)` | Update status ke `completed` dan set `video_path`. Gunakan **write lock**. |
| `FailJob` | `func (s *JobStore) FailJob(id string, errMsg string)` | Update status ke `failed` dan set `error`. Gunakan **write lock**. |

### Aturan Penting:
- **JANGAN** gunakan `sync.Map`. Gunakan `sync.RWMutex` + regular `map[string]*Job`.
- `GetJob` harus return **copy** dari struct, bukan pointer ke data di dalam map, untuk mencegah race condition.

### Verifikasi:
- Code compiles tanpa error: `go build ./internal/clip/`

---

## FASE 2: HTTP Handler (`internal/clip/handler.go`)

### Deskripsi:
Buat Gin HTTP handler untuk dua endpoint.

### Endpoint 1: `POST /api/v1/clips`

- **Request Body**: `{"youtube_url": "https://youtube.com/watch?v=..."}`
- **Logic**:
  1. Bind JSON body. Jika `youtube_url` kosong, return `400 Bad Request`.
  2. Generate UUID menggunakan `github.com/google/uuid`.
  3. Panggil `JobStore.CreateJob(uuid)`.
  4. Jalankan `go service.ProcessClip(jobID, youtubeURL)` sebagai goroutine (untuk saat ini, buat fungsi placeholder kosong di service.go).
  5. Return `202 Accepted` dengan body: `{"job_id": "<uuid>"}`.

### Endpoint 2: `GET /api/v1/clips/:id`

- **Logic**:
  1. Ambil `id` dari URL parameter.
  2. Panggil `JobStore.GetJob(id)`.
  3. Jika job tidak ditemukan, return `404 Not Found`.
  4. Return `200 OK` dengan body Job struct sebagai JSON.

### Struct Handler:

```go
type ClipHandler struct {
    store   *JobStore
    service *ClipService // akan diisi di fase berikutnya
}

func NewClipHandler(store *JobStore, service *ClipService) *ClipHandler
```

### Verifikasi:
- Code compiles tanpa error: `go build ./internal/clip/`

---

## FASE 3: Gin Router & Entry Point (`api/main.go`)

### Deskripsi:
Setup Gin router dan wiring semua dependency.

### Spesifikasi:

```go
package main

import (
    "log"
    "github.com/gin-gonic/gin"
    "github.com/sgo-byan/clipperai/internal/clip"
)

func main() {
    store := clip.NewJobStore()
    service := clip.NewClipService(store) // placeholder untuk sekarang
    handler := clip.NewClipHandler(store, service)

    r := gin.Default()

    v1 := r.Group("/api/v1")
    {
        v1.POST("/clips", handler.SubmitClip)
        v1.GET("/clips/:id", handler.GetClipStatus)
    }

    log.Println("Server starting on :8080")
    r.Run(":8080")
}
```

### Verifikasi:
- `go build ./api/` compiles tanpa error.
- `go run ./api/main.go` server jalan dan endpoint merespons (bisa test dengan curl).
- Test command:
  ```bash
  # Terminal 1: jalankan server
  go run ./api/main.go

  # Terminal 2: test POST
  curl -X POST http://localhost:8080/api/v1/clips -H "Content-Type: application/json" -d '{"youtube_url": "https://youtube.com/watch?v=test"}'

  # Terminal 2: test GET (gunakan job_id dari response POST)
  curl http://localhost:8080/api/v1/clips/<job_id>
  ```

---

## FASE 4: FFmpeg & yt-dlp Executor (`internal/pkg/ffmpeg/executor.go`)

### Deskripsi:
Buat wrapper untuk menjalankan `yt-dlp` dan `ffmpeg` via `os/exec`.

### Fungsi yang harus dibuat:

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `DownloadVideo` | `func DownloadVideo(ctx context.Context, youtubeURL string, outputPath string) error` | Jalankan `yt-dlp` untuk download video. Gunakan `exec.CommandContext` agar bisa di-cancel via context. |
| `SliceAndCrop` | `func SliceAndCrop(ctx context.Context, inputPath string, outputPath string, startTime string, endTime string) error` | Jalankan `ffmpeg` untuk cut video dari `startTime` ke `endTime` dan apply crop filter 9:16. |

### Detail Implementasi `DownloadVideo`:
```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4 -o <outputPath> <youtubeURL>
```

### Detail Implementasi `SliceAndCrop`:
```bash
ffmpeg -i <inputPath> -ss <startTime> -to <endTime> -vf "crop=ih*9/16:ih" -c:v libx264 -c:a aac -y <outputPath>
```

### Aturan Penting:
- Selalu gunakan `exec.CommandContext(ctx, ...)` supaya bisa timeout.
- Capture `stderr` dari command untuk error reporting: gunakan `cmd.CombinedOutput()`.
- Jika command return non-zero exit code, return error yang mengandung stderr output.

### Verifikasi:
- Code compiles: `go build ./internal/pkg/ffmpeg/`

---

## FASE 5: Ollama Client (`internal/pkg/ollama/client.go`)

### Deskripsi:
Buat HTTP client untuk berkomunikasi dengan Ollama local API.

### Spesifikasi:

```go
package ollama

type Client struct {
    baseURL    string // default: "http://localhost:11434"
    httpClient *http.Client
}

type GenerateRequest struct {
    Model  string `json:"model"`
    Prompt string `json:"prompt"`
    Stream bool   `json:"stream"`
}

type GenerateResponse struct {
    Response string `json:"response"`
}

// Parsed result dari response LLM
type ClipTimestamp struct {
    StartTime string `json:"start_time"`
    EndTime   string `json:"end_time"`
    Reasoning string `json:"reasoning"`
}
```

### Fungsi yang harus dibuat:

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `NewClient` | `func NewClient(baseURL string) *Client` | Constructor. Jika `baseURL` kosong, gunakan default `http://localhost:11434`. Set HTTP timeout 120 detik. |
| `FindTimestamps` | `func (c *Client) FindTimestamps(ctx context.Context, transcriptChunk string) (*ClipTimestamp, error)` | Kirim transcript chunk ke Ollama, parse JSON response. |

### Detail Implementasi `FindTimestamps`:
1. Buat prompt yang strict. **PENTING: Gunakan format `HH:MM:SS`** (bukan `MM:SS`) karena FFmpeg lebih stabil menerima format ini:
   ```
   You are a video editor assistant. Analyze the following transcript segment and find the most engaging 30-60 second portion for a short-form vertical video clip.

   TRANSCRIPT:
   <transcriptChunk>

   Respond with ONLY valid JSON, no other text:
   {"start_time": "HH:MM:SS", "end_time": "HH:MM:SS", "reasoning": "..."}

   IMPORTANT: Use HH:MM:SS format (e.g., "00:02:05"), NOT MM:SS.
   ```
2. POST ke `<baseURL>/api/generate` dengan model `llama3.2` dan `stream: false`.
3. Parse `GenerateResponse.Response` sebagai JSON ke `ClipTimestamp`.
4. Jika parsing gagal, return error descriptif.
5. **Validasi format timestamp**: Setelah parsing JSON, validasi bahwa `start_time` dan `end_time` match pattern `HH:MM:SS` menggunakan regex `^\d{2}:\d{2}:\d{2}$`. Jika LLM mengembalikan format `MM:SS`, auto-konversi ke `00:MM:SS`.

### Helper Function (wajib dibuat di file ini):

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `normalizeTimestamp` | `func normalizeTimestamp(ts string) (string, error)` | Terima timestamp string, normalisasi ke format `HH:MM:SS`. Jika input `MM:SS` → prepend `00:`. Jika input `HH:MM:SS` → return as-is. Jika format tidak dikenali → return error. |

### Verifikasi:
- Code compiles: `go build ./internal/pkg/ollama/`

---

## FASE 6: Transcript Fetcher (Tambahan di `internal/pkg/ffmpeg/executor.go`)

### Deskripsi:
Tambahkan fungsi untuk fetch transcript YouTube.

### Fungsi:

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `FetchTranscript` | `func FetchTranscript(ctx context.Context, youtubeURL string) (string, error)` | Jalankan `yt-dlp --write-auto-sub --sub-lang id,en --skip-download --sub-format txt` lalu baca file subtitle yang dihasilkan. |

### Detail:
1. Gunakan `yt-dlp` dengan flag:
   ```bash
   yt-dlp --write-auto-sub --sub-lang id,en --skip-download --sub-format vtt -o "outputs/transcript_<uuid>" <youtubeURL>
   ```
2. Baca file `.vtt` yang dihasilkan.
3. **Parsing VTT — KRITIS**: File `.vtt` dari YouTube mengandung banyak noise. Gunakan helper function `parseVTT` dengan langkah-langkah berikut:
   - **Hapus header**: Buang baris-baris awal yang mengandung `WEBVTT`, `Kind:`, `Language:`.
   - **Hapus timestamp lines**: Gunakan regex `^\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}` untuk mendeteksi dan menghapus baris timestamp.
   - **Hapus baris angka index**: Baris yang hanya berisi angka (nomor urut cue) harus dibuang. Gunakan regex `^\d+$`.
   - **Hapus HTML/XML tags**: Gunakan regex `<[^>]+>` untuk menghapus tag seperti `<c>`, `</c>`, `<b>`, dll.
   - **Hapus baris kosong** dan trim whitespace.
   - **Deduplikasi**: VTT YouTube sering mengulangi teks yang sama di cue berturut-turut. Buang baris yang identik dengan baris sebelumnya.
   - **Gabungkan** semua baris teks yang tersisa menjadi satu string panjang, dipisahkan spasi.
4. Return plain text transcript yang sudah bersih sebagai string.

### Helper Function (wajib dibuat):

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `parseVTT` | `func parseVTT(vttContent string) string` | Terima raw string isi file `.vtt`, return clean plain text transcript. Implementasi sesuai langkah di atas menggunakan `regexp` package. |

### Verifikasi:
- Code compiles: `go build ./internal/pkg/ffmpeg/`

---

## FASE 7: Service / Orchestration (`internal/clip/service.go`)

### Deskripsi:
Implementasi logic utama: chunking, heuristic scoring, LLM call, dan media slicing.

### Struct:

```go
type ClipService struct {
    store       *JobStore
    ollamaClient *ollama.Client
}

func NewClipService(store *JobStore) *ClipService
```

### Fungsi Utama:

#### `ProcessClip(jobID string, youtubeURL string)`
Ini adalah fungsi yang dipanggil sebagai goroutine. **Semua error harus di-recover dan update state ke "failed".**

**Flow:**
1. Buat `context.WithTimeout` 10 menit.
2. **Fetch transcript** → panggil `ffmpeg.FetchTranscript(ctx, youtubeURL)`.
3. **Chunk transcript** → panggil `chunkTranscript(transcript, 5)` (5 menit per chunk).
4. **Score chunks** → panggil `scoreChunks(chunks)`, sort descending, ambil Top 1.
5. **LLM call** → panggil `ollamaClient.FindTimestamps(ctx, topChunk)`.
6. **Konversi timestamp** → Sebelum dikirim ke FFmpeg, konversi `startTime` dan `endTime` dari LLM ke format yang aman untuk FFmpeg menggunakan `parseTimeToSeconds`. Ini menghasilkan integer detik total yang bisa di-format ulang ke `HH:MM:SS` atau langsung digunakan sebagai string detik.
7. **Download video** → panggil `ffmpeg.DownloadVideo(ctx, youtubeURL, tempPath)`.
8. **Slice & crop** → panggil `ffmpeg.SliceAndCrop(ctx, tempPath, outputPath, safeFfmpegStart, safeFfmpegEnd)`. Parameter waktu sudah di-konversi di step 6.
9. **Update state** → `store.CompleteJob(jobID, outputPath)`.
10. Jika ada error di step manapun, panggil `store.FailJob(jobID, err.Error())`.

### Helper Function (wajib dibuat di service.go):

| Fungsi | Signature | Deskripsi |
|--------|-----------|-----------|
| `parseTimeToSeconds` | `func parseTimeToSeconds(timestamp string) (int, error)` | Parse timestamp string (mendukung format `HH:MM:SS`, `MM:SS`, atau detik murni) dan return total detik sebagai integer. Contoh: `"00:02:05"` → `125`, `"02:05"` → `125`, `"125"` → `125`. |
| `secondsToFFmpegTime` | `func secondsToFFmpegTime(seconds int) string` | Konversi integer detik ke format `HH:MM:SS` yang aman untuk FFmpeg. Contoh: `125` → `"00:02:05"`. |

#### `chunkTranscript(transcript string, minutesPerChunk int) []TranscriptChunk`
- Split transcript berdasarkan estimasi waktu (asumsikan ~150 kata = 1 menit).
- Setiap chunk berisi: `Text`, `StartOffset`, `EndOffset`.

#### `scoreChunks(chunks []TranscriptChunk) []ScoredChunk`
- **Heuristic Scoring Rules**:
  - Setiap `?` (tanda tanya) → +3 poin
  - Setiap `!` (tanda seru) → +2 poin
  - Setiap keyword emosional → +2 poin per kemunculan
  - **Keywords**: `"tapi"`, `"masalahnya"`, `"gila"`, `"sebenarnya"`, `"ternyata"`, `"wow"`, `"amazing"`, `"shocking"`, `"seriously"`, `"actually"`, `"honestly"`, `"crazy"`
- Sort descending by score.
- Return semua chunks yang sudah di-sort (caller akan ambil Top 1).

### Verifikasi:
- `go build ./...` compiles seluruh project tanpa error.

---

## FASE 8: Integration & End-to-End Test

### Tugas:
1. Pastikan semua wiring di `api/main.go` sudah benar (inject `ollamaClient` ke `ClipService`).
2. Jalankan `go build ./...` — harus zero errors.
3. Jalankan `go vet ./...` — harus zero warnings.
4. Test manual end-to-end:
   ```bash
   # Pastikan Ollama sudah jalan dengan model llama3.2
   ollama run llama3.2

   # Jalankan server
   go run ./api/main.go

   # Submit job
   curl -X POST http://localhost:8080/api/v1/clips \
     -H "Content-Type: application/json" \
     -d '{"youtube_url": "https://www.youtube.com/watch?v=<VIDEO_ID>"}'

   # Poll status (gunakan job_id dari response)
   curl http://localhost:8080/api/v1/clips/<job_id>
   ```
5. Verifikasi bahwa file output muncul di folder `outputs/`.

### Kriteria Sukses:
- Server merespons `202 Accepted` pada POST.
- Polling GET menunjukkan transisi: `processing` → `completed` (atau `failed` dengan error message).
- File video `outputs/output_clip_<uuid>.mp4` terbuat dengan aspect ratio 9:16.

---

## RINGKASAN URUTAN EKSEKUSI

| Fase | File Target | Dependency |
|------|-------------|------------|
| 0 | `go.mod`, folder structure | Tidak ada |
| 1 | `internal/clip/state.go` | Fase 0 |
| 2 | `internal/clip/handler.go` | Fase 1 |
| 3 | `api/main.go` | Fase 1, 2 |
| 4 | `internal/pkg/ffmpeg/executor.go` | Fase 0 |
| 5 | `internal/pkg/ollama/client.go` | Fase 0 |
| 6 | `internal/pkg/ffmpeg/executor.go` (tambahan) | Fase 4 |
| 7 | `internal/clip/service.go` | Fase 1, 4, 5, 6 |
| 8 | Integration test | Semua fase |

> **Catatan untuk Agent**: Eksekusi fase secara berurutan (0 → 1 → 2 → ... → 8). Di setiap fase, pastikan `go build` berhasil sebelum lanjut ke fase berikutnya. Jika ada compile error, perbaiki dulu sebelum melanjutkan.