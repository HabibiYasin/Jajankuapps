# Pengenalan kategori transaksi

`QrisParser.parseReceipt` memakai `TransactionClassifier` setelah parser bank
mengekstrak merchant dan nominal. Kategori bawaan parser bank tidak lagi
menentukan kategori hasil scan. Kategori yang sudah tersimpan tidak diubah
otomatis, termasuk pilihan manual pengguna.

Kamus offline berasal dari `Jajanku_1400_Keyword_Transaksi.xlsx`: 200 keyword
untuk masing-masing tujuh kategori. Versi yang dikompilasi beserta SHA-256
sumber ada di `lib/data/transaction_keywords.dart`. Kolom catatan/panduan
dalam spreadsheet tidak diimpor sebagai instruksi atau kode.

Regenerasi dengan Python standar, lalu format Dart:

```powershell
python tool/import_transaction_keywords.py 'C:/Users/User1/Downloads/Jajanku_1400_Keyword_Transaksi.xlsx'
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
Tambahan kurasi di luar spreadsheet: `susu formula` → Belanja.

Pengujian mencakup seluruh keyword kuat secara terpisah, contoh merchant,
batas kata, konflik kategori, detail pembayaran, serta integrasi parser.
Ini pengenalan berbasis aturan; hasil nyata tetap bergantung pada kualitas
OCR dan merchant yang berhasil diekstrak. Akurasi atas struk nyata belum
diukur dengan dataset berlabel independen.
