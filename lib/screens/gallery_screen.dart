import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/photo_state.dart';
import '../widgets/lightbox_viewer.dart';
import '../main.dart';
import 'edit_photo_screen.dart';
import 'preview_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDragOver = false; // state untuk drag-and-drop highlight

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Drag & Drop: validasi dan handle file yang di-drop ─────────────────────
  // Flutter mobile tidak support drag-drop dari luar app, tetapi kita sediakan
  // tombol upload yang meniru UX drag-drop dengan File API (ImagePicker).

  Future<void> _handlePickUpload() async {
    try {
      final picker = ImagePicker();
      // Izinkan pilih banyak foto sekaligus (multi-upload)
      final List<XFile> picked = await picker.pickMultiImage();
      if (picked.isEmpty || !mounted) return;

      // Validasi: hanya format gambar yang diterima
      const validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'];
      final validFiles = picked.where((f) {
        final ext = f.path.split('.').last.toLowerCase();
        return validExtensions.contains(ext);
      }).toList();

      if (validFiles.isEmpty) {
        _showSnack('Format file tidak didukung. Gunakan JPG/PNG/WEBP.');
        return;
      }

      if (validFiles.length < picked.length) {
        _showSnack(
            '${picked.length - validFiles.length} file diabaikan (format tidak valid).');
      }

      final state = AppStateScope.of(context);
      final dir = await getApplicationDocumentsDirectory();

      for (final file in validFiles) {
        final savedPath = p.join(
          dir.path,
          'photo_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
        );
        await File(file.path).copy(savedPath);
        await state.addPhoto(savedPath);
      }

      _showSnack('${validFiles.length} foto berhasil diunggah!',
          isSuccess: true);
    } catch (e) {
      _showSnack('Gagal mengunggah: $e');
    } finally {
      setState(() => _isDragOver = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isSuccess ? const Color(0xFF5B62B3) : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFEDE2E0),
      appBar: AppBar(
        title: const Text('Galeri'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF5B62B3)),
          onPressed: () =>
              MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Tombol upload (Drag & Drop alternatif untuk mobile)
          IconButton(
            icon: const Icon(Icons.upload_rounded, color: Color(0xFF5B62B3)),
            tooltip: 'Upload foto',
            onPressed: _handlePickUpload,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF5B62B3),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5B62B3),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF5B62B3),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Favorit'),
            Tab(text: 'Hari ini'),
            Tab(text: 'Minggu ini'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _PhotoGrid(
                    photos: state.photos.toList(),
                    allPhotos: state.photos.toList(),
                  ),
                  _PhotoGrid(
                    photos: state.favoritePhotos,
                    allPhotos: state.favoritePhotos,
                  ),
                  _PhotoGrid(
                    photos: state.todayPhotos,
                    allPhotos: state.todayPhotos,
                  ),
                  _PhotoGrid(
                    photos: state.thisWeekPhotos,
                    allPhotos: state.thisWeekPhotos,
                  ),
                ],
              ),

              // ─── Drop Zone overlay ────────────────────────────────────
              if (state.photos.isEmpty)
                Center(
                  child: _DropZoneWidget(
                    isDragOver: _isDragOver,
                    onTap: _handlePickUpload,
                  ),
                ),
            ],
          );
        },
      ),

      // FAB Upload
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handlePickUpload,
        backgroundColor: const Color(0xFF5B62B3),
        icon: const Icon(Icons.add_photo_alternate_rounded,
            color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ─── Drop Zone Widget ───────────────────────────────────────────────────────

class _DropZoneWidget extends StatelessWidget {
  final bool isDragOver;
  final VoidCallback onTap;

  const _DropZoneWidget({required this.isDragOver, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDragOver
              ? const Color(0xFF5B62B3).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDragOver
                ? const Color(0xFF5B62B3)
                : const Color(0xFFCFD1E8),
            width: isDragOver ? 2.5 : 1.5,
            // Efek dashed via outline
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B62B3).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDragOver
                  ? Icons.file_download_rounded
                  : Icons.add_photo_alternate_outlined,
              size: 64,
              color: isDragOver
                  ? const Color(0xFF5B62B3)
                  : const Color(0xFF8E93CC),
            ),
            const SizedBox(height: 16),
            Text(
              isDragOver ? 'Lepaskan untuk mengunggah' : 'Upload Foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDragOver
                    ? const Color(0xFF5B62B3)
                    : const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ketuk atau seret foto ke sini\nFormat: JPG, PNG, WEBP, GIF',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Pilih dari Galeri'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B62B3),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Photo Grid ─────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<PhotoItem> photos;
  // allPhotos dipakai lightbox agar navigasi prev/next mencakup semua tab
  final List<PhotoItem> allPhotos;

  const _PhotoGrid({required this.photos, required this.allPhotos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: Color(0xFF8E93CC)),
            SizedBox(height: 12),
            Text('Belum ada foto', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _GridCell(
          photo: photo,
          onTap: () {
            AppStateScope.of(context).selectPhoto(photo);
            LightboxViewer.show(context, photos: photos, initialIndex: index);
          },
          onEdit: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EditPhotoScreen(photoPaths: [photo.path]),
          )),
          onPreview: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PreviewScreen(photoPaths: [photo.path]),
          )),
          onDelete: () => _confirmDelete(context, photo),
          onFavorite: () => AppStateScope.of(context).toggleFavorite(photo.id),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PhotoItem photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Foto?'),
        content: const Text('Foto akan dihapus dari galeri.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await AppStateScope.of(context).deletePhoto(photo.id);
    }
  }
}

// ─── Grid Cell dengan long-press menu ───────────────────────────────────────

class _GridCell extends StatelessWidget {
  final PhotoItem photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;      // ← BARU
  final VoidCallback onPreview;   // ← BARU: buka preview + bingkai

  const _GridCell({
    required this.photo,
    required this.onTap,
    required this.onDelete,
    required this.onFavorite,
    required this.onEdit,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8E4F5),
                child: const Icon(Icons.broken_image,
                    color: Color(0xFF8E93CC)),
              ),
            ),
          ),
          if (photo.isFavorite)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    color: Colors.pinkAccent, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                photo.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border_rounded,
                color: photo.isFavorite ? Colors.pinkAccent : Colors.grey,
              ),
              title: Text(photo.isFavorite
                  ? 'Hapus dari Favorit'
                  : 'Tambah ke Favorit'),
              onTap: () {
                Navigator.pop(context);
                onFavorite();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF5B62B3)),
              title: const Text('Edit Foto (Filter & Teks)'),
              onTap: () { Navigator.pop(context); onEdit(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_size_select_large_rounded, color: Colors.teal),
              title: const Text('Pasang Bingkai'),
              onTap: () { Navigator.pop(context); onPreview(); },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded, color: Color(0xFF5B62B3)),
              title: const Text('Lihat Ukuran Penuh'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Hapus Foto',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
