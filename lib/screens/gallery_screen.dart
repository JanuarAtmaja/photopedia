import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_state.dart';
import '../widgets/photo_grid_item.dart';
import 'preview_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text('Galeri'),
        centerTitle: false,
        // Gunakan Builder agar IconButton bisa mengakses Scaffold milik MainShell (induknya)
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF6B4EFF)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF6B4EFF),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6B4EFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6B4EFF),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          return TabBarView(
            controller: _tabController,
            children: [
              _PhotoGrid(photos: state.photos.toList()),
              _PhotoGrid(photos: state.favoritePhotos),
              _PhotoGrid(photos: state.todayPhotos),
              _PhotoGrid(photos: state.thisWeekPhotos),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<PhotoItem> photos;

  const _PhotoGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 64, color: Color(0xFFB39DFF)),
            SizedBox(height: 12),
            Text(
              'Belum ada foto',
              style: TextStyle(color: Colors.grey),
            ),
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
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreviewScreen(photoPath: photo.path),
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEDE9FF),
                    child: const Icon(Icons.broken_image,
                        color: Color(0xFFB39DFF)),
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
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.favorite,
                        color: Colors.pinkAccent, size: 14),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
