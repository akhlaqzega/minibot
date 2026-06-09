# 🤖 MiniBot App

**MiniBot App** adalah aplikasi mobile berbasis **Flutter** yang berfungsi sebagai dashboard kontroler dan monitoring real-time untuk robot pintar **MiniBot** menggunakan protokol **MQTT** dan **Google Gemini AI**. 

Aplikasi ini menggunakan tema *Cyberpunk / Dark SCADA* yang modern, dirancang untuk memberikan kendali manual dan otomatisasi cerdas berbasis kecerdasan buatan langsung melalui interaksi suara (Speech-to-Text).

---

## ✨ Fitur Utama

1. **🔒 Firebase Authentication**
   * Pendaftaran akun baru dan login aman menggunakan **Firebase Auth**.
2. **📡 Real-Time Telemetry Monitor (MQTT)**
   * Koneksi otomatis ke MQTT Broker (`test.mosquitto.org`).
   * Menampilkan telemetri perangkat secara real-time seperti **Jarak Sensor Ultrasonik (cm)**, **Kekuatan Sinyal Wifi (dBm)**, dan status koneksi ESP32.
3. **🎙️ Voice AI Chat (Gemini AI)**
   * Menggunakan modul **Speech-to-Text (STT)** untuk merekam suara pengguna.
   * Mengintegrasikan **Gemini 3.1 Flash Lite API** untuk memproses jawaban pintar.
   * Hasil olah pesan akan dikirim kembali melalui MQTT untuk menggerakkan ekspresi fisik robot dan menampilkan teks jawaban di layar OLED robot.
4. **🎮 Manual Override Expression**
   * Tombol pintas untuk memicu emosi/ekspresi tertentu pada robot secara instan (`HAPPY`, `SAD`, `SCARED`, dan `NORMAL`).

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
Klon repositori ini ke komputer lokal Anda menggunakan Git:
```bash
git clone https://github.com/akhlaqzega/minibot.git
cd minibot
```

### 2. Dapatkan Package Dependencies
Jalankan perintah berikut di folder proyek untuk mengunduh semua package Flutter yang dibutuhkan:
```bash
flutter pub get
```

### 3. Konfigurasi API Key Gemini
Aplikasi ini membutuhkan API Key Gemini dari **Google AI Studio**.
1. Dapatkan API Key Anda di: [Google AI Studio API Key](https://aistudio.google.com/app/apikey).
2. Buka file [dashboard_page.dart](file:///d:/Projek%20Flutter/minibot_app/lib/pages/dashboard_page.dart).
3. Cari baris berikut (sekitar baris ke-15):
   ```dart
   const _geminiApiKey   = 'GANTI_DENGAN_API_KEY_ANDA';
   ```
4. Ganti `'GANTI_DENGAN_API_KEY_ANDA'` dengan API Key yang telah Anda dapatkan.

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
│   ├── auth_service.dart     # Logika Firebase Auth (Sign In, Sign Up, Sign Out)
│   ├── login_screen.dart     # Halaman Login (Cyberpunk UI)
│   └── register_screen.dart  # Halaman Pendaftaran Akun Baru
├── pages/
│   └── dashboard_page.dart   # Dashboard Utama (SCADA Telemetry, MQTT Client, STT & Gemini AI)
├── firebase_options.dart     # Konfigurasi Firebase untuk Android, iOS, & Web
└── main.dart                 # Titik masuk utama aplikasi (Entrypoint)
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
