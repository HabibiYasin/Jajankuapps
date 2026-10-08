import 'package:flutter/material.dart';

import '../widgets/tutorial_dialog.dart';

typedef _GuideSection = ({String title, String body});
typedef _GuideTopic = ({String title, List<_GuideSection> sections});

const List<_GuideTopic> _topics = [
  (
    title: 'Cara Atur Budget',
    sections: [
      (
        title: 'Pilih pengeluaran yang masuk budget',
        body:
            '1. Buka Personalisasi > Limit Budget.\n'
            '2. Centang kategori yang ingin kamu batasi. Minimal satu kategori harus dipilih.\n'
            '3. Pilih Jajan aja untuk memilih Jajan, Makanan, Minuman, dan Belanja, '
            'atau Semuanya untuk memilih seluruh kategori pengeluaran. '
            'Kamu juga bisa mengatur centangnya satu per satu.',
      ),
      (
        title: 'Isi batas pengeluaran',
        body:
            'Isi Budget Harian, Budget Mingguan, dan Budget Bulanan dengan angka '
            'lebih dari 0, lalu tekan Simpan Pengaturan. Ketiganya diisi sendiri; '
            'budget bulanan tidak otomatis dihitung dari budget harian.\n\n'
            'Budget adalah batas pengeluaran yang kamu tentukan, bukan saldo rekening '
            'atau dompet digital. Hanya pengeluaran dalam kategori pilihanmu yang '
            'dihitung sebagai pemakaian budget.',
      ),
      (
        title: 'Contoh dan perubahan pengaturan',
        body:
            'Kalau budget harian Rp50.000 dan kamu mencatat Makanan Rp20.000 '
            'dengan kategori Makanan dicentang, budget terpakai Rp20.000 '
            'dan sisanya Rp30.000.\n\n'
            'Kamu bisa mengubah limit dan kategori lewat menu yang sama. '
            'Ringkasan dihitung ulang memakai pengaturan terbaru, termasuk '
            'untuk transaksi yang sudah tercatat. Mengubah budget tidak menghapus transaksi.',
      ),
    ],
  ),
  (
    title: 'Cara Catat Pemasukan',
    sections: [
      (
        title: 'Langkah mencatat',
        body:
            '1. Buka tab Pemasukan, lalu tekan Catat Pemasukan.\n'
            '2. Isi asal pemasukan, misalnya Gaji dari perusahaan, serta nominalnya.\n'
            '3. Pilih kategori Gaji, Uang Saku, Bonus, Usaha, atau Lainnya.\n'
            '4. Pilih Metode Pembayaran, isi Uang masuk ke '
            '(misalnya BCA atau Tunai), dan periksa tanggalnya.\n'
            '5. Tekan Simpan Pemasukan. Catatan bisa dilihat di tab Pemasukan.\n\n'
            'Jika diminta, login dan selesaikan pengaturan budget terlebih dahulu.',
      ),
      (
        title: 'Pemasukan tidak mengubah budget',
        body:
            'Pemasukan tidak mengurangi budget, tidak menambah limit budget, '
            'dan tidak menghapus pengeluaran yang sudah tercatat. '
            'Pemasukan juga tidak masuk ke Budget lainnya.\n\n'
            'Contoh: budget harian Rp50.000 dan pengeluaran yang masuk budget '
            'Rp20.000. Setelah mencatat pemasukan Rp100.000, limit tetap Rp50.000 '
            'dan sisa budget tetap Rp30.000. Kalau ingin menaikkan limit, '
            'ubah sendiri di Personalisasi > Limit Budget.',
      ),
      (
        title: 'Pemasukan dipakai untuk apa?',
        body:
            'Pemasukan membantu melihat arus uang bulanan. Selisih tercatat '
            'adalah total pemasukan dikurangi seluruh pengeluaran pada bulan itu, '
            'termasuk pengeluaran di luar kategori budget.\n\n'
            'Selisih ini bergantung pada transaksi yang kamu catat. '
            'Angkanya bukan saldo rekening atau uang tunai yang dibaca otomatis.',
      ),
    ],
  ),
  (
    title: 'Cara Share dan Lokasinya',
    sections: [
      (
        title: 'Bagikan progres harian',
        body:
            'Di Dashboard, ketuk kartu Hari Ini atau Kemarin untuk membuka '
            'gambar progres. Tekan Bagikan, lalu pilih aplikasi tujuan yang '
            'tersedia di HP kamu, misalnya WhatsApp atau Instagram. '
            'Ketersediaan tujuan berbagi mengikuti aplikasi yang terpasang.',
      ),
      (
        title: 'Bagikan progres bulanan',
        body:
            'Di Dashboard, ketuk kartu Arus uang di bagian atas. '
            'Pilih kartu bulan ini atau bulan kemarin untuk membuka progres '
            'bulan tersebut, lalu tekan Bagikan.\n\n'
            'Gambar progres memakai pengeluaran dalam kategori budget. '
            'Angkanya bisa berbeda dari total seluruh pengeluaran pada arus uang.',
      ),
      (
        title: 'Atur gambar sebelum dibagikan',
        body:
            'Gunakan Ganti pesan untuk mengganti kalimat pada gambar. '
            'Centang Tutup nominal untuk menyamarkan nominal; persentase progres '
            'masih bisa terlihat, jadi periksa pratinjaunya dulu. '
            'Tekan Unduh jika ingin menyimpan gambar ke galeri. '
            'Jika diminta, izinkan akses penyimpanan foto.\n\n'
            'Akun premium juga dapat mengatur karakter dan warna kartu '
            'melalui pilihan yang muncul di halaman progres.',
      ),
      (
        title: 'Lokasi berbagi lainnya',
        body:
            'Di tab Riwayat, Download Laporan Bulanan PDF akan membuka menu '
            'berbagi setelah PDF dibuat. Ekspor/Impor Data Excel/Sheet juga '
            'membuka menu berbagi saat kamu mengekspor file. Dari menu itu, '
            'pilih aplikasi untuk mengirim atau menyimpan file.\n\n'
            'Untuk mencatat dari bukti pembayaran, arah berbagi dibalik: '
            'buka gambar bukti di galeri atau aplikasi pembayaran, tekan '
            'Bagikan/Share, lalu pilih Jajanku jika tersedia. Gunakan gambar '
            'bukti, bukan tautan. Jika Jajanku tidak muncul, simpan gambarnya '
            'lalu gunakan tombol + > Unggah dari Galeri di Dashboard Jajanku.',
      ),
    ],
  ),
  (
    title: 'Cara Download Laporan Bulanan',
    sections: [
      (
        title: 'Buat dan simpan PDF',
        body:
            '1. Buka tab Riwayat.\n'
            '2. Tekan Download Laporan Bulanan PDF.\n'
            '3. Periksa Nama pada laporan dan pilih Bulan laporan.\n'
            '4. Tekan Buat PDF dan tunggu menu berbagi muncul.\n'
            '5. Pilih tujuan penyimpanan file yang tersedia di HP kamu, '
            'atau kirim PDF melalui aplikasi pilihanmu.\n\n'
            'File tidak otomatis masuk ke folder Download. Lokasi akhirnya '
            'mengikuti tujuan yang kamu pilih di menu berbagi.',
      ),
      (
        title: 'Isi dan pilihan bulan',
        body:
            'PDF memuat ringkasan budget, grafik, perbandingan pengeluaran, '
            'rekap harian, dan rincian transaksi. Laporan mengikuti bulan '
            'yang dipilih pada dialog, bukan filter pencarian di Riwayat. '
            'Laporan bulan berjalan hanya memuat catatan yang sudah ada saat dibuat.\n\n'
            'Akun non-premium dapat memilih bulan ini dan bulan sebelumnya. '
            'Akun premium dapat memilih 12 bulan terakhir, termasuk bulan ini.',
      ),
    ],
  ),
  (
    title: 'Cara Impor dan Ekspor Excel',
    sections: [
      (
        title: 'Ekspor data atau template',
        body:
            'Buka Riwayat > Ekspor/Impor Data Excel/Sheet, lalu pilih '
            'Ekspor seluruh transaksi. Jika belum ada transaksi, pilih '
            'Ekspor template kosong. Simpan file .xlsx melalui menu berbagi.\n\n'
            'Ekspor berisi seluruh pemasukan dan pengeluaran yang dimuat aplikasi, '
            'bukan hanya hasil filter di Riwayat. Simpan salinan asli sebagai '
            'cadangan sebelum mengedit file.',
      ),
      (
        title: 'Edit sheet Transaksi',
        body:
            'Buka hasil ekspor di Excel atau Google Sheets. Edit sheet bernama '
            'Transaksi tanpa mengubah nama kolom. Semua 8 kolom wajib diisi: '
            'No, Merchant, Kategori, Nominal (Rp), Tanggal & Waktu, '
            'Sumber Uang, Metode Pembayaran, dan Jenis Transaksi. '
            'Untuk pemasukan, isi Merchant dengan asal pemasukan.\n\n'
            'No harus bilangan bulat positif dan tidak boleh berulang. '
            'Isi nominal lebih dari 0 tanpa Rp atau pemisah ribuan, '
            'misalnya 25000. Untuk nominal desimal, gunakan sel angka. '
            'Tanggal ditulis dd/mm/yyyy atau dd/mm/yyyy HH:mm (24 jam); '
            'tanggal tanpa jam menjadi 00:00.\n\n'
            'Pilih kategori, metode pembayaran, dan jenis transaksi dari pilihan '
            'yang tersedia. Sesuaikan kategori dengan jenis Pemasukan atau '
            'Pengeluaran. Gunakan nilai langsung, bukan rumus. '
            'Petunjuk lengkap juga tersedia di sheet Petunjuk.',
      ),
      (
        title: 'Impor file yang sudah diedit',
        body:
            '1. Simpan file sebagai .xlsx. Di Google Sheets, pilih '
            'File > Download > Microsoft Excel (.xlsx).\n'
            '2. Buka Riwayat > Ekspor/Impor Data Excel/Sheet > '
            'Impor Excel/Sheet (.xlsx).\n'
            '3. Pilih file dan periksa jumlah pemasukan serta pengeluaran '
            'yang terbaca. Jika ada kesalahan, perbaiki sesuai pesan aplikasi.\n'
            '4. Setelah yakin dan sudah punya cadangan, tekan '
            'Ganti seluruh transaksi.',
      ),
      (
        title: 'Impor mengganti seluruh transaksi',
        body:
            'Impor bukan menambahkan isi file ke catatan lama. Seluruh '
            'pemasukan dan pengeluaran diganti dengan isi sheet Transaksi. '
            'Catatan yang tidak ada di file akan dihapus, termasuk yang '
            'sedang tidak terlihat karena filter riwayat.\n\n'
            'Kalau hanya ingin menambah beberapa transaksi, ekspor seluruh '
            'data dulu, pertahankan baris lama, lalu tambahkan baris baru. '
            'Sheet ringkasan tidak ikut diimpor. Ekspor ulang setelah impor '
            'untuk mendapatkan ringkasan terbaru. Limit budget tidak diatur '
            'melalui file transaksi ini.',
      ),
    ],
  ),
  (
    title: 'Tentang Budget Lainnya',
    sections: [
      (
        title: 'Apa yang dihitung?',
        body:
            'Budget lainnya adalah jumlah pengeluaran di luar kategori '
            'yang kamu pilih di Limit Budget. Angka ini tetap dicatat, '
            'tetapi tidak mengurangi limit budget utama. Ini bukan jatah '
            'uang tambahan atau limit terpisah yang bisa kamu atur.\n\n'
            'Lihat kartu Budget lainnya di bagian bawah Dashboard untuk '
            'jumlah hari ini dan bulan ini. Pemasukan tidak termasuk di dalamnya.',
      ),
      (
        title: 'Contoh sederhana',
        body:
            'Misalnya kamu hanya memilih Makanan dan Minuman untuk budget. '
            'Makan siang Rp25.000 akan mengurangi sisa budget, sedangkan '
            'Transportasi Rp15.000 masuk ke Budget lainnya. Total pengeluaran '
            'tetap Rp40.000, tetapi yang terpakai dari budget hanya Rp25.000.\n\n'
            'Kalau ingin Transportasi ikut mengurangi budget, centang kategori '
            'itu di Personalisasi > Limit Budget, lalu simpan. '
            'Ringkasan transaksi lama juga dihitung ulang sesuai pilihan baru.',
      ),
    ],
  ),
  (
    title: 'FAQ',
    sections: [
      (
        title: 'Kenapa sudah mencatat pemasukan, sisa budget tidak bertambah?',
        body:
            'Pemasukan hanya menambah catatan uang masuk. Limit budget '
            'ditentukan sendiri di Personalisasi > Limit Budget. '
            'Pemasukan tidak mengurangi pemakaian budget yang sudah tercatat.',
      ),
      (
        title: 'Kenapa pengeluaran tidak mengurangi budget?',
        body:
            'Periksa kategori dan tanggal transaksi. Hanya kategori yang '
            'dicentang di Limit Budget yang dihitung dalam budget. Kategori '
            'lain masuk Budget lainnya. Transaksi tanggal kemarin juga tidak '
            'masuk ke angka Hari Ini.',
      ),
      (
        title: 'Kenapa total pengeluaran berbeda dari progres budget?',
        body:
            'Total pengeluaran mencakup semua kategori, sedangkan progres '
            'budget hanya menghitung kategori pilihanmu. Selisih tercatat '
            'di arus uang adalah pemasukan dikurangi seluruh pengeluaran, '
            'bukan sisa budget.',
      ),
      (
        title: 'Apakah budget diambil dari saldo bank atau dompet digital?',
        body:
            'Tidak. Budget diisi sendiri dan perhitungannya memakai transaksi '
            'yang kamu catat. Jajanku tidak membaca saldo rekeningmu secara otomatis.',
      ),
      (
        title: 'Kenapa hasil baca struk salah atau kategorinya Umum?',
        body:
            'Gambar buram, terpotong, atau tata letak bukti yang berbeda bisa '
            'membuat pembacaan keliru. Setelah memproses gambar, periksa catatan '
            'di Riwayat. Ketuk transaksi > Edit Detail untuk memperbaiki '
            'nama, sumber uang, metode pembayaran, atau kategori; '
            'gunakan Ubah Tanggal untuk tanggal dan jam. Jika nominal yang '
            'tersimpan salah, hapus catatan itu lewat Hapus Riwayat Ini, '
            'lalu catat ulang dengan nominal yang benar. Jika nominal tidak '
            'terbaca, gunakan gambar yang lebih jelas atau Catat Manual.',
      ),
      (
        title: 'Di mana cara mencatat tanpa foto struk?',
        body:
            'Tekan tombol + di Dashboard, pilih Catat Manual, '
            'isi rincian pengeluaran, lalu tekan Simpan Pengeluaran. '
            'Untuk uang masuk, gunakan Catat Pemasukan. Login jika diminta.',
      ),
      (
        title: 'Apakah mengubah kategori budget menghapus catatan lama?',
        body:
            'Tidak. Catatannya tetap ada. Yang berubah adalah pengelompokan '
            'antara pemakaian budget dan Budget lainnya. Ringkasan memakai '
            'pilihan kategori serta limit terbaru.',
      ),
      (
        title: 'Kenapa transaksi lama tidak terlihat?',
        body:
            'Periksa tab yang dibuka: uang masuk ada di Pemasukan, uang keluar '
            'ada di Riwayat. Periksa juga pencarian dan filter. Riwayat '
            'non-premium menampilkan bulan ini dan bulan sebelumnya; premium '
            'menampilkan 12 bulan terakhir. Batas tampilan bulan tidak '
            'menghapus transaksi yang tersimpan.',
      ),
      (
        title: 'Sudah tekan download PDF, kenapa tidak ada di folder Download?',
        body:
            'Setelah PDF dibuat, kamu masih perlu memilih tujuan penyimpanan '
            'di menu berbagi HP. Jika menu itu ditutup tanpa menyimpan, '
            'ulangi dari Download Laporan Bulanan PDF. Periksa lokasi '
            'yang kamu pilih saat menyimpan.',
      ),
      (
        title: 'Kenapa impor Excel ditolak?',
        body:
            'Gunakan file .xlsx dari template ekspor Jajanku. Pastikan sheet '
            'Transaksi dan nama kolom tetap ada, semua kolom terisi, nomor '
            'unik, nominal positif, tanggal valid, dan kategori sesuai jenis '
            'transaksi. Jangan gunakan rumus. Jika validasi gagal, data lama '
            'belum diubah; perbaiki baris yang disebut dalam pesan lalu impor ulang.',
      ),
      (
        title: 'Apakah impor hanya menambah transaksi baru?',
        body:
            'Tidak. Impor mengganti seluruh pemasukan dan pengeluaran '
            'dengan isi file. Ekspor cadangan dulu dan sertakan semua '
            'transaksi yang masih ingin kamu simpan di sheet Transaksi.',
      ),
      (
        title: 'Bisa share progres tanpa memperlihatkan nominal?',
        body:
            'Bisa. Di halaman progres, centang Tutup nominal sebelum '
            'menekan Bagikan atau Unduh. Periksa pratinjau karena persentase '
            'progres masih bisa terlihat.',
      ),
      (
        title: 'Kenapa data Guest tidak langsung muncul setelah login?',
        body:
            'Data Guest tersimpan di HP, sedangkan data akun tersimpan '
            'terpisah di cloud. Setelah login, riwayat menampilkan transaksi '
            'akun tersebut. Untuk melihat data Guest lagi, keluar dari akun.',
      ),
      (
        title: 'Apa yang dilakukan kalau data belum tersinkron?',
        body:
            'Periksa koneksi internet dan status sinkronisasi di Personalisasi. '
            'Jika muncul Coba sinkronkan lagi, tekan tombol itu. '
            'Pastikan kamu masuk dengan akun yang sama dengan akun '
            'tempat transaksi dicatat.',
      ),
    ],
  ),
];

class UsageGuideScreen extends StatelessWidget {
  const UsageGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cara Pakai')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Pilih panduan yang ingin kamu baca.'),
          ),
          Card(
            child: ListTile(
              title: const Text('Cara Catat'),
              subtitle: const Text(
                'Lihat tutorial mencatat dari bukti pembayaran',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showTutorialDialog(context),
            ),
          ),
          for (final topic in _topics)
            Card(
              child: ListTile(
                title: Text(topic.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _GuideDetailScreen(topic: topic),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GuideDetailScreen extends StatelessWidget {
  const _GuideDetailScreen({required this.topic});

  final _GuideTopic topic;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(topic.title)),
    body: SafeArea(
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final section in topic.sections) ...[
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    ),
  );
}
