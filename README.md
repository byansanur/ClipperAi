# ✂️ Local AI Clipper

**Local AI Clipper** is a local-first automation tool that converts YouTube videos into engaging vertical clips (9:16 aspect ratio), making them perfect for platforms like TikTok, Shorts, and Reels.

This system prioritizes memory efficiency and privacy by running the LLM and media processing entirely on your local machine, without relying on third-party cloud APIs.

---

## ✨ Key Features

- **Heuristic Pre-Filtering**: Intelligently analyzes YouTube transcripts to find the most interesting moments using a "density score" based on punctuation and emotional keywords. This drastically reduces LLM inference time by filtering out boring segments.
- **Local LLM Integration**: Uses the Llama 3.2 model via Ollama to determine precise start and end timestamps locally.
- **Dynamic Video Layouting**: Includes 3 fast FFmpeg cropping modes (Fast Seeking):
  - **Solo (Vlog)**: Efficient center cropping.
  - **Presentation**: Blurred background effect tailored for educational content.
  - **Podcast**: Split screen / vertical stack layout.
- **On-Demand "Generate More" Clips**: Backend only generates 1 clip initially. Additional clips are generated one-by-one on user demand via the "Gunting Klip Lainnya ✂️" button, saving CPU and memory resources.
- **Concurrency Limiter (Semaphore)**: A buffered channel limits heavy processing (LLM + FFmpeg) to 1 concurrent goroutine, preventing resource starvation on shared servers.
- **Smart Deduplication Caching**: If a user submits the same YouTube URL and layout mode that was already successfully processed, the backend returns the cached result instantly (HTTP 200) without re-processing.
- **Dynamic FFmpeg Arguments**: Automatically detects the OS at runtime — uses `h264_videotoolbox` hardware acceleration on macOS (Apple Silicon) and falls back to `libx264` software encoding on Linux VPS.
- **TikTok-Style Dashboard**: A premium Flutter interface with dark mode, smooth animations, and a TikTok-style vertical video player.
- **Floating History Panel**: An expandable/collapsible panel at the bottom (inspired by Google Drive) showing the 3 most recent jobs with real-time status.
- **Hybrid Download Service**: Cross-platform download — uses DOM-based download on Web and native file download on Android/iOS.
- **System Back Navigation Handling**: Intercepts Android system back gestures and swipe-back to prevent accidental app exit during video preview.

---

## 📸 Screenshots

*(Add your application screenshots to the `assets/screenshoot/` folder and display them here)*

![Home Page](assets/screenshoot/home_view.jpeg)
![Loading Page](assets/screenshoot/loading_view.jpeg)
![Result View](assets/screenshoot/result_view.jpeg)

---

## 🛠️ Tech Stack

### Backend

- **Language**: Go (Golang 1.21+)
- **Web Framework**: Gin HTTP
- **Architecture**: Modulith / Package-by-Feature with Thread-Safe In-Memory State
- **AI Engine**: Ollama (Llama 3.2)
- **Media Toolkit**: FFmpeg (Media Processing), yt-dlp (Video/Transcript Downloader)
- **Concurrency**: Buffered Channel Semaphore (capacity: 1)

### Frontend

- **Framework**: Flutter (Target: Web & Android)
- **State Management**: Provider
- **HTTP Client**: Dio
- **Media Player**: `media_kit` & `media_kit_video`
- **Download**: `universal_html` (Web), `flutter_downloader` (Android/iOS)
- **Permissions**: `permission_handler`
- **Storage**: `shared_preferences`, `path_provider`

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following tools installed on your system (macOS/Linux/Windows):

- [Go](https://go.dev/) (version 1.21 or newer)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Ollama](https://ollama.com/) (Run `ollama pull llama3.2` after installing)
- `ffmpeg` and `yt-dlp` (Available via Homebrew: `brew install ffmpeg yt-dlp`)

### 1. Running the Backend (Go)

Open a terminal and navigate to the `backend` folder:

```bash
cd backend
go mod tidy
go run api/main.go
```

_The server will start at `http://localhost:8080`._

### 2. Running the Frontend (Flutter Web)

Open a new terminal and navigate to the `frontend` folder:

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-renderer html
```

_Alternatively, to build a static web bundle:_

```bash
flutter build web
```

### 3. Running the Frontend (Android)

Ensure the backend server is running and accessible from your Android device (use your machine's local IP address, e.g., `192.168.x.x:8080`).

Update the `frontend/.env` file with your backend IP:

```env
API_BASE_URL=http://192.168.x.x:8080
```

Then run:

```bash
cd frontend
flutter run -d <your_device_id>
```

---

## 📂 Directory Structure

```text
ClipperAi/
├── assets/
│   └── screenshoot/         # Application screenshots
├── backend/
│   ├── api/                 # Go server entry point (main.go)
│   ├── internal/
│   │   ├── clip/            # Domain logic (Handler, Service, State, Utils)
│   │   └── pkg/             # FFmpeg & Ollama wrappers
│   └── outputs/             # Temporary storage for generated videos
├── docs/                    # Complete project documentation (API, Architecture, Code Conventions)
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── api_client.dart
│   │   │   ├── theme.dart
│   │   │   └── services/
│   │   │       └── download_service.dart
│   │   └── features/
│   │       └── clip_generator/
│   │           ├── models/
│   │           ├── providers/
│   │           ├── views/
│   │           └── widgets/
│   └── web/                 # Web build files (index.html)
└── README.md
```

---

## 📜 Further Documentation

- [Backend API Documentation](docs/backend-api.md)
- [Backend Summary](docs/backend-summarize.md)
- [Frontend Summary](docs/frontend-summarize.md)
- [Frontend Implementation Plan](docs/plan-frontend.md)
- [Backend Implementation Plan](docs/plan.md)
- [Code Convention](docs/code-convention.md)
- [Project Context](docs/context.md)

---

_Created by the AI Clipper Dev Team_
