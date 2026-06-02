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
- **TikTok-Style Web Dashboard**: A premium Flutter Web interface with dark mode, smooth animations, and a TikTok-style video player.

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

### Frontend

- **Framework**: Flutter (Target: Web)
- **State Management**: Provider
- **HTTP Client**: Dio
- **Media Player**: `media_kit` & `media_kit_video`

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

---

## 📂 Directory Structure

```text
ClipperAi/
├── assets/
│   └── screenshoot/         # Application screenshots
├── backend/
│   ├── api/                 # Go server entry point (main.go)
│   ├── internal/
│   │   ├── clip/            # Domain logic (Handler, Service, State)
│   │   └── pkg/             # FFmpeg & Ollama wrappers
│   └── outputs/             # Temporary storage for generated videos
├── docs/                    # Complete project documentation (API, Architecture, Code Conventions)
├── frontend/
│   ├── lib/
│   │   ├── core/            # Theme, API Client
│   │   └── features/        # UI Components (Models, Providers, Views)
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
