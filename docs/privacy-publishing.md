# Publikasi kebijakan privasi

Draf kebijakan berada di `assets/legal/privacy_policy.md` dan `public/privacy.html`.
Menu Personalisasi menampilkan versi lokal sehingga tetap bisa dibaca tanpa internet.

Sebelum deploy, lengkapi nama pengelola dan email bantuan di kedua dokumen,
hapus penanda DRAF, dan tinjau kesesuaian isi dengan operasional aplikasi.
Jangan mengunggah dokumen dengan placeholder kontak ke Play Console.

Firebase Hosting sudah dikonfigurasi untuk folder `public` dengan clean URLs.
Setelah isi final, deploy dengan:

```
firebase deploy --only hosting --project jajanku-26976
```

Alamat yang diharapkan setelah deploy adalah
`https://jajanku-26976.web.app/privacy`.
Alamat ini belum diverifikasi aktif; uji akses tanpa login sebelum dimasukkan ke Play Console.
Publikasi halaman ini tidak otomatis melengkapi form Data Safety maupun halaman
permintaan penghapusan akun. Keduanya tetap perlu disiapkan sesuai perilaku aplikasi.

Referensi penyusunan:
- https://firebase.google.com/support/privacy
- https://developers.google.com/ml-kit/android-data-disclosure
- https://developers.google.com/ml-kit/terms
- https://support.google.com/googleplay/android-developer/answer/18258653
