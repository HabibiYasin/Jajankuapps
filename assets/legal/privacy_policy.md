# Kebijakan Privasi Jajanku

DRAF ? identitas pengelola dan kontak belum dilengkapi.

Terakhir diperbarui: 6 Oktober 2026

## Tentang kebijakan ini

Kebijakan ini menjelaskan bagaimana Jajanku memproses data untuk membantu pengguna mencatat pengeluaran dan mengatur budget.

## Data akun

Saat kamu mendaftar atau login, Firebase Authentication memproses email, identitas akun, metode login, dan informasi autentikasi. Jajanku menyimpan email, nama tampilan, metode login, paket akun, waktu pembuatan akun, dan waktu login terakhir. Password dikelola oleh Firebase Authentication dan tidak disimpan sebagai teks di database transaksi Jajanku.

## Catatan pengeluaran dan budget

Data yang kamu masukkan mencakup nama merchant, nominal, tanggal dan waktu transaksi, kategori, serta sumber transaksi. Pengaturan budget meliputi limit harian, mingguan, bulanan, dan kategori pilihan. Data ini dipakai untuk ringkasan, perbandingan, laporan, dan notifikasi budget. Jajanku tidak mengakses saldo rekening atau mengambil transaksi langsung dari bank.

## Gambar dan pengenalan teks

Jajanku mengakses gambar yang kamu pilih atau bagikan ke aplikasi untuk membaca bukti transaksi. Pengenalan teks menggunakan Google ML Kit di perangkat. Fitur ini tidak mengunggah gambar bukti transaksi ke database Jajanku; catatan transaksi hasil pembacaan dapat disimpan ke cloud setelah login. SDK ML Kit dapat mengirim informasi perangkat, versi aplikasi, pengenal instalasi, metrik performa, konfigurasi API, dan kode kesalahan ke Google untuk diagnostik serta analisis penggunaan SDK.

## Penyimpanan lokal dan cloud

Data Guest dan preferensi aplikasi disimpan di perangkat. Saat menggunakan akun, catatan transaksi, profil, dan pengaturan budget disimpan melalui Firebase Authentication dan Cloud Firestore untuk akses akun dan sinkronisasi. Cache data akun dapat tersimpan di perangkat agar aplikasi tetap bisa menampilkan data saat koneksi terbatas. Pemindahan transaksi Guest ke akun dilakukan melalui pilihan pengguna.

## Layanan pihak ketiga

Jajanku memakai layanan Google, termasuk Firebase Authentication, Cloud Firestore, Google Sign-In, dan Google ML Kit. Layanan tersebut memproses data yang diperlukan untuk autentikasi, penyimpanan, keamanan, atau pengoperasian SDK. Infrastruktur penyedia layanan dapat memproses data di negara yang berbeda dari tempat kamu berada. Kebijakan penyedia layanan: https://firebase.google.com/support/privacy dan https://policies.google.com/privacy.

## Izin dan notifikasi

Izin notifikasi digunakan untuk progres budget dan pengingat pukul 12 siang yang dapat dimatikan melalui Personalisasi atau pengaturan Android. Informasi nominal dapat terlihat di panel notifikasi atau layar kunci sesuai pengaturan perangkat. Akses gambar digunakan saat kamu memilih bukti transaksi, sedangkan akses penyimpanan yang tersedia pada perangkat tertentu digunakan untuk menyimpan hasil ekspor.

## Ekspor dan berbagi

Jika kamu memilih ekspor atau bagikan, laporan dibuat dari catatan pengeluaran lalu disimpan atau dikirim ke aplikasi yang kamu pilih. Penerima laporan dapat melihat informasi yang tercantum di dalamnya. Pilihan Tutup nominal menyamarkan nominal pada gambar report; periksa kembali isi laporan sebelum membagikannya.

## Keamanan

Akses data cloud dibatasi dengan autentikasi dan aturan akses berdasarkan pemilik akun. Komunikasi dengan layanan Firebase menggunakan koneksi terenkripsi. Keamanan juga bergantung pada perangkat dan akun yang kamu gunakan; jangan membagikan password atau tautan verifikasi kepada orang lain.

## Penyimpanan dan penghapusan

Data akun disimpan untuk menyediakan layanan sampai kamu menghapus catatan atau akun. Untuk menghapus akun, buka Personalisasi, klik nama, pilih Pengaturan akun lalu Hapus akun. Setelah verifikasi ulang, proses menghapus profil, transaksi, budget, riwayat import, dan akun autentikasi. Jika proses terputus, sebagian data dapat sudah terhapus dan kamu dapat mengulangi proses. Penghapusan akun tidak menghapus data Guest, file ekspor, atau salinan yang telah kamu bagikan. Data lokal dapat dihapus melalui pengaturan data aplikasi atau penghapusan aplikasi. Log operasional atau cadangan yang dikelola penyedia layanan mengikuti kebijakan retensi penyedia tersebut.

## Pilihan pengguna

Kamu dapat mengubah nama dan budget, menghapus transaksi, mengatur notifikasi, mengekspor catatan, atau menghapus akun. Untuk pertanyaan privasi atau permintaan penghapusan dari luar aplikasi, hubungi kontak pengelola pada bagian berikut. Identitas pemohon perlu diverifikasi sebelum data akun dihapus.

## Perubahan kebijakan

Kebijakan ini dapat diperbarui jika fitur atau cara pemrosesan data berubah. Versi terbaru dan tanggal pembaruan akan ditampilkan pada halaman ini.

## Kontak pengelola

Nama pengelola: [MENUNGGU NAMA DEVELOPER]
Email bantuan dan privasi: [MENUNGGU EMAIL BANTUAN]
