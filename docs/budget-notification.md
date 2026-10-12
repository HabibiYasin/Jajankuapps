# Notifikasi budget harian Android

Notifikasi mengikuti batas harian dan kategori budget yang disimpan pengguna.
Pemasukan dan pengeluaran di luar kategori budget tidak ikut dihitung.
Sinkronisasi berjalan setelah membaca transaksi, termasuk setelah tambah,
hapus, ubah tanggal, dan saat aplikasi kembali aktif.

- Kurang dari 80%: hijau; mulai 80%: kuning; mulai 100%: merah.
- Label persentase tetap dapat melebihi 100%; hanya bar yang dibatasi penuh.
- Snapshot total per tanggal dan limit tersimpan di Android SharedPreferences.
- Notifikasi ongoing memakai ID yang sama agar pembaruan tidak menumpuk.
- Peringatan terpisah muncul saat pemakaian **lebih dari 50%, 75%, dan 100%**.
  Tepat di batas tidak memicu tingkat tersebut. Setiap tingkat maksimal sekali
  per tanggal lokal; jika transaksi melewati beberapa tingkat sekaligus, hanya
  tingkat tertinggi yang ditampilkan dan tingkat sebelumnya dianggap terlewati.
  Status tersimpan agar refresh, restart, hapus transaksi, atau perubahan limit
  tidak mengulang peringatan pada tingkat yang sudah diberitahukan hari itu.
- Pengingat pukul **13.00 waktu perangkat** hanya muncul jika pengeluaran budget
  masih tepat **0%**, maksimal sekali sehari. Jadwal lama pukul 12.00 dipindahkan
  ke pukul 13.00 saat sinkronisasi atau pembaruan aplikasi.
- Progres persistent, peringatan batas budget, dan pengingat jam 1 siang memiliki
  sakelar masing-masing di pengaturan Notifikasi, aktif secara default.
  Mematikan progres persistent tidak mematikan kedua pengingat lainnya.
- Delete intent memulihkan notifikasi jika perangkat mengizinkannya diswipe.
- Receiver memulihkan notifikasi setelah boot dan pembaruan aplikasi.
- Alarm tidak presisi memperbarui hari berikutnya; mode hemat baterai dapat
  menunda pembaruan maupun pengingat pukul 13.00. Saat alarm terlambat,
  pengingat memeriksa total terbaru yang tersimpan sebelum ditampilkan.
  Membuka aplikasi langsung menyinkronkan data lagi.
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
10. Dengan batas Rp50.000, naikkan pengeluaran bertahap ke Rp25.000,
    Rp25.001, Rp37.500, Rp37.501, Rp50.000, lalu Rp50.001. Peringatan baru
    hanya muncul di Rp25.001 (50%), Rp37.501 (75%), dan Rp50.001 (100%).
    Buka ulang aplikasi dan ubah/hapus transaksi: tingkat yang sama tidak berulang.
11. Pada hari baru, langsung catat Rp60.000: hanya peringatan 100% yang muncul.
12. Biarkan budget 0% sampai pukul 13.00: pengingat muncul. Ulangi pada hari
    berbeda dengan pengeluaran budget positif: pengingat siang tidak muncul.
13. Matikan progres persistent; peringatan ambang dan pengingat siang tetap
    berfungsi. Matikan sakelar masing-masing untuk menonaktifkannya.
