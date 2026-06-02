# Go Coding Conventions & Standards

> **Tujuan dokumen ini:** Dokumen ini adalah aturan mutlak (STRICT RULES) bagi AI Agent saat melakukan penulisan kode (vibe coding) untuk proyek ClipperAi. Aturan ini harus diterapkan di seluruh file `.go` tanpa pengecualian.

## 1. Error Handling (Wajib)
- **Jangan pernah mengabaikan error.** Dilarang keras menggunakan *blank identifier* (`_`) untuk menekan error yang krusial.
- **Contextual Errors:** Selalu bungkus error dengan konteks yang jelas menggunakan `fmt.Errorf` dan verb `%w` agar stack trace mudah dilacak.
  - *Benar:* `return fmt.Errorf("failed to extract transcript for URL %s: %w", url, err)`
  - *Salah:* `return err`

## 2. Naming Conventions
- **JSON Tags:** Selalu gunakan `snake_case` secara konsisten.
  - *Benar:* ``json:"start_time"``
  - *Salah:* ``json:"startTime"``
- **Structs & Interfaces:** Gunakan `PascalCase` untuk tipe data yang diekspor (*exported*).
- **Variables & Unexported Functions:** Gunakan `camelCase` (contoh: `parseTimeToSeconds`).
- **Acronyms:** Gunakan huruf besar semua untuk akronim standar IT (contoh: `URL`, `ID`, `HTTP`, `JSON`). Gunakan `jobID`, BUKAN `jobId`.

## 3. Logging & Output
- Gunakan standard library `log` bawaan Go (`"log"`).
- Berikan **prefix modul** dalam kurung siku `[...]` pada setiap pesan log agar mudah dibaca di terminal.
  - *Contoh:* `log.Printf("[FFMPEG] Slicing video for job %s started", jobID)`
  - *Contoh:* `log.Printf("[OLLAMA] Failed to parse JSON response: %v", err)`

## 4. Goroutine Safety (Kritis)
- Setiap *goroutine* utama (seperti *background worker* di dalam `ProcessClip`) **WAJIB** memiliki mekanisme `defer` dan `recover` di baris pertamanya.
- Hal ini krusial untuk menangkap *panic* yang tidak terduga dan mencegah seluruh server Go *crash*.
  ```go
  go func() {
      defer func() {
          if r := recover(); r != nil {
              log.Printf("[SERVICE] Panic recovered in background job %s: %v", jobID, r)
              store.FailJob(jobID, "Internal server error during processing")
          }
      }()
      // ... logic goroutine di sini ...
  }()

## 5. Clean Code & Comments
- Asumsikan kode akan di-format menggunakan gofmt. Jangan menulis format spasi atau indentasi yang aneh.
- **Komentar yang Bermakna:** Jangan tambahkan komentar obvious (seperti `// This function returns true`). Berikan komentar HANYA pada logika yang kompleks, seperti alasan regex tertentu digunakan pada parser VTT atau rumus heuristic scoring.

======================================================================

# Flutter Coding Conventions & Standards

> **Tujuan dokumen ini:** Dokumen ini adalah aturan mutlak (STRICT RULES) bagi AI Agent saat menulis kode antarmuka (Frontend) Flutter untuk proyek ClipperAi. 

## 1. Naming & File Structure (Dart Standards)
- **Files & Folders:** Wajib menggunakan `snake_case` (contoh: `home_page.dart`, `clip_provider.dart`).
- **Classes, Enums, & Typedefs:** Wajib menggunakan `PascalCase` (contoh: `ClipGeneratorView`).
- **Variables & Methods:** Wajib menggunakan `camelCase` (contoh: `startPolling()`, `videoUrl`).

## 2. Widget Architecture & UI (Kritis)
- **Gunakan `const` di Mana Pun Memungkinkan:** Untuk mengoptimalkan performa (mencegah *rebuild* yang tidak perlu), setiap *widget* yang tidak bergantung pada *state* dinamis WAJIB menggunakan konstruktor `const`.
- **Ekstraksi Widget, Bukan Helper Method:** Jika sebuah UI menjadi terlalu panjang, ekstrak bagian tersebut menjadi Class `StatelessWidget` terpisah. **DILARANG** memisahkan UI menggunakan *helper method* yang mereturn *widget* (contoh salah: `Widget _buildHeader() { return Text(...); }`).
- **Trailing Commas:** Wajib menambahkan koma `,` di akhir setiap parameter penutup *widget* agar *auto-formatter* (`dart format`) bekerja dengan rapi.

## 3. Separation of Concerns (State Management)
- **Dilarang Menulis Logika Bisnis di UI:** File di dalam folder `views/` hanya boleh berisi komponen visual (UI). Semua pemanggilan API, HTTP Request (Dio), dan logika *polling* **WAJIB** diletakkan di dalam folder `providers/` (menggunakan `ChangeNotifier`).
- **Minimalisasi StatefulWidget:** Gunakan `StatelessWidget` yang dikombinasikan dengan `Consumer` (dari package `provider`) sebisa mungkin. Hindari penggunaan `setState()` kecuali untuk animasi UI lokal yang sangat sederhana.

## 4. Asynchronous & Error Handling
- **Context Mounting Check (Wajib):** Saat menggunakan `await` di dalam fungsi yang membutuhkan `BuildContext` (misalnya menampilkan `SnackBar` setelah API call), kamu **WAJIB** mengecek apakah *widget* masih aktif sebelum menggunakan context.
  ```dart
  await provider.submitJob(url);
  if (!context.mounted) return; // WAJIB ADA
  ScaffoldMessenger.of(context).showSnackBar(...);

- **Dio Error Catching**: Tangkap error HTTP secara spesifik menggunakan on `DioException catch (e)` agar bisa membaca `e.response?.statusCode` dan `e.response?.data` untuk ditampilkan ke user.

## 5. Clean Code
- **Hapus semua komentar bawaan Flutter yang tidak berguna** (seperti komentar panjang di file main.dart bawaan).
- **Jangan menulis UI yang bersarang lebih dari 4-5 level indentasi.** Pecah menjadi widget kecil.