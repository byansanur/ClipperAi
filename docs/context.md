## Project Name: Local AI Clipper

### Project Description: A local-first automation platform that takes a YouTube URL, extracts the transcript, filters the most engaging segment using heuristic text scoring, uses a local LLM to find precise timestamps, and automatically slices the video into a 9:16 vertical clip using FFmpeg.

### Target Environment: Local execution on Apple Silicon (MacBook Air M2) for development. Production deployment on Linux VPS with automatic fallback to software encoding.

### 1. TECH STACK:

**Backend:**
- Language: Go (Golang) using the Gin HTTP framework.
- Architecture Pattern: Modulith / Package-by-Feature (Domain-driven structure)
- Database: NONE. Ephemeral state management using thread-safe in-memory maps (`sync.RWMutex`).
- AI Engine: Local Ollama API (Model: llama3.2).
- Media Processing: FFmpeg (with OS-adaptive encoding via `runtime.GOOS`), yt-dlp via Go's `os/exec`.
- Concurrency Control: Buffered Channel Semaphore (capacity: 1) for resource protection.

**Frontend:**
- Framework: Flutter (Target: Web & Android)
- State Management: Provider (`ChangeNotifier`)
- HTTP Client: Dio
- Video Player: `media_kit` & `media_kit_video`
- Download: `universal_html` (Web), `flutter_downloader` (Android/iOS)

### 2. MODULITH ARCHITECTURE DIRECTORY STRUCTURE:

```
/api/main.go
/internal/clip/
   ├── handler.go   (Gin HTTP: POST /clips, GET /clips/:id, DELETE /clips/:id, POST /clips/:id/next)
   ├── service.go   (Orchestration, Chunking, Heuristic Filtering, Semaphore, ProcessNextClip)
   ├── state.go     (In-memory thread-safe map for Job Polling, Caching, Chunk Storage)
   └── utils.go     (Helper functions: humanizeError, time parsing, scoring)
/internal/pkg/
   ├── ollama/       (HTTP client for Ollama API)
   └── ffmpeg/       (os/exec wrapper for yt-dlp and ffmpeg with dynamic encoding)
```

### 3. CORE WORKFLOW & HEURISTIC FILTERING (CRITICAL):

- Step 1: Submission (Async Trigger with Cache Check)
    - Client POSTs `{"youtube_url": "...", "layout_mode": "solo"}` to `/api/v1/clips`.
    - Handler first checks `FindCompletedJob(url, layout)` for a cached result. If found, returns HTTP 200 with cached data.
    - If no cache, Go generates a UUID for `job_id`, saves state as status: `"processing"` in the in-memory map.
    - Go fires off a background goroutine and immediately returns HTTP 202 Accepted with `{"job_id": "<uuid>"}`.

- Step 2: Heuristic Pre-Filtering (In Go, Before AI)
    - Fetch the full transcript.
    - Chunking: Split the transcript into 5-minute chunks.
    - Scoring: Iterate through chunks and calculate a "Density Score". Add points for question marks (?), exclamation marks (!), and emotional keywords (e.g., "tapi", "masalahnya", "gila", "sebenarnya").
    - Sort chunks descending by score. Store ALL sorted chunks in the Job state for on-demand processing.

- Step 3: AI Analysis (Ollama HTTP Call)
    - Send the Top 1 chunk to Ollama local API.
    - Strict Prompt Requirement: Force Ollama to return ONLY valid JSON: `{"start_time": "00:00", "end_time": "00:00", "reasoning": "..."}`. No preamble, no postscript.

- Step 4: Media Slicing (os/exec)
    - Use yt-dlp to download the video.
    - Use ffmpeg (with `context.WithTimeout`) to cut the video based on AI timestamps and apply a crop filter to make it a 9:16 vertical video. Encoder is selected dynamically based on OS.
    - Save to `./outputs/output_clip_<uuid>_0.mp4`.
    - Update in-memory state to status: `"completed"` with the video path.

- Step 5: On-Demand "Generate More"
    - Client POSTs to `/api/v1/clips/:id/next`.
    - Backend retrieves the next scored chunk from the Job's `SortedChunks`.
    - Re-downloads the video, runs Ollama + FFmpeg, and appends the new clip path to `VideoPaths`.
    - Status returns to `"completed"` once done.

### 4. CRITICAL CONSTRAINTS:

- Concurrency Safety: `clip/state.go` uses robust `sync.RWMutex` to prevent race conditions during HTTP GET polling.
- Concurrency Limiter: `processingSemaphore` (buffered channel, capacity 1) prevents resource starvation when multiple goroutines are spawned.
- Deduplication Caching: `FindCompletedJob` prevents redundant processing of the same URL + layout combination.
- Error Boundaries: If yt-dlp, ffmpeg, or ollama fail inside the goroutine, update the job state to `"failed"` with the error reason so the client stops polling.

### 5. IMPLEMENTATION STATUS:

- ✅ Backend MVP: Completed
- ✅ Frontend MVP (Web): Completed
- ✅ Android Support: Completed
- ✅ Concurrency Limiter (Semaphore): Completed
- ✅ On-Demand Generate More: Completed
- ✅ Smart Deduplication Caching: Completed
- ✅ Dynamic FFmpeg (Mac/Linux): Completed
- ✅ Floating History Panel: Completed
- ✅ System Back Navigation: Completed
- ✅ Hybrid Download Service: Completed
