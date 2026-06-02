# Flutter Frontend — Executive Summary

Dokumen ini merangkum keseluruhan arsitektur, teknologi, dan alur kerja (workflow) dari klien antarmuka **Local AI Clipper** yang dibangun menggunakan Flutter Web.

---

## 🛠️ Tech Stack & Library Utama

*   **Framework**: Flutter (Target: Web / HTML Renderer)
*   **State Management**: `provider` (Sederhana, reaktif, dan mudah di-maintain)
*   **Network / HTTP**: `dio` (Menangani *request* asinkron dan polling)
*   **Pemutar Video**: `media_kit` & `media_kit_video` (Mendukung performa pemutaran video tingkat tinggi di desktop & web)
*   **Utilitas Tambahan**:
    *   `google_fonts`: Tipografi modern (Inter/Outfit).
    *   `flutter_dotenv`: Menyimpan konfigurasi *Environment Variable* (seperti Base URL API).
    *   `flutter_spinkit`: Animasi transisi/loading.
    *   `shared_preferences`: *Local storage* untuk fitur *session recovery*.
    *   `url_launcher`: Memfasilitasi tombol unduh video hasil.

---

## 📂 Struktur Direktori (Feature-Based)

Pendekatan struktur yang digunakan adalah pemisahan berdasarkan fitur (*Feature-Sliced*), sehingga seluruh komponen yang berhubungan berada di satu folder.

```text
frontend/lib/
├── core/
│   ├── api_client.dart       # Konfigurasi Dio (BaseURL, Headers, Timeout)
│   └── theme.dart            # Sistem desain (Premium Dark Theme, Palette)
├── features/
│   └── clip_generator/
│       ├── models/
│       │   └── job_response.dart   # Model pemetaan JSON respon dari Backend
│       ├── providers/
│       │   └── clip_provider.dart  # Pengelola logika HTTP, Polling, dan State (UIState)
│       └── views/
│           ├── home_page.dart      # Halaman utama (Input Form & Layout Mode Chips)
│           ├── loading_view.dart   # Animasi loading saat menunggu proses backend
│           └── result_view.dart    # Pemutar video hasil (TikTok-style UI Stack)
└── main.dart                 # Inisialisasi awal (MediaKit, dotenv) & routing
```

---

## ⚙️ Alur Kerja Aplikasi (Workflow)

Aplikasi memiliki satu *State Manager* utama bernama `ClipProvider` yang mengendalikan alur antarmuka secara dinamis melalui status `UIState` (idle, submitting, loading, result, error).

### 1. Tahap Input & Riwayat Pekerjaan (Idle / Submitting)
*   Berada di `home_page.dart`.
*   Menampilkan **Kartu Riwayat Pekerjaan Aktif**. Daftar pekerjaan (maksimal 3 terakhir) disimpan di `shared_preferences` sehingga pengguna tidak kehilangan *progress* walaupun memuat ulang (*refresh*) browser.
*   Pengguna memasukkan URL YouTube dan memilih **Tipe Video / Layout Mode** (Solo, Presentasi, atau Podcast).
*   Saat tombol Generate ditekan, `ClipProvider` melakukan `POST /api/v1/clips`.

### 2. Tahap Pemrosesan (Loading & Polling)
*   Jika backend mengembalikan kode `202 Accepted` beserta `job_id`, antarmuka langsung berganti menjadi `loading_view.dart`.
*   Di belakang layar, `ClipProvider` memulai *Timer* (Polling) yang memanggil `GET /api/v1/clips/:job_id` setiap 5 detik. Terdapat penanganan error `404 Not Found` untuk mendeteksi apabila server di-*restart* agar aplikasi tidak *infinite loop*.
*   Layar ini memberikan informasi secara teks kepada pengguna mengenai apa yang sedang dilakukan oleh server lokal.
*   Jika pengguna menekan tombol **Batal**, aplikasi akan menembak endpoint pembatalan (`DELETE /api/v1/clips/:id`) untuk menghentikan proses backend (*CPU saving*) lalu menghapus *cache* sesi dari memori lokal.

### 3. Tahap Selesai (Result / TikTok UI)
*   Saat hasil *polling* dari backend mengembalikan status `completed`, state aplikasi berubah menjadi `result`.
*   UI bertransisi secara mulus ke `result_view.dart`.
*   **Result View** menggunakan tata letak *Stack* bergaya **TikTok/Reels**:
    *   **Layer Bawah**: Pemutar video (`media_kit`) yang di-set ke mode `BoxFit.cover` (memenuhi layar) tanpa kontrol video bawaan (*NoVideoControls*).
    *   **Layer Tengah**: Efek *Gradient Overlay* dari warna transparan ke hitam agar teks mudah dibaca.
    *   **Layer Atas (Kiri)**: Informasi klip berhasil digenerate.
    *   **Layer Atas (Kanan)**: Deretan aksi vertikal bulat (Download, Copy Link, Buat Baru) bergaya interaksi media sosial.

---

## 🎨 Konvensi Desain (UI/UX)

*   **Tema Gelap (Dark Mode)**: Menggunakan kombinasi warna hitam dan ungu gelap/neon cyan (`#0F0F12`, `#8B5CF6`) untuk menciptakan kesan premium dan modern.
*   **Responsivitas**: Tampilan dipusatkan di layar (`ConstrainedBox` dengan `maxWidth: 450`/`900` tergantung halaman) sehingga tidak melebar secara canggung saat dibuka pada resolusi desktop *ultrawide*, namun tetap pas apabila kelak diaplikasikan ke perangkat *mobile*.
*   **Animasi**: Memanfaatkan transisi otomatis yang dimediasi oleh `switch(state)` tanpa tumpukan sistem navigasi yang kompleks (Single Page Application murni).
