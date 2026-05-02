# 📸 Photopedia — Flutter Photobooth App

Aplikasi photobooth mobile yang dibangun dengan Flutter, berdasarkan wireframe desain ungu/lavender yang modern.

---

## ✨ Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| 📷 **Kamera** | Akses kamera perangkat secara langsung, flash control, switch kamera depan/belakang |
| 🖼️ **Edit Foto** | Filter (B&W, Warm, Cool, Vivid), sesuaikan Kecerahan/Kontras/Saturasi, Bingkai, Teks, Stiker |
| 👁️ **Preview** | Tampilkan foto hasil dengan metadata (ukuran, waktu, filter), langsung ke Email |
| 🗂️ **Galeri** | Lihat semua foto dengan tab: Semua, Favorit, Hari ini, Minggu ini |
| 📧 **Kirim Email** | Kirim foto ke email tujuan via Gmail SMTP, attachment otomatis |
| 📤 **Drag & Drop** | Upload foto dari galeri perangkat dengan drag-and-drop atau pilih file |

---

## 🚀 Setup & Jalankan

### Prasyarat
- Flutter SDK ≥ 3.0.0 (https://flutter.dev/docs/get-started/install)
- Dart SDK ≥ 3.0.0
- Android Studio / Xcode (untuk emulator atau device fisik)

### Langkah Instalasi

```bash
# 1. Masuk ke folder proyek
cd photopedia

# 2. Install dependencies
flutter pub get

# 3. Jalankan di device/emulator
flutter run
```

### Untuk Android
Pastikan `minSdkVersion` di `android/app/build.gradle` adalah **21** atau lebih tinggi:
```gradle
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

### Untuk iOS
```bash
cd ios
pod install
cd ..
flutter run
```

---

## 📧 Konfigurasi Kirim Email

Untuk menggunakan fitur kirim email, Anda memerlukan **Gmail App Password** (bukan password akun biasa):

1. Buka [Google Account Settings](https://myaccount.google.com/)
2. Pilih **Security** → **2-Step Verification** (aktifkan jika belum)
3. Di bagian bawah, klik **App passwords**
4. Buat app password baru → pilih "Mail" dan "Android/iPhone"
5. Salin 16-karakter password yang dihasilkan
6. Masukkan Gmail dan App Password tersebut di layar **Kirim Email** pada aplikasi

---

## 📁 Struktur Proyek

```
lib/
├── main.dart                  # Entry point + navigasi utama
├── models/
│   └── photo_state.dart       # State management global (AppState + AppStateScope)
├── screens/
│   ├── home_screen.dart       # Halaman beranda + foto terbaru
│   ├── camera_screen.dart     # Kamera + drag & drop upload
│   ├── edit_photo_screen.dart # Editor: filter, adjust, bingkai, teks, stiker
│   ├── preview_screen.dart    # Preview hasil foto
│   ├── gallery_screen.dart    # Galeri dengan filter tab
│   └── email_screen.dart      # Kirim foto via email
└── widgets/
    └── photo_grid_item.dart   # Komponen item foto di grid

android/app/src/main/
└── AndroidManifest.xml        # Izin kamera & storage Android

ios/Runner/
└── Info.plist                 # Izin kamera & galeri iOS
```

---

## 🎨 Desain

- **Warna utama**: `#6B4EFF` (ungu)
- **Warna sekunder**: `#B39DFF` (lavender)
- **Background**: `#F8F5FF` (putih ungu lembut)
- Font: Material3 default (Roboto)
- Corner radius: 12–20px untuk kartu dan tombol

---

## 📦 Dependencies Utama

```yaml
camera: ^0.10.5+9          # Akses kamera native
image_picker: ^1.1.2       # Pilih foto dari galeri
path_provider: ^2.1.3      # Direktori penyimpanan
mailer: ^6.1.2             # Kirim email SMTP
photo_view: ^0.15.0        # Tampilan foto interaktif
intl: ^0.19.0              # Format tanggal/waktu
```

---

## 🔮 Pengembangan Selanjutnya

- [ ] Simpan foto ke galeri sistem (gallery_saver)
- [ ] Multi-foto attachment di email
- [ ] Export foto dengan watermark
- [ ] Share ke media sosial
- [ ] Efek blur real-time di kamera
- [ ] Cloud backup foto
