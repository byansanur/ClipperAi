# Flutter Frontend — Executive Summary

This document summarizes the architecture, technology stack, and workflow of the **Local AI Clipper** client interface, which is built using Flutter for Web and Android.

---

## 🛠️ Tech Stack & Key Libraries

*   **Framework**: Flutter (Target: Web & Android)
*   **State Management**: `provider` (Simple, reactive, and easily maintainable)
*   **Networking**: `dio` (Handles asynchronous HTTP requests and polling)
*   **Video Player**: `media_kit` & `media_kit_video` (High-performance video playback on desktop, web, and mobile)
*   **Download (Cross-Platform)**:
    *   `universal_html`: DOM-based download trigger for Web platform.
    *   `flutter_downloader`: Background download with system notification for Android/iOS.
*   **Permissions**: `permission_handler` (Requests notification and storage permissions on Android)
*   **Additional Utilities**:
    *   `google_fonts`: Modern typography (Inter/Outfit).
    *   `flutter_dotenv`: Manages environment variables (e.g., API Base URL).
    *   `flutter_spinkit`: Provides smooth transition and loading animations.
    *   `shared_preferences`: Local storage for session recovery and job history.
    *   `path_provider`: Locates platform-specific directories for downloads.
    *   `url_launcher`: Facilitates direct video URL opening.

---

## 📂 Directory Structure (Feature-Based)

The project uses a Feature-Sliced design approach. All related components for a specific feature are grouped together in a single folder.

```text
frontend/lib/
├── core/
│   ├── api_client.dart             # Dio configuration (BaseURL, Headers, Timeouts)
│   ├── theme.dart                  # Design system (Premium Dark Theme, Color Palette)
│   └── services/
│       └── download_service.dart   # Cross-platform download logic (Web DOM / Native)
├── features/
│   └── clip_generator/
│       ├── models/
│       │   └── job_response.dart   # JSON mapping models for Backend responses
│       ├── providers/
│       │   └── clip_provider.dart  # Manages HTTP logic, polling, caching, and UIState
│       ├── views/
│       │   ├── home_page.dart      # Main landing page (Unified Form Card, Floating Panel, PopScope)
│       │   ├── loading_view.dart   # Loading animations while waiting for the backend
│       │   └── result_view.dart    # TikTok-style video player with "Generate More" slide
│       └── widgets/
│           └── common_widgets.dart # Reusable UI components (GradientOverlay, ActionButtons, etc.)
└── main.dart                       # App initialization (MediaKit, dotenv) & routing
```

---

## ⚙️ Application Workflow

The application relies on a central state manager, `ClipProvider`, which dynamically controls the user interface flow using various `UIState` enumerations (idle, submitting, loading, result, error).

### 1. Input & Job History Phase (Idle / Submitting)
*   Located in `home_page.dart`.
*   Features a **Unified Form Card** with a responsive `ConstrainedBox` (maxWidth: 600) that looks great on both Web and mobile.
*   Uses a **Segmented Control** for layout mode selection (Solo, Presentation, Podcast).
*   Displays a **Floating History Panel** at the bottom (inspired by Google Drive's download panel). This animated, expandable/collapsible panel shows the 3 most recent jobs with real-time status indicators, saved via `shared_preferences`.
*   Implements `PopScope` to intercept Android system back gestures and swipe-back during loading/result states, preventing accidental app exit.
*   When the "Generate" button is clicked, `ClipProvider` triggers a `POST /api/v1/clips` request.

### 2. Processing Phase (Loading & Polling)
*   If the backend returns a `202 Accepted` along with a `job_id`, the interface immediately transitions to `loading_view.dart`.
*   If the backend returns `200 OK` (cache hit), the `job_id` from the cached result is used, and the polling engine is activated — which instantly detects the completed status and jumps to the result view.
*   In the background, `ClipProvider` starts a polling timer, calling `GET /api/v1/clips/:job_id` every 5 seconds. It includes `404 Not Found` error handling to detect server restarts and prevent infinite polling loops.
*   This screen provides real-time text updates to the user, explaining what the local server is currently doing (e.g., analyzing transcripts, querying the LLM, rendering via FFmpeg).
*   If the user clicks the **Cancel** button, the app fires a `DELETE /api/v1/clips/:id` request to instantly stop the backend process (saving CPU resources) and clears the session cache from local memory.

### 3. Completion Phase (Result / TikTok UI)
*   Once the polling returns a `completed` status, the application state shifts to `result`.
*   The UI smoothly transitions to `result_view.dart`.
*   The **Result View** uses a vertical `PageView.builder` with swipe-up navigation (TikTok-style):
    *   Each page contains a full-screen video player (`media_kit`), set to `BoxFit.cover` with native video controls hidden (`NoVideoControls`).
    *   A gradient overlay fading from transparent at the top to solid black at the bottom ensures text readability.
    *   Action buttons (Download, Copy Link, Create New) are positioned on the right side (mobile) or in a separate column (desktop).
*   **"Generate More" Slide**: The last page in the `PageView` is an interactive card with a "Gunting Klip Lainnya ✂️" button. When tapped, it calls `POST /api/v1/clips/:id/next` and displays a loading spinner while the backend processes the next chunk. Once complete, the new video appears in the swipe-able feed.

### 4. Responsive Layout Logic
*   **Web (width > 800px)**: Desktop-optimized layout with the video in a 9:16 container and action buttons in a side column. Floating History Panel is positioned at the bottom-right corner.
*   **Mobile (width ≤ 800px)**: Full-width layout with TikTok-style overlay actions. Floating History Panel stretches across the bottom edge.

---

## 🎨 UI/UX Design Conventions

*   **Dark Mode**: Employs a combination of deep blacks and neon purple/cyan accents (`#0F0F12`, `#8B5CF6`) to create a premium, modern aesthetic.
*   **Unified Form Card**: All input elements (URL field, layout selector, submit button) are grouped inside a single dark container with rounded corners and subtle borders, creating a cohesive form experience.
*   **Responsiveness**: The interface is centered on the screen using a `ConstrainedBox` (maxWidth: 600 for form, 450 for mobile views). This prevents awkward stretching on ultrawide desktop monitors while remaining perfectly proportioned for mobile screens.
*   **Animations**: Utilizes automatic transitions mediated by `switch(state)`. The Floating History Panel uses `AnimatedContainer` for smooth expand/collapse. Loading states use `SpinKitWave` for premium feel.
*   **System Navigation**: `PopScope` intercepts physical back buttons and swipe-back gestures on Android to prevent accidental exits during video preview or loading.
