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