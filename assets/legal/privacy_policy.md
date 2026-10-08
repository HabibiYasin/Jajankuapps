# Kebijakan Privasi Jajanku

**Terakhir diperbarui: 7 Oktober 2026**

Kebijakan Privasi ini menjelaskan bagaimana **Jajanku**, yang dikembangkan dan dikelola oleh **Spizartel**, mengumpulkan, menggunakan, menyimpan, dan melindungi informasi pengguna saat menggunakan aplikasi Jajanku.

Kebijakan Privasi resmi Jajanku tersedia di:

**https://spizartel.biz.id/jajanku/privacy**

Dengan menggunakan Jajanku, kamu memahami bahwa data akan diproses sebagaimana dijelaskan dalam Kebijakan Privasi ini.

## Tentang Jajanku

Jajanku adalah aplikasi pencatatan pengeluaran dan pengelolaan budget yang membantu pengguna mencatat transaksi, mengelompokkan pengeluaran, memantau budget, serta melihat ringkasan keuangan pribadi.

Jajanku tidak terhubung secara langsung ke rekening bank dan tidak mengambil saldo maupun riwayat transaksi secara otomatis dari rekening pengguna.

## Data Akun

Saat kamu membuat akun atau login ke Jajanku, layanan autentikasi dapat memproses informasi seperti:

- Alamat email
- Nama tampilan
- Identitas akun
- Metode login
- Informasi autentikasi
- Waktu pembuatan akun
- Waktu login terakhir
- Informasi paket atau jenis akun

Jajanku menggunakan **Firebase Authentication**, termasuk Google Sign-In apabila pengguna memilih login menggunakan akun Google.

Password atau kredensial autentikasi dikelola oleh Firebase Authentication dan tidak disimpan sebagai teks biasa di database transaksi Jajanku.

Jika kamu menggunakan Jajanku tanpa login sebagai Guest, sebagian data dapat disimpan secara lokal di perangkat.

## Catatan Pengeluaran dan Budget

Informasi yang kamu masukkan ke dalam Jajanku dapat mencakup:

- Nama merchant atau tempat transaksi
- Nominal transaksi
- Tanggal dan waktu transaksi
- Kategori transaksi
- Sumber transaksi
- Catatan transaksi
- Informasi lain yang kamu tambahkan ke transaksi

Jajanku juga dapat menyimpan pengaturan budget seperti:

- Budget harian
- Budget mingguan
- Budget bulanan
- Budget berdasarkan kategori

Informasi tersebut digunakan untuk menyediakan fitur seperti ringkasan pengeluaran, perbandingan pengeluaran, laporan, analisis budget, dan notifikasi budget.

Jajanku **tidak meminta akses ke saldo rekening bank dan tidak mengambil transaksi langsung dari rekening bank, kartu debit, kartu kredit, atau dompet digital pengguna**.

Transaksi hanya dicatat berdasarkan informasi yang diberikan, dipilih, atau dikonfirmasi oleh pengguna.

## Gambar dan Pengenalan Teks

Jajanku dapat mengakses gambar yang kamu pilih atau bagikan ke aplikasi, misalnya screenshot atau bukti transaksi, untuk membantu membaca informasi transaksi.

Pengenalan teks dilakukan menggunakan **Google ML Kit**.

Pemrosesan utama gambar untuk pengenalan teks dilakukan di perangkat.

Jajanku tidak menyimpan atau mengunggah gambar bukti transaksi tersebut ke database cloud Jajanku sebagai bagian dari proses pencatatan transaksi, kecuali apabila suatu fitur di masa mendatang secara jelas meminta persetujuan pengguna untuk melakukan hal tersebut.

Hasil pembacaan teks, seperti nama merchant, nominal, atau tanggal transaksi, dapat digunakan untuk membuat catatan transaksi dan dapat disimpan ke akun pengguna apabila pengguna memilih untuk menyimpannya.

Google ML Kit atau SDK Google terkait dapat mengumpulkan informasi teknis tertentu, seperti informasi perangkat, versi aplikasi, pengenal instalasi, konfigurasi API, metrik performa, serta informasi kesalahan untuk keperluan diagnostik, keamanan, dan pengoperasian layanan.

## Penyimpanan Lokal dan Cloud

Jajanku menggunakan kombinasi penyimpanan lokal dan penyimpanan cloud.

Untuk pengguna Guest, data transaksi dan preferensi tertentu dapat disimpan secara lokal di perangkat.

Untuk pengguna yang menggunakan akun, beberapa informasi dapat disimpan melalui layanan Google Firebase, termasuk:

- Profil pengguna
- Catatan transaksi
- Pengaturan budget
- Preferensi tertentu
- Riwayat terkait proses impor transaksi

Cache data akun juga dapat tersimpan di perangkat agar aplikasi tetap dapat menampilkan informasi ketika koneksi internet terbatas.

Data Guest di perangkat dan data akun di cloud disimpan terpisah. Login tidak memindahkan transaksi Guest ke akun.

## Layanan Pihak Ketiga

Untuk menjalankan beberapa fungsi aplikasi, Jajanku menggunakan layanan pihak ketiga yang disediakan oleh Google, termasuk:

- Firebase Authentication
- Cloud Firestore
- Google Sign-In
- Google ML Kit

Layanan tersebut dapat memproses informasi yang diperlukan untuk autentikasi, penyimpanan data, keamanan, diagnostik, serta pengoperasian fitur aplikasi.

Data dapat diproses menggunakan infrastruktur penyedia layanan yang berada di negara atau wilayah yang berbeda dari lokasi pengguna.

Informasi lebih lanjut mengenai kebijakan privasi layanan Google dapat dilihat melalui:

https://firebase.google.com/support/privacy

https://policies.google.com/privacy

## Izin Aplikasi

Jajanku hanya meminta izin perangkat yang diperlukan untuk menyediakan fitur tertentu.

Izin tersebut dapat mencakup:

### Notifikasi

Digunakan untuk menampilkan informasi seperti progres budget dan pengingat yang telah diaktifkan pengguna.

Pengingat dapat dinonaktifkan melalui menu Personalisasi di Jajanku atau melalui pengaturan notifikasi Android.

Jika notifikasi menampilkan informasi transaksi atau budget, sebagian informasi seperti nominal dapat terlihat pada panel notifikasi atau layar kunci sesuai pengaturan perangkat pengguna.

### Gambar atau Media

Digunakan ketika pengguna memilih screenshot atau gambar bukti transaksi untuk diproses oleh Jajanku.

### Penyimpanan

Pada perangkat atau versi Android tertentu, akses penyimpanan dapat digunakan untuk menyimpan hasil ekspor yang dibuat oleh pengguna.

Jajanku tidak menggunakan izin tersebut untuk mengakses file yang tidak diperlukan untuk fungsi yang dipilih pengguna.

## Ekspor dan Berbagi

Jajanku menyediakan fitur yang memungkinkan pengguna membuat, menyimpan, atau membagikan laporan pengeluaran.

Jika kamu memilih fitur ekspor atau bagikan, laporan dibuat berdasarkan data transaksi yang tersimpan di Jajanku.

Setelah laporan dibagikan ke aplikasi atau pihak lain, penerima laporan dapat melihat informasi yang terdapat di dalam laporan tersebut.

Jajanku dapat menyediakan pilihan untuk menyamarkan nominal pada laporan atau gambar yang dibagikan.

Pengguna disarankan untuk memeriksa kembali isi laporan sebelum membagikannya.

Jajanku tidak bertanggung jawab atas penggunaan data setelah pengguna secara sadar membagikannya kepada pihak lain.

## Keamanan Data

Jajanku menggunakan langkah-langkah yang wajar untuk membantu melindungi informasi pengguna.

Akses data cloud dibatasi menggunakan autentikasi pengguna dan aturan akses berdasarkan kepemilikan akun.

Komunikasi antara aplikasi dan layanan Firebase menggunakan koneksi terenkripsi yang disediakan oleh layanan tersebut.

Namun, tidak ada metode penyimpanan atau transmisi data elektronik yang dapat menjamin keamanan secara mutlak.

Keamanan akun juga bergantung pada pengguna. Jangan membagikan password, kode autentikasi, atau tautan verifikasi kepada orang lain.

## Penyimpanan dan Penghapusan Data

Data akun disimpan selama diperlukan untuk menyediakan layanan Jajanku atau sampai pengguna menghapus data atau akun tersebut.

Pengguna dapat menghapus transaksi tertentu langsung melalui aplikasi.

Untuk menghapus akun Jajanku:

**Personalisasi → pilih nama akun → Pengaturan Akun → Hapus Akun**

Pengguna mungkin diminta melakukan autentikasi ulang sebelum proses penghapusan dapat dilakukan.

Proses penghapusan akun dirancang untuk menghapus data yang terkait dengan akun, termasuk:

- Profil pengguna
- Catatan transaksi
- Pengaturan budget
- Riwayat impor yang terkait dengan akun
- Akun autentikasi Jajanku

Apabila proses penghapusan terganggu, misalnya karena koneksi internet terputus, sebagian proses mungkin perlu dijalankan kembali.

Penghapusan akun cloud tidak secara otomatis menghapus:

- Data Guest yang tersimpan lokal pada perangkat
- File hasil ekspor yang telah disimpan
- Screenshot yang tersimpan di perangkat
- Laporan atau data yang sebelumnya telah dibagikan ke aplikasi atau pihak lain

Data lokal Jajanku dapat dihapus melalui fitur aplikasi yang tersedia, pengaturan penyimpanan aplikasi Android, atau dengan menghapus aplikasi dari perangkat.

Log teknis, diagnostik, atau cadangan yang dikelola oleh penyedia layanan pihak ketiga dapat memiliki periode penyimpanan tersendiri sesuai kebijakan penyedia layanan tersebut.

## Pilihan dan Kontrol Pengguna

Jajanku memberikan pengguna kontrol terhadap sejumlah informasi dan fitur aplikasi.

Pengguna dapat, sesuai fitur yang tersedia:

- Mengubah nama atau profil
- Mengatur budget
- Menambah, mengubah, atau menghapus transaksi
- Mengatur notifikasi
- Menggunakan atau menonaktifkan pengingat
- Mengekspor catatan
- Membagikan laporan
- Menghapus akun

Untuk pertanyaan mengenai privasi atau permintaan penghapusan data yang tidak dapat dilakukan melalui aplikasi, pengguna dapat menghubungi Spizartel melalui alamat email yang tercantum pada bagian Kontak.

Untuk melindungi data pengguna, kami dapat meminta verifikasi identitas atau kepemilikan akun sebelum memproses permintaan terkait data akun.

## Privasi Anak

Jajanku tidak secara khusus ditujukan untuk mengumpulkan data pribadi anak-anak.

Jika kami mengetahui bahwa data pribadi anak telah dikumpulkan secara tidak semestinya melalui layanan Jajanku, kami akan mengambil langkah yang wajar untuk menanganinya sesuai ketentuan yang berlaku.

## Perubahan Kebijakan Privasi

Kebijakan Privasi ini dapat diperbarui dari waktu ke waktu, misalnya jika terdapat perubahan pada fitur Jajanku, teknologi yang digunakan, layanan pihak ketiga, atau cara data diproses.

Tanggal **Terakhir diperbarui** pada bagian atas halaman akan diperbarui ketika terdapat perubahan pada Kebijakan Privasi ini.

Versi terbaru Kebijakan Privasi selalu dapat dilihat melalui:

**https://spizartel.biz.id/jajanku/privacy**

Pengguna disarankan untuk meninjau halaman ini secara berkala.

## Kontak

Jajanku dikembangkan dan dikelola oleh:

**Developer / Pengelola:** Spizartel  
**Email bantuan dan privasi:** contact@spizartel.biz.id  
**Kebijakan Privasi:** https://spizartel.biz.id/jajanku/privacy

Untuk pertanyaan mengenai Kebijakan Privasi, penggunaan data, atau permintaan terkait data pribadi, silakan hubungi kami melalui email tersebut.
