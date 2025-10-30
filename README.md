# Seditor — Swift‑crafted Web Playground with AI

> Playground berbasis **SwiftUI** untuk menyusun halaman web (HTML/CSS/JS) dengan **live preview** dan **asisten AI (Gemini)** terintegrasi — dirancang agar prototyping web jadi lebih cepat, iteratif, dan menyenangkan langsung dari perangkat Apple.

---

## Ringkasan
- **Platform**: iOS / iPadOS (SwiftUI, `async/await`)
- **Bahasa**: Swift
- **AI**: Google Gemini — Generative Language API `v1beta`
- **Ketergantungan pihak ketiga**: *Tidak ada* (native frameworks)

**Demo singkat alur kerja**: kelola proyek → buat file → tulis kode → lihat live preview → minta AI menyusun HTML yang valid → terapkan hasilnya ke file aktif. Semua tanpa meninggalkan aplikasi.

---

## Fitur Utama
### Editor & Preview
- Editor HTML/CSS/JS dengan preferensi tampilan (ukuran font, status bar, *line numbers*).
- **Live Preview** HTML:
  - **Inline** pada layout lebar.
  - **Layar penuh** pada layout sempit.

### Manajemen Proyek
- Multi‑project (disimpan sebagai JSON di `Documents/SeditorProjects`).
- Buat, pilih, ganti nama, dan hapus proyek.

### Manajemen File & Folder
- Buat / *rename* / *duplicate* / hapus file.
- Buat folder dan pindahkan file.
- Impor file (`.html` / `.css` / `.js` / `.txt`) dari Files.
- **Starter template** siap pakai.

### AI Companion (Gemini)
- Menyusun **rencana analisis** berdasar kompleksitas instruksi.
- **Audit konteks** (opsional) & analisis potongan kode (*chunk*) cerdas.
- **Strategi perubahan** yang terstruktur.
- **Generasi HTML end‑to‑end** dalam blok kode Markdown.
- **Validasi struktur HTML** + perbaikan otomatis.
- **Patch otomatis**: *full file* atau *edits* per rentang baris.
- **Riwayat percakapan per file** (persisten).

### Keamanan API Key
- Disimpan aman di **Keychain** (bukan `UserDefaults`).

---

## Tangkapan Layar
> Tambahkan screenshot / GIF di bagian ini untuk menarik minat pengguna:
- Dashboard dengan editor & preview.
- Sidebar file/folder & aksi cepat.
- Lembar **AI Companion** saat menghasilkan HTML.

---

## Arsitektur Singkat
```
Views
├─ ContentView              // entry + splash
├─ DashboardView            // workspace utama (toolbar, sidebar, editor, preview)
├─ FilesSidebarView         // daftar file/folder, aksi cepat, pengaturan editor
└─ AIAgentSheet             // percakapan AI, ringkasan langkah, patch code

ViewModel
└─ DashboardViewModel       // state pusat (files/folders/projects, AI settings, preview, importer, sheet)

Services
├─ GeminiClient             // HTTP client ke Generative Language API (fetchModels, generateResponse)
├─ ProjectStore             // serialisasi snapshot per project (metadata.json + workspace.json)
└─ KeychainHelper           // simpan/baca API key dengan aman

Models
├─ CodeFile, CodeFolder, CodeLanguage   // representasi file & tipe bahasa (HTML/CSS/JS)
├─ ProjectMetadata, WorkspaceSnapshot   // metadata + isi workspace
├─ AISettings                           // pengaturan AI (model, apiKey, temperature, topP)
└─ PendingChange, CodeEditOperation     // patch perubahan (full content / edits)
```
> Catatan: Penjelasan ini merangkum alur & peran komponen berdasarkan referensi pemakaian pada file yang tersedia.

---

## Struktur Proyek (Ringkas)
```
Seditor/
├─ ContentView.swift                 // Entry view + splash
├─ DashboardView.swift               // Workspace UI (editor + preview + sidebar)
├─ DashboardViewModel.swift          // State & aksi utama (files/folders/projects/AI)
├─ FilesSidebarView.swift            // Sidebar untuk file/folder/aksi/pengaturan editor
├─ AIAgentSheet.swift                // UI + orkestrasi agen AI (analisis → kode → validasi → patch)
├─ GeminiClient.swift                // Klien HTTP Gemini (models, generateContent)
├─ AISettings.swift                  // Model konfigurasi AI (model/apiKey/temperature/topP)
├─ CodeModels.swift                  // CodeFile, CodeFolder, CodeLanguage (+ starter templates)
├─ ProjectStore.swift                // Penyimpanan project/snapshot (JSON)
├─ ProjectMetadata.swift             // Metadata project
├─ KeychainHelper.swift              // Utilitas Keychain
└─ Components/                       // AISettingsSheet, EditorWorkspaceView, NewFileSheet, NewFolderSheet,
                                    // ProjectManagerView, WebPreviewView, DashboardTheme, EditorPreferences,
                                    // AIConversationStore, PendingChange, CodeEditOperation, WorkspaceSnapshot, ...
```

---

## Persyaratan
- **Xcode 15+** (disarankan).
- **iOS/iPadOS 17+** (atau sesuai minimum deployment target di project).
- Akses internet untuk Gemini API.
- **API Key** Google Generative Language (aktifkan API di Google Cloud).

---

## Cara Menjalankan
1. Buka proyek di **Xcode**.
2. Pilih target iOS/iPadOS, lalu **Run** di simulator atau perangkat.
3. (Opsional) Jika ada dependency SPM lain, Xcode akan mengunduh otomatis.

---

## Menyiapkan API Gemini
1. Buka aplikasi, ketuk ikon **AI** (brain/sparkles) untuk membuka *AI Companion*.
2. Buka **Pengaturan AI**:
   - Isi **API key** (disimpan di Keychain).
   - Pilih **model** (default: `gemini-2.0-flash`).
   - Atur parameter **temperature** dan **topP**.
3. Pastikan project **Google Cloud** kamu sudah mengaktifkan **Generative Language API**.

---

## Cara Pakai (Alur Singkat)
### 1) Buat / Impor File
- Buka sidebar (ikon menu) atau gunakan *pinned sidebar* (layar lebar).
- Gunakan **File Baru**, **Folder Baru**, atau **Impor File**.
- Format didukung: `.html`, `.css`, `.js`, `.txt`.
- Gunakan **Load Template** untuk starter project (`index.html`, `styles.css`, `scripts.js`).

### 2) Edit & Preview
- Pilih file untuk dibuka di editor.
- Aktifkan **Preview**:
  - **Inline** pada layout lebar (bila ruang cukup).
  - **Tombol Preview** untuk layar sempit.
- Dokumen final:
  - Mengambil **HTML pertama** sebagai *body*.
  - Menyisipkan **CSS** dalam `<style>` dan **JS** dalam `<script>` di `<head>` / `<body>` sesuai *builder*.

### 3) AI Companion (Gemini)
- Buka **AI Companion**.
- Pastikan ada **file aktif** dan **API key** terisi.
- Tulis instruksi, contoh: _"Buat landing page simpel dengan hero, grid 3 kolom, footer."_.
- **Pipeline AI** (ringkas):
  1. Profil kompleksitas (heuristik)
  2. Rencana analisis
  3. Audit konteks (opsional)
  4. Pemetaan struktur file
  5. Analisis potongan kode (opsional)
  6. Strategi perubahan
  7. Generasi HTML (blok kode Markdown)
  8. Validasi struktur + auto‑fix
  9. Patch otomatis (full/edits per rentang baris)

---

## Keamanan & Privasi
- **API key** disimpan di **Keychain**.
- Konten proyek diserialisasi ke **JSON** di direktori aplikasi (`Documents/SeditorProjects`).
- Pertimbangkan untuk menambahkan opsi *redaction* atau *local-only mode* (tanpa mengirim konteks file) jika diperlukan.

---

## Roadmap (Usulan)
- [ ] **macOS** target (SwiftUI multi‑platform) + *drag & drop* antar jendela.
- [ ] **Plugin AI**: dukungan model lain (mis. OpenAI / lokal LLM via server lokal).
- [ ] **Validator** tambahan: HTML/CSS linting, aksesibilitas dasar (ARIA checks).
- [ ] **Ekspor** proyek sebagai ZIP + share sheet.
- [ ] **Unit tests** untuk `ProjectStore`, `GeminiClient`, & patch engine.

---

## FAQ (Singkat)
**Q:** Apakah butuh akun berbayar untuk Gemini?  
**A:** Bergantung kuota & kebijakan Google Cloud project kamu. Pastikan *billing* & API diaktifkan.

**Q:** Bisa jalan offline?  
**A:** Editor & preview bisa; namun fitur AI memerlukan koneksi internet.

**Q:** Apakah ada ketergantungan pihak ketiga?  
**A:** Tidak — seluruhnya memanfaatkan native frameworks.

---
