# Photopedia — QA Checklist & Dokumentasi Rilis

## Struktur Folder

```
lib/
├── main.dart                        ← Entry point + MainShell (Drawer + BottomNav)
├── models/
│   └── photo_state.dart             ← AppState + PhotoItem (dengan persistensi)
├── screens/
│   ├── home_screen.dart             ← Beranda + foto terbaru
│   ├── camera_screen.dart           ← Kamera + filter real-time + drag-drop upload
│   ├── gallery_screen.dart          ← Galeri + Lightbox + upload + delete
│   ├── preview_screen.dart          ← Preview foto + pemilih bingkai
│   ├── edit_photo_screen.dart       ← Editor filter + brightness + overlay
│   ├── email_screen.dart            ← Kirim email via Resend API
│   └── analytics_screen.dart       ← Dashboard statistik aktivitas pengguna
├── services/
│   ├── analytics_service.dart      ← Pencatat log aktivitas (SharedPreferences)
│   ├── email_service.dart           ← Integrasi Resend API
│   └── storage_service.dart        ← Persistensi foto ke SharedPreferences
└── widgets/
    ├── lightbox_viewer.dart         ← Full-screen preview + prev/next + download
    └── photo_grid_item.dart         ← Item grid foto di beranda

assets/
└── frames/
    ├── Frame_1.png   ← Bingkai Film Strip (hitam)
    ├── Frame_2.png   ← Bingkai Y2K Vibes (ungu-pink)
    └── Frame_3.png   ← Bingkai Music Player (abu-hijau)
```

---

## Setup Awal

### 1. Daftarkan asset bingkai
Salin `Frame_1.png`, `Frame_2.png`, `Frame_3.png` ke `assets/frames/` di root proyek,
lalu pastikan `pubspec.yaml` sudah mendaftarkannya (sudah tersedia).

### 2. Jalankan `flutter pub get`

### 3. Konfigurasi API email
Buka `lib/services/email_service.dart` dan ganti:
```dart
static const String _apiKey = 'YOUR_RESEND_API_KEY';
```

---

## Fase 1 — Fitur Baru

| Fitur | File |
|---|---|
| **LocalStorage / Persistensi** | `services/storage_service.dart` + `models/photo_state.dart` |
| **Analitik Pengguna** | `services/analytics_service.dart` + `screens/analytics_screen.dart` |
| **Drag & Drop Upload** | `screens/gallery_screen.dart` → `_handlePickUpload()` |
| **Lightbox Preview + Download** | `widgets/lightbox_viewer.dart` |
| **Bingkai (Frame) di Preview** | `screens/preview_screen.dart` |

### Detail Implementasi

#### LocalStorage
- `StorageService.savePhotos()` dipanggil otomatis setiap kali foto ditambah, diedit, atau dihapus.
- `AppState.loadFromStorage()` dipanggil di `main()` sebelum `runApp()`.
- Data format JSON di `SharedPreferences` dengan key `photopedia_photos`.

#### Analitik
Data yang dicatat: `photo_taken`, `photo_clicked`, `photo_sent`, `photo_deleted`.
Akses dashboard: Drawer → **Analitik Pengguna**.

#### Drag & Drop Upload
- `ImagePicker.pickMultiImage()` memungkinkan pilih banyak foto sekaligus.
- Validasi ekstensi: hanya `jpg/jpeg/png/webp/gif/heic` yang diterima.
- File tidak valid diabaikan dengan notifikasi snackbar.

#### Lightbox
- Buka via `LightboxViewer.show(context, photos: [...], initialIndex: i)`.
- Navigasi prev/next: geser atau tekan tombol chevron.
- Download: simpan ke `<Documents>/downloads/` dengan nama unik.
- Thumbnail strip di bagian bawah untuk lompat langsung ke foto tertentu.

---

## Fase 2 — Bug Fixing

| Bug | Perbaikan |
|---|---|
| Bingkai tidak bisa diklik | Pemilih bingkai ditambahkan di `preview_screen.dart` sebagai `ListView` horizontal |
| Asset frame tidak termuat | `pubspec.yaml` didaftarkan + `errorBuilder` fallback di setiap `Image.asset()` |
| Drag & drop tidak responsif | Diganti dengan `ImagePicker` multi-file + validasi format |
| Analitik email tidak tercatat | `AnalyticsService.logPhotoSent()` ditambahkan di `email_screen.dart` |
| Data hilang saat restart | `StorageService` + `loadFromStorage()` di `main()` |

---

## Fase 3 — QA Checklist Rilis

### Fungsionalitas Inti
- [ ] Kamera berhasil diinisialisasi dan menampilkan preview
- [ ] Filter real-time (B&W, Sepia, Invert, Vintage) diterapkan pada preview
- [ ] Foto berhasil diambil dan tersimpan ke storage
- [ ] Foto muncul di galeri setelah diambil
- [ ] **Data foto tidak hilang setelah app ditutup dan dibuka ulang** ✓ (SharedPreferences)
- [ ] Upload multi-foto dari galeri berfungsi
- [ ] Hanya format gambar yang diterima saat upload
- [ ] Lightbox terbuka dengan foto yang diklik
- [ ] Navigasi prev/next di lightbox berfungsi
- [ ] Tombol download di lightbox menyimpan file
- [ ] Bingkai Film Strip, Y2K Vibes, Music Player tampil di preview
- [ ] Filter gambar (grayscale, sepia, invert) di editor berfungsi
- [ ] Slider brightness mengubah kecerahan foto
- [ ] Tombol reset editor mengembalikan ke foto asli
- [ ] Form email divalidasi (nama, email, subjek wajib diisi)
- [ ] Validasi format email berjalan
- [ ] Email berhasil terkirim via Resend API
- [ ] Status modal berhasil/gagal muncul setelah kirim email

### Analitik
- [ ] Jumlah foto diambil bertambah setiap kali kamera dipakai
- [ ] Jumlah klik bertambah saat foto dibuka
- [ ] Jumlah terkirim bertambah saat email sukses
- [ ] Jumlah dihapus bertambah saat foto dihapus
- [ ] Dashboard analitik menampilkan log terbaru
- [ ] Tombol reset statistik berfungsi

### UI/UX
- [ ] Bottom navigation berpindah tab dengan benar
- [ ] Drawer terbuka dari semua halaman
- [ ] Tidak ada overflow/clipping pada semua ukuran layar
- [ ] Loading indicator muncul saat proses berlangsung
- [ ] Snackbar notifikasi muncul untuk aksi penting
- [ ] Long-press di galeri menampilkan context menu (favorit, lihat, hapus)

### Konsol & Performa
- [ ] Tidak ada error merah di konsol saat runtime normal
- [ ] Tidak ada warning `setState() called after dispose()`
- [ ] Tidak ada memory leak (controller di-dispose dengan benar)
- [ ] Scroll galeri lancar tanpa jank

### Cross-Platform
- [ ] Android: izin kamera dan storage diminta dengan benar
- [ ] iOS: `Info.plist` sudah berisi key kamera dan galeri
- [ ] Orientasi portrait terkunci

---

## Catatan Deployment

1. **Android** — tambahkan di `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA"/>
   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
   ```

2. **iOS** — tambahkan di `Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Photopedia membutuhkan akses kamera untuk mengambil foto.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Photopedia membutuhkan akses galeri untuk memilih foto.</string>
   ```

3. **Email API** — Ganti API key di `email_service.dart` dengan key production Resend.
