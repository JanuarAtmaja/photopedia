import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/photo_state.dart';
import '../main.dart';
import '../screens/edit_photo_screen.dart';

/// LightboxViewer menampilkan foto dalam ukuran penuh layar.
/// Mendukung navigasi prev/next antar foto dan fitur download.
class LightboxViewer extends StatefulWidget {
  /// Daftar semua foto yang bisa dinavigasi.
  final List<PhotoItem> photos;

  /// Indeks foto yang pertama kali dibuka.
  final int initialIndex;

  const LightboxViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  /// Buka lightbox dari mana saja dengan Navigator.
  static Future<void> show(
    BuildContext context, {
    required List<PhotoItem> photos,
    required int initialIndex,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => LightboxViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<LightboxViewer> createState() => _LightboxViewerState();
}

class _LightboxViewerState extends State<LightboxViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  void _goTo(int index) {
    if (index < 0 || index >= widget.photos.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  /// Algoritma download: salin file foto ke direktori Downloads / Documents
  /// lalu tampilkan konfirmasi kepada pengguna.
  Future<void> _downloadPhoto() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final photo = widget.photos[_currentIndex];
      final sourceFile = File(photo.path);

      if (!await sourceFile.exists()) {
        throw Exception('File foto tidak ditemukan.');
      }

      // Simpan ke direktori Documents yang bisa diakses pengguna
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'photopedia_${photo.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = p.join(dir.path, 'downloads', fileName);

      // Buat folder downloads jika belum ada
      await Directory(p.dirname(destPath)).create(recursive: true);

      // Salin file
      final Uint8List bytes = await sourceFile.readAsBytes();
      await File(destPath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto disimpan ke: $fileName'),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // ─── PageView: geser kiri-kanan untuk navigasi ────────────────────
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white54, size: 80),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ─── Kontrol overlay (tampil/sembunyi saat tap) ───────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    // Top bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                // Tombol tutup
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const Spacer(),
                                // Counter foto
                                Text(
                                  '${_currentIndex + 1} / $total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                // FIX 3: Tombol edit foto — langsung ke EditPhotoScreen
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: Colors.white),
                                  tooltip: 'Edit foto',
                                  onPressed: () {
                                    final photo = widget.photos[_currentIndex];
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EditPhotoScreen(photoPaths: [photo.path],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Tombol download
                                _isDownloading
                                    ? const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.download_rounded,
                                            color: Colors.white),
                                        tooltip: 'Unduh foto',
                                        onPressed: _downloadPhoto,
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Tombol Prev
                    if (_currentIndex > 0)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _NavButton(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => _goTo(_currentIndex - 1),
                          ),
                        ),
                      ),

                    // Tombol Next
                    if (_currentIndex < total - 1)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _NavButton(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => _goTo(_currentIndex + 1),
                          ),
                        ),
                      ),

                    // Bottom: thumbnail strip
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: SafeArea(
                          child: SizedBox(
                            height: 72,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              itemCount: total,
                              itemBuilder: (context, index) {
                                final isActive = index == _currentIndex;
                                return GestureDetector(
                                  onTap: () => _goTo(index),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(right: 6),
                                    width: isActive ? 56 : 48,
                                    height: isActive ? 56 : 48,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: isActive
                                          ? Border.all(
                                              color:
                                                  kPrimary,
                                              width: 2.5)
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      child: Image.file(
                                        File(widget.photos[index].path),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: Colors.grey.shade800,
                                          child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.white30,
                                              size: 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
