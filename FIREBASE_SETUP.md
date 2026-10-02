# Login email/password dan profil pengguna

Project: `jajanku-26976`.

1. Firebase Console → Authentication → Sign-in method → Email/Password → aktifkan Email/Password. Email link tidak diperlukan. Pertahankan Google jika masih digunakan.
2. Firestore Database → Create database jika belum ada → pilih mode Production dan lokasi yang sesuai. Jangan buat database kedua jika transaksi sudah memakai Firestore.
3. Firestore → Rules → salin seluruh isi `firestore.rules`, lalu Publish. Alternatif CLI: `firebase deploy --only firestore:rules --project jajanku-26976`.
4. Authentication → Settings → Password policy: sesuaikan kebijakan password. Aplikasi memvalidasi minimal 6 karakter; kebijakan Firebase yang lebih ketat tetap berlaku.
5. Authentication → Templates → Password reset: sesuaikan nama aplikasi dan template email.
6. Uji daftar, logout, login, dan lupa password dengan email sendiri pada perangkat.

## Database pengguna

Dokumen `users/{uid}` berisi `email`, `displayName`, `providers`, `plan`, `createdAt`, dan `lastLoginAt`. Password hanya ditangani Firebase Authentication dan tidak disimpan di Firestore. UID sama dengan UID di Authentication → Users. Transaksi dan budget tetap berada di subkoleksi pengguna tersebut.

Setiap akun baru mendapat `plan: free`. Login berikutnya tidak menimpa status VIP atau waktu pendaftaran. Akun Google juga dibuatkan profil. Akun yang sudah login dibuatkan profil saat aplikasi dibuka kembali. `createdAt` adalah waktu profil Firestore pertama kali dibuat, bukan selalu waktu akun Authentication pertama kali dibuat.

Untuk melihat pengguna, buka Firestore → Data → users. Filter `plan == free` atau `plan == vip`. Untuk mengubah status, edit field `plan` menjadi `vip` atau `free` dari Firebase Console sebagai admin. Rules melarang pengguna membaca daftar seluruh pengguna, menghapus profil, atau mengubah status sendiri. Fitur berbayar/pembayaran dan masa berlaku VIP belum diimplementasikan.

## Menghitung total, free, dan VIP

Script admin `tools/user-stats.cjs` melakukan tiga aggregate count tanpa mengunduh semua profil. Pada komputer admin:

```powershell
npm install --prefix tools --no-save --package-lock=false firebase-admin
gcloud auth application-default login
node tools/user-stats.cjs
```

Akun Google yang digunakan harus memiliki akses baca Firestore project. Jangan memasukkan service-account key atau kredensial admin ke aplikasi Flutter/repository. Script menghitung profil Firestore; akun lama yang belum membuka versi baru belum masuk hitungan. Authentication → Users tetap menjadi daftar akun autentikasi, termasuk akun yang profil Firestore-nya belum berhasil dibuat.

Login email/password dapat memakai paket Spark; Firestore memiliki kuota gratis dan biaya saat melewati kuota pada Blaze. Tidak memerlukan biaya SMS.

Referensi: https://firebase.google.com/docs/auth/flutter/password-auth dan https://firebase.google.com/docs/firestore/query-data/aggregation-queries.
