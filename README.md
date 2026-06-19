# 🤖 MiniBot App

**MiniBot App** adalah aplikasi mobile berbasis **Flutter** yang berfungsi sebagai dashboard kendali, monitoring real-time, dan asisten robot pintar berbasis IoT (**MiniBot**) menggunakan protokol **MQTT**, **Google Gemini AI**, dan **Cloud Firestore**.

Aplikasi ini mengusung desain premium bergaya *Cyberpunk / Dark SCADA* dengan dukungan tema adaptif (terang & gelap), serta navigasi interaktif untuk memberikan pengalaman pengguna yang modern dan futuristik.

---

## ✨ Fitur Utama

1. **🔒 Firebase Authentication**
   * Pendaftaran akun baru dan login aman menggunakan email & password melalui **Firebase Auth**.
   * Dukungan integrasi masuk cepat menggunakan **Google Sign-In**.

2. **📡 Real-Time Telemetry Monitor (MQTT)**
   * Koneksi otomatis ke MQTT Broker publik (`test.mosquitto.org`).
   * Menampilkan telemetri perangkat secara real-time:
     * **Jarak Sensor Ultrasonik (cm)**
     * **Kekuatan Sinyal Wi-Fi (dBm)** dengan indikator kualitas sinyal (*Excellent, Good, Poor*).
     * **Status Emosi Aktif Robot** (`HAPPY`, `SAD`, `SCARED`, `NORMAL`).

3. **🎙️ Voice AI Chat & OLED Output (Gemini AI)**
   * Menggunakan modul **Speech-to-Text (STT)** untuk merekam perintah suara pengguna dalam Bahasa Indonesia.
   * Mengintegrasikan **Gemini 3.1 Flash Lite API** dengan *system prompt* kustom untuk memproses jawaban pintar yang seru dan ekspresif.
   * Mengirimkan tag emosi secara otomatis ke ESP32 via MQTT untuk memicu ekspresi wajah robot, dilanjutkan dengan pengiriman teks jawaban untuk ditampilkan di layar OLED robot.

4. **🎮 Manual Override Expression**
   * Tombol pintas interaktif untuk memicu emosi/ekspresi tertentu pada robot secara instan (`HAPPY`, `SAD`, `SCARED`, dan `NORMAL`) lewat MQTT.

5. **📅 Histori Aktivitas & Filter Tanggal (Firestore)**
   * Menyimpan log telemetri dan log percakapan AI secara otomatis ke **Cloud Firestore** berdasarkan UID pengguna yang sedang masuk.
   * Halaman histori aktivitas mengelompokkan log secara rapi berdasarkan hari (Hari ini, Kemarin, Tanggal sebelumnya).
   * Fitur **Kalender Filter Tanggal** pada *AppBar* untuk menyaring riwayat berdasarkan Hari, Bulan, dan Tahun tertentu.
   * Opsi pembersihan riwayat (*Clear History*) instan dengan konfirmasi aman.

6. **🎨 Kustomisasi Tema & Kombinasi Warna Neon**
   * **Mode Terang / Gelap (Light & Dark Mode)** yang dapat diubah secara dinamis langsung dari navigasi drawer kiri.
   * **Preset Warna Neon Cyberpunk**:
     * *Cyberpunk Classic* (Biru Neon & Merah Neon)
     * *Matrix Green* (Hijau Neon & Biru Neon)
     * *Volt Gold* (Kuning Neon & Oranye Neon)
     * *Sunset Purple* (Ungu Neon & Magenta Neon)
   * Semua UI berubah warna secara reaktif berdasarkan preset yang dipilih.

7. **🖼️ Edit Profil & Unggah Foto Galeri (Firebase Storage)**
   * Dialog profil untuk mengubah Nama Tampilan (*Display Name*).
   * Pilihan avatar bot cepat menggunakan DiceBear API.
   * **Pilih Foto Kustom dari Galeri**: Mengakses galeri handphone secara langsung, mengompres kualitas gambar, dan mengunggahnya secara aman ke **Firebase Storage** (`users/{uid}/profile.jpg`).

---

## 🛠️ Persyaratan Sistem

Sebelum menjalankan proyek ini, pastikan komputer Anda telah terinstal:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi stabil terbaru)
* [Dart SDK](https://dart.dev/get-started/sdk)
* Android Studio / VS Code dengan ekstensi Flutter & Dart
* Emulator Android/iOS atau perangkat fisik untuk testing

---

## 🚀 Cara Menjalankan Proyek

### 1. Klon Repositori
Klon repositori ini ke komputer lokal Anda:
```bash
git clone https://github.com/akhlaqzega/minibot.git
cd minibot
```

### 2. Dapatkan Package Dependencies
Instal semua library Flutter yang dibutuhkan:
```bash
flutter pub get
```

### 3. Konfigurasi API Key Gemini
Aplikasi ini membutuhkan API Key Gemini dari **Google AI Studio**.
1. Dapatkan API Key Anda di: [Google AI Studio API Key](https://aistudio.google.com/app/apikey).
2. Buka file [dashboard_page.dart](file:///d:/Projek%20Flutter/minibot_app/lib/pages/dashboard_page.dart).
3. Cari baris berikut (sekitar baris ke-22):
   ```dart
   const _geminiApiKey   = 'AQ.Ab8RN6...';
   ```
4. Ganti dengan API Key yang telah Anda miliki.

### 4. Jalankan Aplikasi
Hubungkan perangkat HP fisik (pastikan USB Debugging aktif) atau jalankan emulator Anda, kemudian jalankan perintah:
```bash
flutter run
```

---

## 📂 Struktur Proyek Utama

```text
lib/
├── auth/
│   ├── auth_service.dart     # Logika Firebase Auth & Google Sign-In
│   ├── login_screen.dart     # Halaman Login (Cyberpunk UI dengan logo baru)
│   └── register_screen.dart  # Halaman Pendaftaran Akun Baru
├── pages/
│   ├── dashboard_page.dart   # Dashboard Utama (SCADA Telemetry, MQTT, STT & Dialog Edit Profil Galeri)
│   └── history_page.dart     # Halaman Histori Aktivitas dengan Filter Kalender
├── theme/
│   └── theme_service.dart    # State Management & Preset Warna Tema Adaptif
├── firebase_options.dart     # Konfigurasi Platform Firebase
└── main.dart                 # Entrypoint Utama Aplikasi (MaterialApp dengan Theme Listener)
```

---

## 🔌 Detail Topik MQTT & Struktur JSON

Aplikasi ini mendengarkan (*subscribe*) dan mengirim data (*publish*) pada topik:
* **Topik MQTT:** `minibot/trkj/zega`
* **Broker:** `test.mosquitto.org`

### Format Telemetri Masuk (dari ESP32 ke App):
```json
{
  "status": "happy",
  "jarak": 45,
  "sinyal": -60
}
```

### Format Perintah Keluar (dari App ke ESP32):
* Perubahan Emosi: `happy`, `sad`, `scared`, `normal`
* Teks Tampilan OLED: `msg:<jawaban_ai>`
