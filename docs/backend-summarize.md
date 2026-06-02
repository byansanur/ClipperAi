# Backend MVP Summary

Dokumen ini merangkum penyelesaian pengembangan fase MVP untuk **Backend ClipperAi**.

## 🎯 Tujuan yang Dicapai
Backend ClipperAi saat ini sudah sepenuhnya operasional untuk menerima URL YouTube, menganalisa momen terbaik secara cerdas, dan menghasilkan klip vertikal pendek (9:16) secara otomatis dan seutuhnya berjalan secara lokal.

## 🛠 Tech Stack & Tools
- **Bahasa**: Go 1.21+
- **Web Framework**: Gin HTTP
- **AI/LLM**: Ollama (Lokal, Model default: `llama3.2`)
- **Media Processing**: FFmpeg & yt-dlp
- **Konfigurasi**: `godotenv` (.env file)

## ✨ Fitur Utama yang Berhasil Diimplementasikan

1. **Asynchronous API (Polling & Cancellation)**
   - `POST /api/v1/clips`: Menerima URL video, melakukan generate Job ID (UUID), dan langsung mengembalikan HTTP 202 Accepted.
   - `GET /api/v1/clips/:id`: API untuk mengecek status job (`processing`, `completed`, `failed`).
   - `DELETE /api/v1/clips/:id`: API untuk membatalkan proses latar belakang secara paksa (*Cancel Job*).

2. **Smart Pipeline Processing**
   - **Download Transcript**: Mengambil subtitle otomatis langsung dari YouTube.
   - **Heuristic Scoring**: Memecah transcript ke dalam *chunk* 5 menit, lalu memberikan skor berdasarkan tanda baca (tanda seru/tanya) dan keyword emosional (*wow, gila, dsb*).
   - **LLM Timestamp Extraction**: Mengirim chunk terbaik ke Ollama untuk mencari 30-60 detik momen paling menarik secara cerdas.
   - **Video Slicing & Cropping**: Mengunduh video menggunakan yt-dlp, memotongnya sesuai timestamp LLM, dan mengubah *aspect ratio* ke 9:16 menggunakan FFmpeg.

## 🐛 Masalah Kritis yang Berhasil Diselesaikan

Selama fase MVP, beberapa *edge cases* dan *bug* berhasil diatasi agar sistem menjadi *robust*:

1. **Halusinasi LLM pada Timestamp**
   - *Masalah*: LLM mengarang timestamp (seperti 10 jam) karena ia tidak punya referensi waktu asli.
   - *Solusi*: Mengubah parser VTT untuk menyisipkan penanda waktu inline `[HH:MM:SS]` secara langsung ke dalam teks transcript, dan mengupdate prompt agar LLM hanya diizinkan memilih waktu dari penanda tersebut.

2. **Video Tidak Bisa Diputar di QuickTime (Apple)**
   - *Masalah*: Video output dari FFmpeg ditolak oleh QuickTime player macOS/iOS.
   - *Solusi*: Memaksa FFmpeg menggunakan format pixel standar Apple (`-pix_fmt yuv420p`) dan memastikan dimensi video selalu genap (`crop=floor(ih*9/16/2)*2:floor(ih/2)*2`).

3. **Error "HTTP 429: Too Many Requests" dari yt-dlp**
   - *Masalah*: YouTube melakukan rate-limit saat program mencoba mendownload multi-bahasa secara cepat.
   - *Solusi*: Mengimplementasikan "Toleransi Kesalahan Parsial". Jika bahasa EN gagal didownload, selama bahasa ID sukses didapatkan, sistem akan terus memproses video tanpa menggagalkan job.

4. **Konfigurasi Fleksibel**
   - Menghapus konfigurasi yang sepenuhnya di-hardcode ke sistem berbasis `godotenv` (`.env` file) agar pengguna mudah mengubah `PORT`, `OLLAMA_MODEL`, dan direktori output tanpa harus *recompile* kode.

5. **Resource Leak Prevention (Context Cancellation)**
   - *Masalah*: Jika pengguna menekan tombol Batal di Frontend, backend tetap memproses FFmpeg dan menghabiskan CPU secara percuma.
   - *Solusi*: Menggunakan injeksi `context.Context` dengan `CancelFunc` ke dalam `exec.CommandContext` sehingga ketika API `DELETE` dipanggil, yt-dlp dan FFmpeg otomatis dibunuh (*SIGKILL*) secara terprogram.

## 📌 Status Saat Ini & Langkah Selanjutnya
- **Fase Backend**: **SELESAI ✅**
- **Langkah Selanjutnya**: Melanjutkan ke implementasi Frontend MVP (React/Vue/Vanilla JS tergantung preferensi pengguna) yang akan mengonsumsi API `POST /api/v1/clips` dan polling status hingga file video siap ditampilkan.
