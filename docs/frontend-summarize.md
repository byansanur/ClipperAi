# Flutter Frontend — Executive Summary

This document summarizes the architecture, technology stack, and workflow of the **Local AI Clipper** client interface, which is built using Flutter Web.

---

## 🛠️ Tech Stack & Key Libraries

*   **Framework**: Flutter (Target: Web / HTML Renderer)
*   **State Management**: `provider` (Simple, reactive, and easily maintainable)
*   **Networking**: `dio` (Handles asynchronous HTTP requests and polling)
*   **Video Player**: `media_kit` & `media_kit_video` (High-performance video playback on desktop and web)
*   **Additional Utilities**:
    *   `google_fonts`: Modern typography (Inter/Outfit).
    *   `flutter_dotenv`: Manages environment variables (e.g., API Base URL).
    *   `flutter_spinkit`: Provides smooth transition and loading animations.
    *   `shared_preferences`: Local storage for session recovery.
    *   `url_launcher`: Facilitates the direct video download button.

---

## 📂 Directory Structure (Feature-Based)

The project uses a Feature-Sliced design approach. All related components for a specific feature are grouped together in a single folder.

```text
frontend/lib/
├── core/
│   ├── api_client.dart       # Dio configuration (BaseURL, Headers, Timeouts)
│   └── theme.dart            # Design system (Premium Dark Theme, Color Palette)
├── features/
│   └── clip_generator/
│       ├── models/
│       │   └── job_response.dart   # JSON mapping models for Backend responses
│       ├── providers/
│       │   └── clip_provider.dart  # Manages HTTP logic, polling, and UIState
│       └── views/
│           ├── home_page.dart      # Main landing page (Input form & layout modes)
│           ├── loading_view.dart   # Loading animations while waiting for the backend
│           └── result_view.dart    # The final video player (TikTok-style UI Stack)
└── main.dart                 # App initialization (MediaKit, dotenv) & routing
```

---

## ⚙️ Application Workflow

The application relies on a central state manager, `ClipProvider`, which dynamically controls the user interface flow using various `UIState` enumerations (idle, submitting, loading, result, error).

### 1. Input & Job History Phase (Idle / Submitting)
*   Located in `home_page.dart`.
*   Displays the **Active Jobs Card**. A history of the 3 most recent jobs is saved via `shared_preferences`. This ensures users don't lose their progress even if they accidentally refresh the browser.
*   The user inputs a YouTube URL and selects a **Video Layout Mode** (Solo, Presentation, or Podcast).
*   When the "Generate" button is clicked, `ClipProvider` triggers a `POST /api/v1/clips` request.

### 2. Processing Phase (Loading & Polling)
*   If the backend returns a `202 Accepted` along with a `job_id`, the interface immediately transitions to `loading_view.dart`.
*   In the background, `ClipProvider` starts a polling timer, calling `GET /api/v1/clips/:job_id` every 5 seconds. It includes `404 Not Found` error handling to detect server restarts and prevent infinite polling loops.
*   This screen provides real-time text updates to the user, explaining what the local server is currently doing (e.g., analyzing transcripts, querying the LLM, rendering via FFmpeg).
*   If the user clicks the **Cancel** button, the app fires a `DELETE /api/v1/clips/:id` request to instantly stop the backend process (saving CPU resources) and clears the session cache from local memory.

### 3. Completion Phase (Result / TikTok UI)
*   Once the polling returns a `completed` status, the application state shifts to `result`.
*   The UI smoothly transitions to `result_view.dart`.
*   The **Result View** uses a `Stack` layout heavily inspired by **TikTok/Reels**:
    *   **Bottom Layer**: The video player (`media_kit`), set to `BoxFit.cover` (filling the screen completely) with native video controls hidden (`NoVideoControls`).
    *   **Middle Layer**: A gradient overlay fading from transparent at the top to solid black at the bottom, ensuring text readability.
    *   **Top Layer (Left)**: Status indicators confirming successful generation.
    *   **Top Layer (Right)**: A vertical column of circular action buttons (Download, Copy Link, Create New), mimicking standard social media interactions.

---

## 🎨 UI/UX Design Conventions

*   **Dark Mode**: Employs a combination of deep blacks and neon purple/cyan accents (`#0F0F12`, `#8B5CF6`) to create a premium, modern aesthetic.
*   **Responsiveness**: The interface is centered on the screen using a `ConstrainedBox` (with a `maxWidth` of 450px or 900px, depending on the page). This prevents awkward stretching on ultrawide desktop monitors while remaining perfectly proportioned for mobile screens.
*   **Animations**: Utilizes automatic transitions mediated by `switch(state)`. This pure Single Page Application (SPA) approach avoids complex navigation stacks and ensures a fluid user experience.
