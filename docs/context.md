## Project Name: Local AI Clipper (MVP)

### Project Description: A local-first automation platform that takes a YouTube URL, extracts the transcript, filters the most engaging segment using heuristic text scoring, uses a local LLM to find precise timestamps, and automatically slices the video into a 9:16 vertical clip using FFmpeg.

### Target Environment: Local execution on Apple Silicon (MacBook Air M2). Memory efficiency and minimizing LLM inference time are top priorities.

### 1. TECH STACK:

- Backend: Go (Golang) using the Gin HTTP framework.
- Architecture Pattern: Modulith / Package-by-Feature (Domain-driven structure)
- Database: NONE. Ephemeral state management using thread-safe in-memory maps (sync.Map or RWMutex).
- AI Engine: Local Ollama API (Model: llama3.2).
- Media Processing: ffmpeg, youtube-transcript, yt-dlp via Go's os/exec.

### 2. MODULITH ARCHITECTURE DIRECTORY STRUCTURE:
/api/main.go
/internal/clip/
   ├── handler.go (Gin HTTP POST trigger & GET polling status)
   ├── service.go (Orchestration, Chunking, Heuristic Filtering)
   ├── state.go (In-memory thread-safe map for Job Polling)
/internal/pkg/
   ├── ollama/ (HTTP client for Ollama API)
   ├── ffmpeg/ (os/exec wrapper for yt-dlp and ffmpeg)

### 3. CORE WORKFLOW & HEURISTIC FILTERING (CRITICAL):
- Step 1: Submission (Async Trigger)
    - Client POSTs {"youtubeUrl": "..."} to /api/v1/clips.
    - Go generates a UUID for job_id, saves state as status: "processing" in the in-memory map.
    - Go fires off a background goroutine and immediately returns HTTP 202 Accepted with {"job_id": "<uuid>"}.

- Step 2: Heuristic Pre-Filtering (In Go, Before AI)
    - Fetch the full transcript.
    - Chunking: Split the transcript into 5-minute chunks.
    - Scoring: Iterate through chunks and calculate a "Density Score". Add points for question marks (?), exclamation marks (!), and emotional keywords (e.g., "tapi", "masalahnya", "gila", "sebenarnya").
    - Sort chunks descending by score. Select ONLY the Top 1 chunk to send to the LLM.

- Step 3: AI Analysis (Ollama HTTP Call)
    - Send the Top 1 chunk to Ollama local API.
    - Strict Prompt Requirement: Force Ollama to return ONLY valid JSON: {"start_time": "00:00", "end_time": "00:00", "reasoning": "..."}. No preamble, no postscript.

- Step 4: Media Slicing (os/exec)
    - Use yt-dlp to download the specific segment.
    - Use ffmpeg (with context.WithTimeout) to cut the video based on AI timestamps and apply a crop filter to make it a 9:16 vertical video. Save to ./outputs/output_clip_<uuid>.mp4.
    - Update in-memory state to status: "completed" with the local video path.

### 4. CRITICAL CONSTRAINTS:

- Concurrency Safety: Ensure clip/state.go uses robust sync.RWMutex to prevent race conditions during HTTP GET polling.
- Error Boundaries: If yt-dlp, ffmpeg, or ollama fail inside the goroutine, update the job state to "failed" with the error reason so the client stops polling.

### 5. VIBE CODING TASK:
- Acknowledge this blueprint.
- Initialize the Go project (go mod init)
- set up the Gin router in main.go
- scaffold the Modulith structure inside /internal/clip/ and /internal/pkg/
- Do not write the full implementation in one go; start with the skeleton and state manager first.

