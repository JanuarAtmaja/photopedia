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
  bool _isDragOver = false;

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

  Future<void> _handlePickUpload() async {
    try {
      final picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultiImage();
      if (picked.isEmpty || !mounted) return;

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
      if (!mounted) return;

      for (final file in validFiles) {
        final savedPath = p.join(
          dir.path,
          'photo_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
        );
        await File(file.path).copy(savedPath);
        await state.addPhoto(savedPath);
        if (!mounted) return;
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
      backgroundColor: isSuccess ? kPrimary : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isDark = ThemeModeScope.of(context);
    final bg = isDark ? kBackgroundDark : kBackground;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Galeri'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: kPrimary),
          onPressed: () =>
              MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded, color: kPrimary),
            tooltip: 'Upload foto',
            onPressed: _handlePickUpload,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.grey.shade600,
              indicator: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Semua', height: 36),
                Tab(text: 'Favorit', height: 36),
                Tab(text: 'Hari ini', height: 36),
                Tab(text: 'Minggu ini', height: 36),
              ],
            ),
          ),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: FloatingActionButton(
          onPressed: _handlePickUpload,
          backgroundColor: kPrimary,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.add_photo_alternate_rounded,
              color: Colors.white, size: 24),
        ),
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
    final isDark = ThemeModeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDragOver
              ? kPrimary.withValues(alpha: 0.08)
              : (isDark ? kSurfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDragOver ? kPrimary : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isDragOver ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDragOver
                  ? Icons.file_download_rounded
                  : Icons.add_photo_alternate_outlined,
              size: 56,
              color: isDragOver ? kPrimary : kPrimaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              isDragOver ? 'Lepaskan untuk mengunggah' : 'Upload Foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDragOver
                    ? kPrimary
                    : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ketuk untuk memilih foto\nFormat: JPG, PNG, WEBP, GIF',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Pilih dari Galeri'),
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
  final List<PhotoItem> allPhotos;

  const _PhotoGrid({required this.photos, required this.allPhotos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 56, color: kPrimaryLight.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('Belum ada foto', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  final VoidCallback onEdit;
  final VoidCallback onPreview;

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
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Container(
                color: kPrimary.withValues(alpha: 0.08),
                child: const Icon(Icons.broken_image,
                    color: kPrimaryLight),
              ),
            ),
          ),
          if (photo.isFavorite)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
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
    final isDark = ThemeModeScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? kSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _MenuTile(
              icon: photo.isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
              iconColor: photo.isFavorite ? Colors.pinkAccent : Colors.grey,
              label: photo.isFavorite ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
              onTap: () { Navigator.pop(context); onFavorite(); },
            ),
            _MenuTile(
              icon: Icons.edit_rounded,
              iconColor: kPrimary,
              label: 'Edit Foto (Filter & Teks)',
              onTap: () { Navigator.pop(context); onEdit(); },
            ),
            _MenuTile(
              icon: Icons.photo_size_select_large_rounded,
              iconColor: const Color(0xFF26A69A),
              label: 'Pasang Bingkai',
              onTap: () { Navigator.pop(context); onPreview(); },
            ),
            _MenuTile(
              icon: Icons.fullscreen_rounded,
              iconColor: kPrimary,
              label: 'Lihat Ukuran Penuh',
              onTap: () { Navigator.pop(context); onTap(); },
            ),
            _MenuTile(
              icon: Icons.delete_rounded,
              iconColor: Colors.red,
              label: 'Hapus Foto',
              labelColor: Colors.red,
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(label, style: TextStyle(
        color: labelColor, fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
