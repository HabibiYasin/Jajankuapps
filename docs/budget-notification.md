# Notifikasi budget harian Android

Notifikasi mengikuti `dailyLimit` di `lib/main.dart` (saat ini Rp50.000).
Layar pengaturan budget yang sudah ada masih berupa placeholder penyimpanan.
Sinkronisasi berjalan setelah membaca transaksi, termasuk setelah tambah,
hapus, ubah tanggal, dan saat aplikasi kembali aktif.

- Kurang dari 80%: hijau; mulai 80%: kuning; mulai 100%: merah.
- Label persentase tetap dapat melebihi 100%; hanya bar yang dibatasi penuh.
- Snapshot total per tanggal dan limit tersimpan di Android SharedPreferences.
- Notifikasi ongoing memakai ID yang sama agar pembaruan tidak menumpuk.
- Delete intent memulihkan notifikasi jika perangkat mengizinkannya diswipe.
- Receiver memulihkan notifikasi setelah boot dan pembaruan aplikasi.
- Alarm tidak presisi memperbarui hari berikutnya; mode hemat baterai dapat
  menunda pembaruan. Membuka aplikasi langsung menyinkronkan data lagi.
- Izin notifikasi diperlukan. Force stop atau mematikan izin/channel melalui
  pengaturan Android tidak dapat diatasi oleh mekanisme ini; buka kembali
  aplikasi setelah mengaktifkan izin. Perilaku vendor perlu diuji di perangkat.

## Pemeriksaan perangkat

1. Install build baru (perubahan native memerlukan restart, bukan hot reload),
   buka aplikasi, lalu izinkan notifikasi.
2. Dengan batas Rp50.000, periksa pengeluaran Rp25.000 (50%, hijau),
   Rp40.000 (80%, kuning), Rp50.000 (100%, merah), dan Rp62.500 (125%, merah).
3. Hapus transaksi atau pindahkan tanggalnya. Pastikan total dan bar berubah.
4. Ketuk notifikasi: aplikasi terbuka dan notifikasi tetap tersedia.
5. Tutup aplikasi dari recent apps. Periksa notifikasi tetap tersedia.
6. Pada Android yang mengizinkan swipe ongoing, hapus notifikasi dan periksa
   notifikasi muncul kembali tanpa membuka aplikasi.
7. Restart perangkat lalu unlock. Periksa notifikasi dipulihkan.
8. Uji pergantian hari dan perubahan zona waktu; periksa data hari yang benar.
9. Tolak izin notifikasi: transaksi tetap berfungsi. Aktifkan izin melalui
   pengaturan Android dan buka aplikasi; notifikasi seharusnya muncul.
