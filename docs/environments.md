# Lingkungan Android dev dan prod

Flavor memilih lingkungan; debug/release memilih mode build. Pemisahan ini
diterapkan untuk Android. Flavor iOS belum dikonfigurasi.

| | Dev | Prod |
|---|---|---|
| Nama aplikasi | Jajanku Dev | Jajanku |
| Application ID | `com.jajanku.app.dev` | `com.jajanku.app` |
| Firebase | `jajanku-dev-25ae6` | `jajanku-26976` |
| Google services | `android/app/src/dev/google-services.json` | `android/app/src/prod/google-services.json` |
| FirebaseOptions Dart | `lib/firebase_options_dev.dart` | `lib/firebase_options.dart` |
| Signing debug | Kunci debug | Kunci debug |
| Signing release | Kunci debug untuk pengujian lokal | Upload keystore dari `android/key.properties` |

Kedua aplikasi bisa dipasang bersamaan. SQLite dan preferensi lokal terpisah
karena Application ID berbeda. Mengganti mode debug/release tidak mengganti
Firebase. Project Firebase prod menggunakan konfigurasi yang sudah ada.

## Menjalankan aplikasi sekarang

```powershell
flutter run
flutter run --flavor dev --debug
flutter run --flavor dev --release
flutter run --flavor prod --debug
```

`flutter run` memilih dev melalui `default-flavor` di pubspec.yaml. VS Code
menyediakan pilihan Jajanku Dev (debug), Jajanku Dev (release), dan Jajanku Prod
(debug) di Run and Debug.

Firebase dev sudah dikonfigurasi untuk `jajanku-dev-25ae6`. Login dan sinkronisasi
menggunakan project tersebut. Jika Firebase dev belum tersedia, mode Guest tetap
dapat dipakai. Tidak ada fallback ke Firebase prod.
Konfigurasi Firebase dev yang memakai project prod ditolak saat build dan
sebelum inisialisasi Firebase di Dart.

## Menyiapkan ulang Firebase dev

1. Di Firebase Console, buat project baru, misalnya dengan nama Jajanku Dev.
   Catat **project ID sebenarnya**; nama tampilan tidak selalu sama dengan ID.
2. Login Firebase CLI menggunakan akunmu:

   ```powershell
   firebase login
   ```

3. Jalankan perintah berikut dari root repository setelah mengganti ID contoh:

   ```powershell
   flutterfire configure --project=jajanku-dev-25ae6 --platforms=android --android-package-name=com.jajanku.app.dev --out=lib/firebase_options_dev.dart --android-out=android/app/src/dev/google-services.json
   ```

   Perintah ini memperbarui konfigurasi Dart dan
   mendaftarkan/memilih aplikasi Android dev. Jika ditanya tentang penggunaan
   firebase.json yang sudah ada, gunakan project dev yang kamu pilih. Periksa
   perubahan firebase.json setelahnya: konfigurasi prod tetap menunjuk ke
   `jajanku-26976` dan file JSON di `src/prod`, bukan di root `android/app/`.

4. Aktifkan Email/Password dan Google pada Authentication project dev.
5. Buat database Cloud Firestore `(default)`, pilih lokasi yang sesuai, lalu
   deploy rules ke project dev dengan ID eksplisit:

   ```powershell
   firebase deploy --only firestore:rules --project jajanku-dev-25ae6
   ```

6. Ambil SHA-1/SHA-256 sertifikat debug melalui Android Studio atau signing
   report, lalu tambahkan ke aplikasi Android dev di Firebase Console:

   ```powershell
   Push-Location android
   ./gradlew.bat :app:signingReport
   Pop-Location
   ```

   Unduh ulang `google-services.json` setelah pengaturan Google Sign-In berubah,
   simpan ke `android/app/src/dev/google-services.json`, lalu build ulang.
7. Uji login dan transaksi dev. Pastikan datanya muncul di Firestore **dev**.
   Akun Firebase Authentication dev dan prod terpisah; buat akun uji dev baru.

Jangan menaruh `google-services.json` di `android/app/` atau `src/main/`.
Gunakan file khusus setiap flavor supaya tidak ada konfigurasi lintas lingkungan.

## Yang perlu kamu selesaikan: signing prod

Jika sudah memiliki upload keystore, gunakan keystore tersebut. Jika belum,
buat di komputer sendiri; `keytool` akan meminta password secara interaktif:

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE/upload-keystore.jks" -keyalg RSA -storetype JKS -keysize 2048 -validity 10000 -alias upload
Copy-Item android/key.properties.example android/key.properties
```

Isi `android/key.properties` dengan lokasi keystore, alias, dan password asli.
Untuk Windows, gunakan path dengan slash `/`. Path relatif dihitung dari
direktori `android/`. Keystore dan `key.properties` sudah diabaikan Git.
Simpan cadangan keystore dan password secara pribadi.

```powershell
flutter build appbundle --flavor prod --release
```

Output: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.
Build prod release berhenti dengan pesan konfigurasi jika keystore belum siap.
Dev release tetap bisa dibangun dengan kunci debug untuk tes lokal:

```powershell
flutter build apk --flavor dev --release
```

Di Play Console aktifkan Play App Signing. Tambahkan SHA-1/SHA-256 sertifikat
**app signing** dari Play Console ke aplikasi Android **prod** di Firebase.
Sertifikat app signing dapat berbeda dari upload key. Untuk tes Google Login
prod secara lokal, daftarkan juga sertifikat yang dipakai build lokal.
Unduh ulang JSON prod bila diperlukan dan uji melalui internal testing Play.

## Pemeriksaan sebelum rilis

- Pastikan rules prod sudah dipublish; keberadaan file lokal tidak berarti
  rules produksi sudah terpasang.
- Deploy selalu dengan `--project` eksplisit agar tujuan jelas.
- Uji perpindahan akun, offline/online, impor Guest, ekspor, dan hapus akun
  pada Firebase dev sebelum memvalidasi build prod.
- Dev yang sudah berisi data lokal Guest tetap perlu tindakan impor pengguna
  untuk memindahkannya ke akun dev. Data dev tidak otomatis pindah ke prod.

Referensi:
- https://docs.flutter.dev/deployment/flavors
- https://firebase.google.com/docs/projects/dev-workflows/general-best-practices
- https://firebase.google.com/docs/android/google-services-plugin-and-file
- https://docs.flutter.dev/deployment/android
