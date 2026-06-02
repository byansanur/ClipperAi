# Local AI Clipper — Implementation Plan (Step-by-Step)

> **Purpose of this document**: Provide precise, structured instructions for AI coding agents to execute each phase **without ambiguity**. Every phase must be completed sequentially. Do not jump to the next phase before the previous one is fully completed and verified.

> **IMPORTANT:** Before executing any phase below, the agent **MUST** read and adhere to all coding conventions found in the `/docs/code-convention.md` file.

---

## Architecture Reference

```
ClipperAi/
├── backend/
│   ├── api/
│   │   └── main.go                  # Entry point, Gin router setup
│   ├── internal/
│   │   ├── clip/
│   │   │   ├── handler.go           # HTTP handler (POST /api/v1/clips, GET /api/v1/clips/:id, DELETE /api/v1/clips/:id)
│   │   │   ├── service.go           # Orchestration: chunking, scoring, LLM call, media slicing
│   │   │   └── state.go             # Thread-safe in-memory job state manager
│   │   └── pkg/
│   │       ├── ollama/
│   │       │   └── client.go        # HTTP client wrapper for Ollama API
│   │       └── ffmpeg/
│   │           └── executor.go      # os/exec wrapper for yt-dlp and ffmpeg
│   ├── outputs/                     # Output folder for video clips
│   ├── go.mod
│   └── go.sum
├── docs/
│   ├── context.md               # Project context
│   └── plan.md                  # This file
└── frontend/
```

---

## PHASE 0: Project Initialization

### Tasks:
1. Run `go mod init github.com/sgo-byan/clipperai` in the project root `/Users/sgo-byan/project/ClipperAi`.
2. Create the directory structure based on the reference above: `api/`, `internal/clip/`, `internal/pkg/ollama/`, `internal/pkg/ffmpeg/`, `outputs/`.
3. Add a `.gitkeep` file inside the `outputs/` folder so it gets tracked by Git.
4. Install Gin: `go get github.com/gin-gonic/gin`.
5. Install UUID library: `go get github.com/google/uuid`.

### Verification:
- `go mod tidy` runs without errors.
- All folders are created successfully.

---

## PHASE 1: State Manager (`internal/clip/state.go`)

### Description:
Create a thread-safe, in-memory job state manager using `sync.RWMutex`.

### Specifications:

```go
package clip

// JobStatus represents the status of a job.
type JobStatus string

const (
    StatusProcessing JobStatus = "processing"
    StatusCompleted  JobStatus = "completed"
    StatusFailed     JobStatus = "failed"
)

// Job stores the state of a single job.
type Job struct {
    ID        string    `json:"id"`
    Status    JobStatus `json:"status"`
    VideoPath string    `json:"video_path,omitempty"`
    Error     string    `json:"error,omitempty"`
}
```

### Required Functions:

| Function | Signature | Description |
|--------|-----------|-----------|
| `NewJobStore` | `func NewJobStore() *JobStore` | Constructor, returns a pointer to `JobStore` containing a `map[string]*Job` and a `sync.RWMutex`. |
| `CreateJob` | `func (s *JobStore) CreateJob(id string)` | Creates a new job with the `processing` status. Uses a **write lock**. |
| `GetJob` | `func (s *JobStore) GetJob(id string) (*Job, bool)` | Retrieves a job by its ID. Uses a **read lock**. Returns a copy of the `Job`, not a direct pointer to the map data. |
| `CompleteJob` | `func (s *JobStore) CompleteJob(id string, videoPath string)` | Updates the job's status to `completed` and sets the `video_path`. Uses a **write lock**. |
| `FailJob` | `func (s *JobStore) FailJob(id string, errMsg string)` | Updates the job's status to `failed` and sets the `error`. Uses a **write lock**. |

### Important Rules:
- **DO NOT** use `sync.Map`. Use a standard `map[string]*Job` protected by `sync.RWMutex`.
- `GetJob` must return a **copy** of the struct, not a pointer to the internal map data, to prevent race conditions.

### Verification:
- Code compiles without errors: `go build ./internal/clip/`

---

## PHASE 2: HTTP Handler (`internal/clip/handler.go`)

### Description:
Create Gin HTTP handlers for the endpoints.

### Endpoint 1: `POST /api/v1/clips`

- **Request Body**: `{"youtube_url": "https://youtube.com/watch?v=..."}`
- **Logic**:
  1. Bind the JSON body. If `youtube_url` is empty, return `400 Bad Request`.
  2. Generate a UUID using `github.com/google/uuid`.
  3. Call `JobStore.CreateJob(uuid)`.
  4. Run `go service.ProcessClip(jobID, youtubeURL)` as a goroutine (for now, create an empty placeholder function in `service.go`).
  5. Return `202 Accepted` with the body: `{"job_id": "<uuid>"}`.

### Endpoint 2: `GET /api/v1/clips/:id`

- **Logic**:
  1. Extract `id` from the URL parameters.
  2. Call `JobStore.GetJob(id)`.
  3. If the job is not found, return `404 Not Found`.
  4. Return `200 OK` with the `Job` struct as the JSON body.

### Handler Struct:

```go
type ClipHandler struct {
    store   *JobStore
    service *ClipService // to be populated in the next phase
}

func NewClipHandler(store *JobStore, service *ClipService) *ClipHandler
```

### Verification:
- Code compiles without errors: `go build ./internal/clip/`

---

## PHASE 3: Gin Router & Entry Point (`api/main.go`)

### Description:
Set up the Gin router and wire all dependencies.

### Specifications:

```go
package main

import (
    "log"
    "github.com/gin-gonic/gin"
    "github.com/sgo-byan/clipperai/internal/clip"
)

func main() {
    store := clip.NewJobStore()
    service := clip.NewClipService(store) // placeholder for now
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

### Verification:
- `go build ./api/` compiles without errors.
- `go run ./api/main.go` starts the server and endpoints respond correctly.
- Test commands:
  ```bash
  # Terminal 1: run server
  go run ./api/main.go

  # Terminal 2: test POST
  curl -X POST http://localhost:8080/api/v1/clips -H "Content-Type: application/json" -d '{"youtube_url": "https://youtube.com/watch?v=test"}'

  # Terminal 2: test GET (use the job_id from the POST response)
  curl http://localhost:8080/api/v1/clips/<job_id>
  ```

---

## PHASE 4: FFmpeg & yt-dlp Executor (`internal/pkg/ffmpeg/executor.go`)

### Description:
Create a wrapper to execute `yt-dlp` and `ffmpeg` via `os/exec`.

### Required Functions:

| Function | Signature | Description |
|--------|-----------|-----------|
| `DownloadVideo` | `func DownloadVideo(ctx context.Context, youtubeURL string, outputPath string) error` | Runs `yt-dlp` to download the video. Use `exec.CommandContext` to support cancellation via context. |
| `SliceAndCrop` | `func SliceAndCrop(ctx context.Context, inputPath string, outputPath string, startTime string, endTime string) error` | Runs `ffmpeg` to trim the video from `startTime` to `endTime` and apply a 9:16 crop filter. |

### `DownloadVideo` Implementation Detail:
```bash
yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4 -o <outputPath> <youtubeURL>
```

### `SliceAndCrop` Implementation Detail:
```bash
ffmpeg -i <inputPath> -ss <startTime> -to <endTime> -vf "crop=ih*9/16:ih" -c:v libx264 -c:a aac -y <outputPath>
```

### Important Rules:
- Always use `exec.CommandContext(ctx, ...)` to ensure commands can be canceled or timed out.
- Capture the command's `stderr` for error reporting using `cmd.CombinedOutput()`.
- If the command returns a non-zero exit code, return an error that includes the `stderr` output.

### Verification:
- Code compiles: `go build ./internal/pkg/ffmpeg/`

---

## PHASE 5: Ollama Client (`internal/pkg/ollama/client.go`)

### Description:
Create an HTTP client to communicate with the local Ollama API.

### Specifications:

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

// Parsed result from the LLM response
type ClipTimestamp struct {
    StartTime string `json:"start_time"`
    EndTime   string `json:"end_time"`
    Reasoning string `json:"reasoning"`
}
```

### Required Functions:

| Function | Signature | Description |
|--------|-----------|-----------|
| `NewClient` | `func NewClient(baseURL string) *Client` | Constructor. If `baseURL` is empty, default to `http://localhost:11434`. Set the HTTP timeout to 120 seconds. |
| `FindTimestamps` | `func (c *Client) FindTimestamps(ctx context.Context, transcriptChunk string) (*ClipTimestamp, error)` | Sends the transcript chunk to Ollama and parses the JSON response. |

### `FindTimestamps` Implementation Detail:
1. Create a strict prompt. **IMPORTANT: Use the `HH:MM:SS` format** (not `MM:SS`) as FFmpeg handles it more reliably:
   ```
   You are a video editor assistant. Analyze the following transcript segment and find the most engaging 30-60 second portion for a short-form vertical video clip.

   TRANSCRIPT:
   <transcriptChunk>

   Respond with ONLY valid JSON, no other text:
   {"start_time": "HH:MM:SS", "end_time": "HH:MM:SS", "reasoning": "..."}

   IMPORTANT: Use HH:MM:SS format (e.g., "00:02:05"), NOT MM:SS.
   ```
2. Make a POST request to `<baseURL>/api/generate` with the `llama3.2` model and `stream: false`.
3. Parse `GenerateResponse.Response` as JSON into `ClipTimestamp`.
4. If parsing fails, return a descriptive error.
5. **Timestamp Format Validation**: After parsing, validate that `start_time` and `end_time` match the `HH:MM:SS` pattern using the regex `^\d{2}:\d{2}:\d{2}$`. If the LLM returns `MM:SS`, automatically prepend `00:` to correct it.

### Helper Function (Must be created in this file):

| Function | Signature | Description |
|--------|-----------|-----------|
| `normalizeTimestamp` | `func normalizeTimestamp(ts string) (string, error)` | Accepts a timestamp string and normalizes it to `HH:MM:SS`. If input is `MM:SS` → prepend `00:`. If input is `HH:MM:SS` → return as-is. Return an error if the format is unrecognized. |

### Verification:
- Code compiles: `go build ./internal/pkg/ollama/`

---

## PHASE 6: Transcript Fetcher (Addition in `internal/pkg/ffmpeg/executor.go`)

### Description:
Add a function to fetch the YouTube transcript.

### Function:

| Function | Signature | Description |
|--------|-----------|-----------|
| `FetchTranscript` | `func FetchTranscript(ctx context.Context, youtubeURL string) (string, error)` | Runs `yt-dlp --write-auto-sub --sub-lang id,en --skip-download --sub-format vtt`, then reads and processes the generated subtitle file. |

### Detail:
1. Run `yt-dlp` with these flags:
   ```bash
   yt-dlp --write-auto-sub --sub-lang id,en --skip-download --sub-format vtt -o "outputs/transcript_<uuid>" <youtubeURL>
   ```
2. Read the resulting `.vtt` file.
3. **VTT Parsing — CRITICAL**: YouTube's `.vtt` files contain a lot of noise. Create a `parseVTT` helper function with the following steps:
   - **Remove headers**: Discard early lines containing `WEBVTT`, `Kind:`, `Language:`.
   - **Keep inline timestamps**: Don't discard timestamps entirely, but format them so they are inline with the text (e.g., `[HH:MM:SS]`) to help the LLM maintain temporal awareness.
   - **Remove cue indexes**: Lines containing only numbers should be dropped.
   - **Remove HTML/XML tags**: Use a regex like `<[^>]+>` to strip formatting tags (`<c>`, `<b>`, etc.).
   - **Deduplication**: YouTube's auto-generated VTT often repeats text across consecutive cues. Remove consecutive identical lines.
   - **Combine**: Join all remaining text into a clean, readable string.
4. Return the cleaned plain text transcript.

### Helper Function (Must be created):

| Function | Signature | Description |
|--------|-----------|-----------|
| `parseVTT` | `func parseVTT(vttContent string) string` | Accepts raw VTT content as a string and returns a cleaned transcript. |

### Verification:
- Code compiles: `go build ./internal/pkg/ffmpeg/`

---

## PHASE 7: Service / Orchestration (`internal/clip/service.go`)

### Description:
Implement the core logic: chunking, heuristic scoring, LLM API calls, and media slicing.

### Struct:

```go
type ClipService struct {
    store        *JobStore
    ollamaClient *ollama.Client
}

func NewClipService(store *JobStore) *ClipService
```

### Main Function:

#### `ProcessClip(jobID string, youtubeURL string)`
This function is executed as a goroutine. **All errors must be recovered, and the job state updated to "failed".**

**Flow:**
1. Create a `context.WithTimeout` of 10 minutes.
2. **Fetch transcript** → call `ffmpeg.FetchTranscript(ctx, youtubeURL)`.
3. **Chunk transcript** → call `chunkTranscript(transcript, 5)` (5 minutes per chunk).
4. **Score chunks** → call `scoreChunks(chunks)`, sort them in descending order, and pick the Top 1.
5. **LLM call** → call `ollamaClient.FindTimestamps(ctx, topChunk)`.
6. **Convert timestamps** → Before passing times to FFmpeg, parse `startTime` and `endTime` using `parseTimeToSeconds` to calculate the exact duration and format safely.
7. **Download video** → call `ffmpeg.DownloadVideo(ctx, youtubeURL, tempPath)`.
8. **Slice & crop** → call `ffmpeg.SliceAndCrop(ctx, tempPath, outputPath, safeStart, safeEnd)`.
9. **Update state** → `store.CompleteJob(jobID, outputPath)`.
10. If an error occurs at any step, call `store.FailJob(jobID, err.Error())`.

### Helper Functions (Must be created in `service.go`):

| Function | Signature | Description |
|--------|-----------|-----------|
| `parseTimeToSeconds` | `func parseTimeToSeconds(timestamp string) (int, error)` | Parses a timestamp string (`HH:MM:SS`, `MM:SS`, or raw seconds) into total integer seconds. |
| `secondsToFFmpegTime` | `func secondsToFFmpegTime(seconds int) string` | Converts integer seconds back into the `HH:MM:SS` format required by FFmpeg. |

#### `chunkTranscript(transcript string, minutesPerChunk int) []TranscriptChunk`
- Splits the transcript based on estimated time (assume ~150 words = 1 minute).
- Each chunk contains: `Text`, `StartOffset`, `EndOffset`.

#### `scoreChunks(chunks []TranscriptChunk) []ScoredChunk`
- **Heuristic Scoring Rules**:
  - Every `?` (question mark) → +3 points
  - Every `!` (exclamation mark) → +2 points
  - Every emotional keyword → +2 points per occurrence
  - **Keywords**: `"tapi"`, `"masalahnya"`, `"gila"`, `"sebenarnya"`, `"ternyata"`, `"wow"`, `"amazing"`, `"shocking"`, `"seriously"`, `"actually"`, `"honestly"`, `"crazy"`
- Sort descending by score.
- Return all sorted chunks.

### Verification:
- `go build ./...` compiles the entire project without errors.

---

## PHASE 8: Integration & End-to-End Test

### Tasks:
1. Ensure all wiring in `api/main.go` is correct (e.g., injecting `ollamaClient` into `ClipService`).
2. Run `go build ./...` — must result in zero errors.
3. Run `go vet ./...` — must result in zero warnings.
4. Perform a manual end-to-end test:
   ```bash
   # Ensure Ollama is running the llama3.2 model
   ollama run llama3.2

   # Run the server
   go run ./api/main.go

   # Submit a job
   curl -X POST http://localhost:8080/api/v1/clips \
     -H "Content-Type: application/json" \
     -d '{"youtube_url": "https://www.youtube.com/watch?v=<VIDEO_ID>"}'

   # Poll the status (use the job_id from the response)
   curl http://localhost:8080/api/v1/clips/<job_id>
   ```
5. Verify that the output video file appears in the `outputs/` folder.

### Success Criteria:
- The server responds with `202 Accepted` on POST.
- GET polling shows the transition: `processing` → `completed` (or `failed` with an error message).
- The video file `outputs/output_clip_<uuid>.mp4` is successfully generated with a 9:16 aspect ratio.

---

## EXECUTION SEQUENCE SUMMARY

| Phase | Target File | Dependencies |
|-------|-------------|--------------|
| 0 | `go.mod`, folder structure | None |
| 1 | `internal/clip/state.go` | Phase 0 |
| 2 | `internal/clip/handler.go` | Phase 1 |
| 3 | `api/main.go` | Phase 1, 2 |
| 4 | `internal/pkg/ffmpeg/executor.go` | Phase 0 |
| 5 | `internal/pkg/ollama/client.go` | Phase 0 |
| 6 | `internal/pkg/ffmpeg/executor.go` (addition) | Phase 4 |
| 7 | `internal/clip/service.go` | Phase 1, 4, 5, 6 |
| 8 | Integration test | All phases |

> **Agent Note**: Execute these phases sequentially (0 → 1 → 2 → ... → 8). During each phase, ensure `go build` is successful before advancing to the next. If compile errors arise, fix them before moving forward.