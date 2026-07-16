# Dojo Internship Mobile

Aplikasi Flutter untuk KMI Internship Monitoring pada Android dan iOS. Aplikasi menggunakan REST API v1 yang didokumentasikan pada `../API.md` dan tidak mengakses database secara langsung.

## Fitur per role

| Fitur | Intern | Mentor | HRD / Headmaster |
|---|:---:|:---:|:---:|
| Dashboard | ✅ | ✅ | ✅ |
| Leaderboard | ✅ | ✅ | ✅ |
| Absensi | Clock In/Out, Face ID, lokasi, riwayat | — | Monitoring |
| Calendar Sharing | ✅ | ✅ | ✅ |
| Rapor Intern | Rapor sendiri | Daftar rapor | Daftar rapor |
| Pengajuan WFH | — | — | Review approve/reject |
| Report | — | Agregasi dashboard + evaluasi | Agregasi dashboard + evaluasi |
| Notifikasi | ✅ | ✅ | ✅ |

Navigasi bawah berubah sesuai role agar fitur yang paling sering dipakai selalu mudah dijangkau.

## Menjalankan aplikasi

1. Pastikan Flutter stable dan Android Studio/Xcode telah terpasang.
2. Dari folder `dojo`, ambil dependency:

   ```bash
   flutter pub get
   ```

3. Jalankan Laravel API dari root repository:

   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```

4. Jalankan Flutter dengan URL API sesuai perangkat:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
   ```

Alamat umum:

- Android Emulator: `http://10.0.2.2:8000/api/v1` (nilai default aplikasi).
- iOS Simulator: `http://127.0.0.1:8000/api/v1`.
- Perangkat fisik: gunakan IP LAN komputer, misalnya `http://192.168.1.10:8000/api/v1`.
- Staging/production: wajib HTTPS, misalnya `https://internship.example.com/api/v1`.

Di Windows, Flutter plugin memerlukan symbolic link. Aktifkan **Developer Mode** melalui Settings → Privacy & security → For developers bila `flutter pub get` menampilkan pesan `Building with plugins requires symlink support`.

## Absensi dan permission

Alur intern pada halaman Absensi:

1. Daftarkan Face ID dengan tiga foto jika belum terdaftar.
2. Aplikasi mengambil foto terbaru dari kamera depan.
3. Aplikasi meminta lokasi presisi saat tindakan dilakukan.
4. Foto terkompresi, koordinat, akurasi, dan informasi perangkat dikirim ke API.
5. Server tetap menjadi source of truth untuk kecocokan wajah, radius, WFH, jam kerja, dan status kehadiran.

Permission yang telah disiapkan:

- Android: internet, kamera, coarse/fine location, notification, vibration, dan reschedule notification setelah reboot.
- iOS: kamera dan location while in use; permission notification diminta melalui aplikasi.

## Notifikasi

Implementasi saat ini memiliki dua lapis:

- Pengingat Clock In 15 menit sebelum window dimulai dan Clock Out 10 menit sebelum window dimulai, Senin–Jumat. Jam mengikuti `settings` dari endpoint absensi. Notifikasi menggunakan suara dan getaran serta tetap dijadwalkan di perangkat.
- Notifikasi server disinkronkan setiap 30 detik selama aplikasi aktif dan saat aplikasi kembali ke foreground. Item baru ditampilkan sebagai device notification dan getaran.

Push realtime ketika aplikasi terminated belum dapat diaktifkan hanya dari mobile client. API saat ini belum memiliki registrasi device token dan repository belum berisi konfigurasi Firebase/APNs. Untuk produksi, tambahkan:

1. Firebase project beserta aplikasi Android/iOS dan APNs key.
2. `firebase_core` dan `firebase_messaging` pada Flutter.
3. Endpoint API register/unregister device token per user/perangkat.
4. Pengiriman FCM dari `NotificationService` Laravel ketika notifikasi database dibuat.
5. Rotasi token, logout cleanup, deep link, dan pengujian background/terminated pada perangkat fisik.

Tanpa kelima komponen tersebut, klaim push realtime ketika aplikasi ditutup tidak dapat dijamin oleh Android maupun iOS.

## Struktur kode

```text
lib/
├── core/          tema, formatter, dan HTTP client
├── models/        model sesi user
├── repositories/  pemetaan endpoint API
├── services/      local notification dan reminder
├── state/         lifecycle autentikasi
├── widgets/       komponen UI reusable
└── features/      layar per fitur
```

Bearer token disimpan menggunakan secure storage (Android Keystore/EncryptedSharedPreferences dan iOS Keychain). Respons `401` otomatis menghapus token dan mengembalikan user ke login.

## Quality checks

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Sebelum rilis, ganti application ID/bundle ID `com.example.dojo`, siapkan signing Android, Apple Team/provisioning profile, icon aplikasi final, URL API HTTPS, Firebase/APNs, serta privacy disclosure untuk kamera, lokasi, dan biometrik wajah.
