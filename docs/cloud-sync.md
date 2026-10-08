# Sinkronisasi akun Jajanku

Project: `jajanku-26976`, database `(default)` di `asia-southeast2`.

## Penyimpanan

- Guest tetap memakai SQLite `qris_tracker.db`. Upgrade versi 3 menambahkan
  tabel `cloud_imports` tanpa menghapus transaksi yang sudah ada.
- Setelah login, transaksi berasal dari `users/{uid}/transactions/{id}` dan
  budget dari `users/{uid}/settings/budget`. ID dokumen dibuat oleh Firestore.
- Firestore Android/iOS menyediakan cache dan antrean perubahan offline.
  Listener metadata membedakan data cache, perubahan tertunda, dan data server.
- Riwayat, budget dan preview struk dibersihkan saat akun berganti. Operasi
  edit dan OCR memeriksa pemilik sebelum menulis. Listener lama dibatalkan dan
  hasil async lama diabaikan.
- Logout menunggu konfirmasi perubahan tertunda maksimal 10 detik. Jika belum
  selesai, pengguna diminta menghubungkan internet sebelum keluar.
- Sinkronisasi mengikuti lifecycle SDK aplikasi, bukan layanan background
  yang selalu aktif. Perubahan dari HP lain diterima saat aplikasi terhubung.
- Foto struk dan nama profil kustom belum disinkronkan; fitur ini mencakup
  data transaksi dan limit budget. Guest memiliki budget lokal terpisah.

## Data Guest dan akun

Data Guest tetap tersimpan lokal dan terpisah dari data akun. Login menampilkan
transaksi akun tanpa memindahkan transaksi Guest. Keluar dari akun untuk melihat
riwayat Guest kembali. Fitur pemindahan Guest ke akun sudah dihapus.

Tabel lokal `cloud_imports` dan filter baris yang pernah dicadangkan tetap
dipertahankan untuk kompatibilitas data versi lama. Aplikasi tidak lagi membuat
pemindahan baru. Penanda impor cloud lama tetap dibersihkan saat hapus akun.

## Aturan akses

`firestore.rules` membatasi akses berdasarkan UID dan memvalidasi tipe/batas
field. Lokasi selain transaksi, budget, dan penanda impor tidak mendapat akses.
Penanda impor tidak dapat diubah atau dihapus oleh aplikasi.

Deploy khusus aturan:

```powershell
firebase deploy --only firestore:rules --project jajanku-26976
```

## Verifikasi

```powershell
flutter analyze
flutter test test/account_cloud_test.dart test/budget_notification_service_test.dart test/widget_test.dart
firebase emulators:exec --only firestore --project demo-jajanku --config firebase.emulator.json "node test/firestore_rules_test.cjs"
flutter build apk --debug
```

Tes Dart memakai Firestore palsu untuk sinkronisasi dua klien, isolasi akun,
CRUD dan validasi budget. Aturan akses diuji terpisah pada
emulator resmi dengan 27 pemeriksaan (tanpa data produksi).

Uji perangkat: login, ubah budget,
dan pastikan status menunjukkan tersinkron. Login akun yang sama di HP kedua
untuk memeriksa data. Uji tambah/edit/hapus saat offline, sambungkan kembali,
dan periksa sinkronisasi. Ganti akun untuk memeriksa pemisahan riwayat.
