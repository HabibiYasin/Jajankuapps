# Premium melalui Google Play

Implementasi menggunakan **langganan otomatis**, sesuai keputusan produk.
Pembelian aktual memerlukan konfigurasi Play Console dan deployment Functions;
menjalankan Flutter saja belum mengaktifkan pembayaran.

## Data User

Firestore memakai dokumen `users/{uid}`, bukan tabel SQL.

| Field | Nilai / fungsi |
| --- | --- |
| `plan` | `free` atau `premium` |
| `userStatus` | `free`, `subscriber`, atau `exsubscriber`, dikelola server |
| `PremiumStartedAt` | Timestamp mulai langganan terverifikasi Google; null sebelum premium |
| `PremiumEndedAt` | Timestamp akhir periode aktif dari Google; berubah pada perpanjangan |
| `hasEverBeenPremium` | Riwayat pernah premium, tetap true setelah berakhir |
| `premiumAutoRenewing` | Status perpanjangan otomatis dari Google |
| `premiumSubscriptionState` | Status langganan Google terakhir diperiksa |
| `premiumLifetime` | Boolean pemberian premium seumur hidup oleh admin; default false |

Untuk langganan berbayar, tanggal memakai waktu Google, bukan menambahkan 30/180 hari di HP. Saat waktu
berakhir, akses premium di aplikasi ikut berakhir, termasuk ketika halaman
masih terbuka. Pembatalan otomatis tidak menghilangkan sisa periode berbayar.
`PremiumStartedAt` mengikuti awal langganan, bukan tanggal setiap tagihan ulang.
Setelah berakhir, tanggal terakhir tetap disimpan sebagai riwayat.

Client hanya boleh membuat nilai awal null/false. Seluruh perubahan premium
berasal dari Admin SDK di server. Koleksi privat `billingAccounts` menyimpan
riwayat kelayakan; `playPurchases` menyimpan token, pemilik, dan hasil verifikasi.
Keduanya tidak dapat dibaca, diubah, atau dihapus dari aplikasi.

## Premium seumur hidup untuk tester

Setelah memasang versi aplikasi yang mendukung lifetime, buka **Firebase Console
> project `jajanku-26976` > Firestore Database > users > UID tester**.
Pastikan UID sesuai akun tester yang sudah login. Tambahkan/ubah kedua field ini
dengan tipe **boolean**, bukan string:

```text
premiumLifetime: true
hasEverBeenPremium: true
```

Ulangi pada akun tester yang dipilih. Tidak perlu mengubah `plan`, mengisi
tanggal kedaluwarsa palsu, atau membuat transaksi Google Play. Jika tester belum
pernah berlangganan, `PremiumStartedAt` dan `PremiumEndedAt` boleh tetap null.

Aplikasi menampilkan **Premium seumur hidup**, menyembunyikan pilihan paket, dan
membuka semua fitur premium. `premiumLifetime` mempunyai prioritas atas status
dan tanggal langganan Google Play, termasuk saat `plan` bernilai `free`.
Sinkronisasi billing tetap memperbarui field langganan tanpa menyentuh flag
lifetime. Field `plan` dan tanggal merepresentasikan akses berjangka; akses
efektif adalah lifetime **atau** langganan premium yang masih berlaku.

Untuk mencabut pemberian tersebut, ubah hanya `premiumLifetime` menjadi `false`.
Biarkan `hasEverBeenPremium: true` agar riwayat tetap tercatat dan akun tidak
mendapat diskon pembelian pertama. Jika langganan berbayarnya masih aktif,
akses premium berbayar tetap berlaku sampai periode tersebut berakhir.
Jangan menghapus lalu membuat ulang dokumen profil untuk melakukan perubahan ini.

Field lifetime hanya dapat diberikan lewat Firebase Console/Admin SDK.
Firestore rules menolak aktivasi atau perubahan flag melalui aplikasi pengguna.
Deploy rules sebelum merilis aplikasi karena profil baru menyimpan nilai awal
`premiumLifetime: false`; deploy Functions juga untuk pemeriksaan riwayat diskon
dan hasil verifikasi yang memahami lifetime. Akun lama tanpa field ini tetap
berperilaku seperti sebelumnya; tidak memerlukan migrasi massal.

Pemberian ini tidak membuat pembelian atau membatalkan langganan Google Play.
Tester yang sebelumnya membayar tetap perlu membatalkan langganannya melalui
Google Play agar tagihan berikutnya berhenti. Penghapusan akun menghapus grant
lifetime; akun baru perlu diberi akses lagi oleh admin.

## Yang perlu dibuat di Google Play Console

1. Pastikan profil pembayaran/merchant siap, lalu buka aplikasi Android yang
   sesuai (`com.jajanku.app` untuk prod).
2. Di **Monetize with Play > Products > Subscriptions**, buat subscription
   **`jajanku_premium`** dengan dua base plan berikut. Aktifkan wilayah Indonesia.

| Base plan ID | Jenis | Periode penagihan | Harga Indonesia |
| --- | --- | --- | --- |
| `monthly` | Auto-renewing | 1 bulan | Rp10.000 |
| `six-monthly` | Auto-renewing | 6 bulan | Rp50.000 |

3. Aktifkan base plan. Untuk katalog baru, pembelian memakai harga normal tanpa
   offer otomatis. Voucher Firestore disimpan terpisah dan belum diterapkan ke Play.
4. Unggah AAB prod ke **Internal testing**, tambahkan penguji, dan daftarkan akun
   uji di **Settings > License testing**. Instal melalui tautan testing Play.
   Untuk flavor dev, gunakan aplikasi Play terpisah dengan package `com.jajanku.app.dev`.

Harga yang dapat dibeli selalu berasal dari Google Play. Ubah harga base plan dan
harga offer melalui Play Console; aplikasi menampilkan harga terbaru yang dikembalikan Play.
Tidak perlu mengubah kode atau mengisi harga duplikat di Firestore.

## Katalog paket dan voucher

Koleksi `subscriptions` memakai ID base plan Google Play. Contoh `monthly`:

```json
{"title":"1 bulan","billingPeriod":"P1M","price":10000,"currency":"IDR","durationDays":30,"enabled":true,"sortOrder":1}
```

`six-monthly` memakai `price: 50000`, `durationDays: 180`, `billingPeriod: "P6M"`.
`offerId` dan `discountPercent` sudah dihapus dari katalog. `price` adalah harga
katalog dalam rupiah yang dapat diedit admin. Harga pembayaran Google Play tetap
harus disesuaikan di Play Console. `durationDays` menyimpan durasi katalog;
tanggal akses pembelian Play tetap berasal dari periode terverifikasi Google,
karena satu bulan kalender tidak selalu 30 hari.

Koleksi `vouchers`, dokumen `cobapremium`:

| Field | Nilai awal |
| --- | --- |
| name | cobapremium |
| type | percentage |
| price | 75 |
| eligibleUntil | Timestamp 2 Januari 2027 00:00 WIB (batas eksklusif) |
| enabled | true |
| title | Cobain Premium |
| userStatus | free |
| subscriptionId | null (semua paket) |

Voucher berlaku sampai akhir 1 Januari 2027 WIB. `type` mendukung `percentage`
(potongan persen, maksimal 100) dan `absolute` (potongan rupiah). Potongan dibatasi
agar total tidak negatif. `userStatus` mendukung free, subscriber, exsubscriber;
`subscriptionId` berisi ID dokumen paket atau null. Callable `previewPremiumVoucher`
menerima `name` dan `subscriptionId`, memvalidasi akun, masa berlaku dan paket,
lalu mengembalikan perhitungan beserta `title`. Ini baru preview katalog:
`checkoutSupported: false`. Voucher database belum terhubung ke checkout Google Play;
aplikasi tidak mengiklankan diskon otomatis dari katalog ini.

Field `users.userStatus` mengikuti aturan:
- `hasEverBeenPremium` bukan true: free.
- `hasEverBeenPremium: true` dan `plan: premium`: subscriber.
- `hasEverBeenPremium: true` dan `plan: free`: exsubscriber.

Trigger `syncUserStatus` menyinkronkan field setelah perubahan profil. Status ini
merupakan klasifikasi, bukan sumber hak akses. `PremiumStartedAt` dan
`PremiumEndedAt` tetap divalidasi oleh server/client; lifetime tetap pengecualian.
Setelah lewat tanggal akhir, akses langsung berakhir di client, sementara status
tersimpan mengikuti pembaruan plan dari sinkronisasi billing.

Migrasi project lama (ADC, tanpa `--apply` hanya dry-run):

```powershell
node functions/scripts/migrate-catalog.js --project jajanku-26976 --apply
```

Migrasi mengatur ulang harga/durasi dua paket sesuai nilai awal di atas, menghapus
field diskon lama, membuat voucher jika belum ada, dan mengisi status semua user.
Jangan menjalankan ulang setelah mengubah harga jika ingin mempertahankan harga baru.
Deploy rules sebelum memakai aplikasi yang menambahkan `userStatus` saat registrasi.
Deploy Functions untuk mengaktifkan trigger dan preview voucher.

## Firebase / Google Cloud

1. Gunakan Firebase plan yang mendukung deployment Cloud Functions dan siapkan
   billing Google Cloud. Backend memakai Node.js 22, region `asia-southeast2`.
2. Aktifkan **Google Play Android Developer API** pada project Cloud masing-masing.
   Berikan service account runtime Functions akses ke aplikasi yang tepat melalui
   Play Console **Users and permissions**, termasuk melihat data keuangan dan
   mengelola pesanan/langganan (verifikasi, acknowledge, refund).
   Kredensial memakai Application Default Credentials di server, bukan JSON di APK.
3. Instal dependency dan buat konfigurasi lokal:

   ```powershell
   npm.cmd ci --prefix functions
   # Isi file functions/.env.jajanku-dev-25ae6:
   # PLAY_PACKAGE_NAME=com.jajanku.app.dev
   # Isi file functions/.env.jajanku-26976:
   # PLAY_PACKAGE_NAME=com.jajanku.app
   ```

4. Deploy ke dev terlebih dahulu, lalu prod setelah pengujian:

   ```powershell
   firebase deploy --only firestore:rules,functions --project jajanku-dev-25ae6
   firebase deploy --only firestore:rules,functions --project jajanku-26976
   ```

5. Functions memakai topic Pub/Sub **`google-play-billing`**. Pada IAM topic,
   berikan role **Pub/Sub Publisher** kepada
   `google-play-developer-notifications@system.gserviceaccount.com`.
   Pada pengaturan monetisasi Play Console, isi Real-time developer notifications
   dengan `projects/PROJECT_ID/topics/google-play-billing`. Aktifkan notifikasi
   subscription/voided purchase yang tersedia dan kirim test notification.
6. Periksa log `googlePlayNotifications`, lalu lakukan pembelian uji. Functions
   yang dideploy: `preparePremiumPurchase`, `verifyPremiumPurchase`,
   `googlePlayNotifications`, `reconcilePremiumPurchases`.

Server memeriksa token via `purchases.subscriptionsv2.get`, mencocokkan akun yang
disamarkan, menolak penggunaan token lintas akun, menyimpan entitlement secara
transaksional, lalu acknowledge. RTDN memperbarui renewal, cancellation,
hold/grace period, dan revocation; pemeriksaan setiap jam menjadi cadangan.
Pembayaran pending belum memberi premium atau menghabiskan kelayakan diskon.
Pembelian diskon yang melewati aturan riwayat akun ditolak dan dimintakan refund.
Pantau log kegagalan verifikasi/refund; gangguan API/IAM membutuhkan perbaikan
operator. Jangan mencatat token atau respons Google mentah ke log.

## Migrasi akun lama

Jalankan script admin dari direktori `functions` dengan ADC dan project eksplisit:

```powershell
Push-Location functions
node scripts/migrate-premium.js --project jajanku-dev-25ae6
# Setelah memeriksa hasil dry-run:
node scripts/migrate-premium.js --project jajanku-dev-25ae6 --apply
Pop-Location
```

Script menambahkan field yang belum ada dan menandai akun lama `premium`/`vip`
sebagai pernah premium. Akun premium lama tanpa tanggal perlu diisi dengan
tanggal hak akses yang sebenarnya melalui Admin SDK/Console sebelum rilis;
script melaporkan akun tersebut dan tidak mengarang masa berlaku. Tanpa tanggal
yang valid, aplikasi memperlakukan akses sebagai gratis agar tidak menjadi VIP
selamanya. Riwayat VIP lama yang sudah diubah menjadi `free` tanpa jejak tanggal
tidak bisa ditebak: isi `hasEverBeenPremium: true` dari catatan yang tersedia.

## Pengujian sebelum rilis

- Akun baru: harga Rp10.000/Rp50.000 untuk periode pertama; setelah itu harga normal.
- Mantan VIP, termasuk akun gratis dengan `hasEverBeenPremium: true`: tanpa offer.
- Pembayaran pending, dibatalkan, gagal, koneksi putus setelah membayar, tutup aplikasi.
- Restore pada akun yang sama dan penolakan pada akun Jajanku berbeda.
- Renewal memperbarui akhir premium; cancel tetap aktif sampai tanggal akhir;
  expire/hold/revoke melepas akses; grace period mengikuti expiry Google.
- Notifikasi duplikat/terlambat tidak menggandakan hak akses.
- Coba mengubah tanggal/plan/history via client: harus ditolak Firestore rules.

```powershell
flutter analyze
flutter test
npm.cmd test --prefix functions
firebase emulators:exec --only firestore --project demo-jajanku --config firebase.emulator.json "node test/firestore_rules_test.cjs"
firebase emulators:exec --only firestore --project demo-jajanku --config firebase.emulator.json "node functions/test/billing_emulator.cjs"
flutter build appbundle --flavor prod --release
```

Penghapusan akun Jajanku tidak membatalkan langganan Play. Pengguna perlu
membatalkannya melalui tombol Kelola langganan. Metadata verifikasi billing
disimpan terpisah untuk menangani transaksi dan mencegah replay; penghapusan
profil tidak menghidupkan ulang profil saat RTDN datang. Sesuaikan pengungkapan
Data safety dan kebijakan retensi operasional dengan data billing ini.

Referensi resmi:
- [Konfigurasi base plan dan offer](https://support.google.com/googleplay/android-developer/answer/140504?hl=en)
- [Verifikasi dan keamanan transaksi](https://developer.android.com/google/play/billing/security)
- [Siklus hidup subscription](https://developer.android.com/google/play/billing/lifecycle/subscriptions)
- [Referensi SubscriptionPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2)
- [RTDN dan Pub/Sub](https://developer.android.com/google/play/billing/getting-ready#configure-rtdn)
