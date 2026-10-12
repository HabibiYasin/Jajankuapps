# Pengenalan kategori transaksi

`QrisParser.parseReceipt` memakai `TransactionClassifier` setelah parser bank
mengekstrak merchant dan nominal. Kategori bawaan parser bank tidak lagi
menentukan kategori hasil scan. Kategori yang sudah tersimpan tidak diubah
otomatis, termasuk pilihan manual pengguna.

Untuk QRIS, parser khusus yang cocok dipakai sebelum parser umum. Nama
BCA Syariah tetap dikenali ketika OCR memisahkan BCA dan Syariah menjadi dua
baris. Label Sumber Dana, Tujuan, dan Total Transaksi saja tidak cukup untuk
menentukan bank; jika identitas bank tidak terbaca, sumber tetap Tidak Diketahui.
Penyebutan bank hanya sebagai penerima/acquirer tidak memilih parsernya.
Parser umum dipakai jika format/metode belum didukung, ketika parser khusus
melaporkan field yang tidak terbaca (`ReceiptLayoutException`), atau untuk
mengganti merchant yang ternyata berisi metadata. Error status dan tanggal
tidak dialihkan menjadi transaksi melalui fallback.

`ReceiptStatus` menolak status gagal, pending, tertunda, dan dibatalkan sebelum
pemilihan parser. `ReceiptAmount` menyatukan pembacaan nominal: total akhir
didahulukan, saldo/cashback/kembalian/uang tunai yang diserahkan dikecualikan,
dan desimal dipertahankan. Angka tanpa Rp/IDR hanya dibaca sebagai nominal
jika berlabel jumlah uang, agar nomor rekening/referensi tidak ikut terbaca.
Total nol tetap nol; validasi penyimpanan pengeluaran menolaknya.

Kamus offline berasal dari `Jajanku_7000_Keyword_Transaksi.xlsx`: 1.000 keyword
untuk masing-masing tujuh kategori. Versi yang dikompilasi beserta SHA-256
sumber ada di `lib/data/transaction_keywords.dart`. Kolom catatan/panduan
dalam spreadsheet tidak diimpor sebagai instruksi atau kode.

Regenerasi dengan Python standar, lalu format Dart:

```powershell
python tool/import_transaction_keywords.py 'C:/Users/User1/Downloads/Jajanku_7000_Keyword_Transaksi.xlsx'
dart format lib/data/transaction_keywords.dart
```

Pencocokan mengabaikan huruf besar/kecil dan tanda baca, menggunakan batas
kata, dan mengutamakan frasa yang mencakup keyword lebih pendek. Keyword
kuat mengalahkan sinyal sedang. Dua kategori kuat yang bertentangan menjadi
`Umum`, sehingga dapat dikoreksi melalui Edit Detail. Pencocokan kabur
berdasarkan kemiripan huruf tidak digunakan untuk menghindari tebakan nama.

Merchant menjadi sumber utama. Detail eksplisit berlabel Keterangan, Catatan,
Deskripsi, Produk, Item, atau Layanan dapat membantu merchant yang tidak
dikenal atau merchant umum seperti Indomaret. Nama pengirim, metode bayar,
nama bank, footer, serta teks promosi di luar detail tersebut tidak dipakai.
Keyword kontekstual seperti Gojek, top up, atau nama orang bukan bukti tunggal
yang cukup. Pengecualian retailer dan kata ambigu tercatat di classifier.
Tambahan kurasi di luar spreadsheet: `susu formula` ke Belanja,
`A&W` ke Makanan, dan `H&M` ke Belanja. Dua nama merchant tersebut tetap
dikenali meski versi spreadsheet baru menandainya kontekstual.

Keyword `chicken` dan `ayam` masuk Makanan; `warung` tanpa petunjuk yang lebih spesifik
masuk Belanja. Frasa seperti `warung makan`, `warung kopi`, `chicken nugget`,
dan `frozen chicken` tetap mengikuti kategori spesifiknya. Detail produk
eksplisit juga dapat memperjelas kategori warung, misalnya pembelian token
listrik menjadi Tagihan & Pulsa, termasuk ketika label Produk dan nilainya
berada pada baris berbeda. KFC, Warung Tekko, Warung Leko, dan Ayam Bang Doyok
dikurasi sebagai Makanan; daging ayam dan telur ayam sebagai Belanja.

Pengujian mencakup seluruh keyword kuat secara terpisah, contoh merchant,
batas kata, konflik kategori, detail pembayaran, serta integrasi parser.
Ini pengenalan berbasis aturan; hasil nyata tetap bergantung pada kualitas
OCR dan merchant yang berhasil diekstrak. Akurasi atas struk nyata belum
diukur dengan dataset berlabel independen.
