# Go Coding Conventions & Standards

> **Purpose of this document:** This document outlines the STRICT RULES for AI Agents during "vibe coding" sessions for the ClipperAi project. These rules must be applied across all `.go` files without exception.

## 1. Error Handling (Mandatory)
- **Never ignore errors.** It is strictly forbidden to use the blank identifier (`_`) to suppress critical errors.
- **Contextual Errors:** Always wrap errors with clear context using `fmt.Errorf` and the `%w` verb so the stack trace remains traceable.
  - *Correct:* `return fmt.Errorf("failed to extract transcript for URL %s: %w", url, err)`
  - *Incorrect:* `return err`

## 2. Naming Conventions
- **JSON Tags:** Consistently use `snake_case`.
  - *Correct:* ``json:"start_time"``
  - *Incorrect:* ``json:"startTime"``
- **Structs & Interfaces:** Use `PascalCase` for exported data types.
- **Variables & Unexported Functions:** Use `camelCase` (e.g., `parseTimeToSeconds`).
- **Acronyms:** Use all uppercase letters for standard IT acronyms (e.g., `URL`, `ID`, `HTTP`, `JSON`). Use `jobID`, NOT `jobId`.

## 3. Logging & Output
- Use Go's built-in `log` standard library (`"log"`).
- Include a **module prefix** enclosed in brackets `[...]` on every log message for easier reading in the terminal.
  - *Example:* `log.Printf("[FFMPEG] Slicing video for job %s started", jobID)`
  - *Example:* `log.Printf("[OLLAMA] Failed to parse JSON response: %v", err)`

## 4. Goroutine Safety (Critical)
- Every primary goroutine (like the background worker in `ProcessClip`) **MUST** include a `defer` and `recover` mechanism as its very first line.
- This is crucial for catching unexpected panics and preventing the entire Go server from crashing.
  ```go
  go func() {
      defer func() {
          if r := recover(); r != nil {
              log.Printf("[SERVICE] Panic recovered in background job %s: %v", jobID, r)
              store.FailJob(jobID, "Internal server error during processing")
          }
      }()
      // ... goroutine logic goes here ...
  }()
  ```

## 5. Clean Code & Comments
- Assume the code will be formatted using `gofmt`. Do not manually write strange spacing or indentation.
- **Meaningful Comments:** Do not add obvious comments (like `// This function returns true`). Provide comments ONLY for complex logic, such as explaining why a specific regex is used in the VTT parser or detailing the heuristic scoring formula.

======================================================================

# Flutter Coding Conventions & Standards

> **Purpose of this document:** This document outlines the STRICT RULES for AI Agents when writing Flutter Frontend code for the ClipperAi project.

## 1. Naming & File Structure (Dart Standards)
- **Files & Folders:** Must use `snake_case` (e.g., `home_page.dart`, `clip_provider.dart`).
- **Classes, Enums, & Typedefs:** Must use `PascalCase` (e.g., `ClipGeneratorView`).
- **Variables & Methods:** Must use `camelCase` (e.g., `startPolling()`, `videoUrl`).

## 2. Widget Architecture & UI (Critical)
- **Use `const` Wherever Possible:** To optimize performance and prevent unnecessary rebuilds, any widget that does not depend on dynamic state MUST use the `const` constructor.
- **Widget Extraction, Not Helper Methods:** If a UI component becomes too long, extract it into a separate `StatelessWidget` class. **DO NOT** break down UI using helper methods that return widgets (e.g., incorrect: `Widget _buildHeader() { return Text(...); }`).
- **Trailing Commas:** You must add a trailing comma `,` at the end of every closing widget parameter to ensure the auto-formatter (`dart format`) organizes the code neatly.

## 3. Separation of Concerns (State Management)
- **No Business Logic in UI:** Files within the `views/` folder must only contain visual components (UI). All API calls, HTTP requests (Dio), and polling logic **MUST** be placed in the `providers/` folder (using `ChangeNotifier`).
- **Minimize StatefulWidget:** Rely on `StatelessWidget` combined with a `Consumer` (from the `provider` package) as much as possible. Avoid using `setState()` unless it's for very simple, localized UI animations.

## 4. Asynchronous & Error Handling
- **Context Mounting Check (Mandatory):** When using `await` inside a function that requires a `BuildContext` (like showing a `SnackBar` after an API call), you **MUST** check if the widget is still mounted before using the context.
  ```dart
  await provider.submitJob(url);
  if (!context.mounted) return; // MANDATORY
  ScaffoldMessenger.of(context).showSnackBar(...);
  ```
- **Dio Error Catching**: Catch HTTP errors specifically using `on DioException catch (e)` so you can read `e.response?.statusCode` and `e.response?.data` to display appropriate messages to the user.

## 5. Clean Code
- **Remove all useless default Flutter comments** (like the long explanations in the default `main.dart` file).
- **Avoid nesting UI more than 4-5 indentation levels.** Break them down into smaller, reusable widgets.