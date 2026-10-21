# Wajib update Android

Aplikasi memeriksa dokumen Firestore `app_config/android_update` saat dibuka,
ketika kembali aktif, dan ketika pengguna menekan Periksa lagi. Pemeriksaan
berlaku sebelum login, termasuk Guest. Gate berada di atas Navigator sehingga
halaman yang sudah terbuka dan dialog tidak dapat menutupi halaman wajib update.
Tombol Update sekarang membuka halaman aplikasi sesuai package di Google Play.
Ini bukan instalasi otomatis atau integrasi Play Immediate Update.

## Persiapan

1. Deploy rules ke Firebase dev dan uji terlebih dahulu:

   ```powershell
   firebase deploy --only firestore:rules --project jajanku-dev-25ae6
   ```

2. Di Firebase Console dev, buka Firestore Database > Data, buat collection
   `app_config`, lalu document `android_update` dengan field:

   | Field | Tipe | Nilai awal |
   |---|---|---|
   | `enabled` | boolean | `false` |
   | `minimumBuildNumber` | number (integer) | `1` |

   Hanya dokumen ini yang dapat dibaca publik. Pengguna aplikasi tidak dapat
   membuat, mengubah, menghapus, atau melakukan list collection konfigurasi.
   Ubah aturan melalui Console/Admin SDK saja. Jangan simpan rahasia di dokumen ini.

3. Pada dev, ubah minimum menjadi nomor build terpasang + 1 dan `enabled` menjadi
   `true`. Uji halaman pemblokiran, tombol kembali, serta matikan aturan lagi
   untuk menguji Periksa lagi. Package dev tidak diterbitkan di Play Store;
   gunakan build dev APK yang lebih baru untuk menguji pembaruan lokal.

4. Deploy rules prod dan buat dokumen awal yang sama dengan `enabled: false`:

   ```powershell
   firebase deploy --only firestore:rules --project jajanku-26976
   ```

   Kode ini tidak men-deploy rules atau membuat dokumen server secara otomatis.

## Mengaktifkan sesudah rilis

Nomor yang dibandingkan adalah **versionCode**, yaitu angka setelah `+` pada
`pubspec.yaml`, bukan nama versi. Contoh `1.1.0+3` memiliki nomor build `3`.
Jika memakai `--build-number`, yang dibandingkan adalah nilai override tersebut.

1. Rilis build yang sudah mengandung mekanisme ini. Versi lama yang belum
   mengandung mekanisme tidak dapat dipaksa lewat pengaturan ini.
2. Untuk rilis berikutnya, naikkan nomor build dan unggah AAB prod ke Google Play.
3. Tunggu sampai update tersedia untuk semua pengguna sasaran, termasuk selesai
   rollout. Jangan menaikkan minimum ketika update belum tersedia bagi mereka.
4. Misalnya build baru `4` sudah tersedia, ubah dokumen **prod** menjadi:

   ```json
   {"enabled": true, "minimumBuildNumber": 4}
   ```

   Build di bawah `4` yang memiliki mekanisme ini akan diblokir pada pemeriksaan
   berikutnya. Build `4` dan yang lebih baru tetap bisa masuk.

Untuk membatalkan kewajiban update, ubah `enabled` menjadi `false`, lalu pengguna
menekan Periksa lagi atau membuka ulang aplikasi dalam keadaan online. Menghapus
dokumen dari server juga menonaktifkan aturan saat pemeriksaan berhasil.

## Koneksi dan cache

Pembacaan server dibatasi 6 detik; pembacaan informasi paket maksimal 3 detik.
Aturan valid terakhir disimpan per package. Saat offline, akses ditolak tetap
berlaku jika aturan yang tersimpan mewajibkan update; build baru yang sudah
memenuhi minimum otomatis diizinkan. Pengguna tanpa aturan tersimpan tetap
bisa membuka aplikasi jika server tidak terjangkau. Ini menjaga penggunaan
Guest/offline; bukan jaminan pemblokiran perangkat yang belum menerima aturan.

Dokumen tidak valid tidak menggantikan aturan valid terakhir. Pembatalan aturan
memerlukan koneksi agar diterima perangkat. Pemblokiran ini ada di UI, bukan
mekanisme otorisasi API/server. iOS, web, dan desktop tidak diberi gate Android.

## Validasi lokal

```powershell
flutter test test/app_update_service_test.dart test/app_update_gate_test.dart
firebase emulators:exec --only firestore --project demo-jajanku --config firebase.emulator.json "node test/firestore_rules_test.cjs"
```
