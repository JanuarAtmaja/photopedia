import 'package:flutter/material.dart';
import '../models/photo_state.dart';
import '../widgets/photo_grid_item.dart';
import 'preview_screen.dart';
import '../main.dart'; // Import main.dart

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photopedia'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6B4EFF).withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FF), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.camera_enhance_rounded, size: 40, color: Color(0xFF6B4EFF)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PHOTOPEDIA',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6B4EFF), letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Photobooth seru yang bikin momen kamu jadi lebih hidup dan estetik. Akses kamera dan galeri dengan cepat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToTab(context, 1),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Mulai Ambil Foto'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _navigateToTab(context, 2),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6B4EFF)),
                          foregroundColor: const Color(0xFF6B4EFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Lihat Galeri'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: state,
                builder: (context, _) {
                  if (state.photos.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Foto Terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
                          TextButton(
                            onPressed: () => _navigateToTab(context, 2),
                            child: const Text('Lihat Semua', style: TextStyle(color: Color(0xFF6B4EFF))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: state.photos.length > 6 ? 6 : state.photos.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PreviewScreen(photoPath: state.photos[index].path)),
                            ),
                            child: PhotoGridItem(photo: state.photos[index]),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    final notifier = MainTabNotifier.of(context);
    notifier?.changeTab(index);
  }
}

class MainTabNotifier extends InheritedWidget {
  final void Function(int) changeTab;
  const MainTabNotifier({super.key, required this.changeTab, required super.child});
  static MainTabNotifier? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MainTabNotifier>();
  @override
  bool updateShouldNotify(MainTabNotifier old) => false;
}