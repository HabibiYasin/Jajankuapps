Berikut adalah isi file **`README.md`** lengkap yang bisa langsung Anda salin dan tempelkan ke dalam file `README.md` di proyek Anda:

```markdown
# 📱 QRIS Expense Tracker

Aplikasi mobile berbasis Flutter yang dirancang untuk mempermudah pencatatan pengeluaran harian secara otomatis melalui *screenshot* struk pembayaran QRIS dari berbagai e-wallet dan perbankan di Indonesia menggunakan teknologi Google ML Kit OCR.

---

## ✨ Fitur Utama

* **🤖 Smart OCR & Multi-App Routing:** Ekstraksi teks otomatis dari gambar menggunakan Google ML Kit yang dilengkapi *router* cerdas untuk mendeteksi berbagai sumber aplikasi pembayaran secara spesifik:
  * ShopeePay
  * BRI / BRImo
  * BCA & BCA Syariah
  * DANA
  * GoPay
  * Mandiri (Livin')
* **🛡️ Koreksi Typo OCR Lanjutan:** Dilengkapi fungsi pembersih teks bawaan untuk mengatasi kesalahan baca mesin OCR yang sering tertukar (seperti huruf `i/l/1`, `g/q`, dan `o/0`) pada nominal, tanggal, dan nama bulan.
* **📊 Dashboard & Statistik Interaktif:** 
  * Ringkasan pengeluaran harian dan bulanan dengan indikator *progress bar* batas anggaran (*budget limit*).
  * Grafik visualisasi statistik pengeluaran 7 hari terakhir.
  * Ringkasan kategori pengeluaran teratas (*Top Categories*).
* **📝 Full CRUD & Manual Edit:** Pengguna dapat melihat detail transaksi, menghapus riwayat, mengubah tanggal transaksi, serta mengedit nama merchant, sumber aplikasi, dan kategori secara manual melalui modal dialog interaktif.
* **📥 Export Data:** Fitur ekspor riwayat transaksi ke format CSV / Google Sheets dengan mudah[cite: 3].
* **🔄 Share Intent Integration:** Mendukung fitur *share* langsung dari galeri HP ke aplikasi untuk langsung memproses struk pembayaran.
* **💾 Database Lokal (SQLite):** Penyimpanan data offline yang aman dan cepat menggunakan `sqflite` dengan dukungan migrasi otomatis versi database.

---

## 🛠️ Arsitektur Proyek

Proyek ini menerapkan prinsip ***Clean Architecture*** sederhana untuk memisahkan logika antarmuka, model data, dan layanan pemrosesan:

```text
lib/
│
├── models/
│   └── transaction_model.dart      # Struktur data transaksi utama
│
├── screens/
│   ├── dashboard_screen.dart       # Tampilan utama, ringkasan, dan riwayat
│   ├── scanner_screen.dart         # Layar pemindaian dan debug teks OCR
│   └── settings_screen.dart        # Pengaturan profil dan limit anggaran
│
├── services/
│   ├── parsers/                    # Parser khusus per aplikasi pembayaran
│   │   ├── bca_parser.dart
│   │   ├── bca_syariah_parser.dart
│   │   ├── bri_parser.dart
│   │   ├── dana_parser.dart
│   │   ├── gopay_parser.dart
│   │   ├── mandiri_parser.dart
│   │   └── shopeepay_parser.dart
│   │
│   ├── database_helper.dart        # Pengelolaan SQLite & migrasi tabel
│   ├── export_service.dart         # Logika ekspor CSV/Sheet[cite: 3]
│   ├── ocr_service.dart            # Integrasi ML Kit & pembersih typo tanggal
│   └── qris_parser.dart            # Router utama pengarah parser aplikasi
│
└── main.dart                       # Titik masuk utama aplikasi & State Management

```

---

## 🚀 Memulai (Getting Started)

Ikuti langkah-langkah berikut untuk menjalankan proyek ini di perangkat lokal Anda:

### Prasyarat

* Flutter SDK (Versi terbaru disarankan)
* Android Studio / VS Code
* Perangkat Android / Emulator (mendukung minSDK untuk SQLite dan ML Kit)

### Langkah Instalasi

1. Clone repository ini atau buka folder proyek di terminal Anda.
2. Jalankan perintah untuk mengunduh seluruh dependensi:
```bash
flutter pub get

```


3. Hubungkan perangkat fisik atau nyalakan emulator Android.
4. Jalankan aplikasi dengan perintah:
```bash
flutter run

```



---

## 📦 Build APK (Release Mode)

Untuk menghasilkan file APK siap instal (*release*), jalankan perintah berikut di terminal:

```bash
flutter build apk --release

```

File APK hasil *build* akan tersedia di direktori:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 👨‍💻 Kontributor

* **Habibi Yasin** — *QA Engineer & Developer*

---

## 📄 Lisensi

Proyek ini dikembangkan untuk kebutuhan pribadi dan portofolio profesional.

```

```