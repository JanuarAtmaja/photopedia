import 'package:flutter/material.dart';
import '../models/photo_state.dart';
import '../widgets/photo_grid_item.dart';
import 'preview_screen.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isDark = ThemeModeScope.of(context);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photopedia'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero section: HANYA tampil jika belum ada foto ──
                  if (state.photos.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: isDark
                            ? [kSurfaceDark, const Color(0xFF252542)]
                            : [Colors.white, const Color(0xFFF0EEFF)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                            blurRadius: 24, offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kPrimary.withValues(alpha: 0.15), kAccent.withValues(alpha: 0.10)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.camera_enhance_rounded, size: 36, color: kPrimary),
                          ),
                          const SizedBox(height: 20),
                          const Text('PHOTOPEDIA',
                            style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: kPrimary, letterSpacing: 1.5,
                            )),
                          const SizedBox(height: 12),
                          Text(
                            'Photobooth seru yang bikin momen kamu\njadi lebih hidup dan estetik.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: subColor, height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToTab(context, 1),
                              icon: const Icon(Icons.camera_alt_rounded, size: 20),
                              label: const Text('Mulai Ambil Foto'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _navigateToTab(context, 2),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: kPrimary, width: 1.5),
                                foregroundColor: kPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Lihat Galeri'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Foto terbaru: tampil jika ada foto ──────────────
                  if (state.photos.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Foto Terbaru', style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
                        TextButton(
                          onPressed: () => _navigateToTab(context, 2),
                          child: const Text('Lihat Semua',
                            style: TextStyle(color: kPrimary, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                      ),
                      itemCount: state.photos.length > 6 ? 6 : state.photos.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => PreviewScreen(photoPaths: [state.photos[index].path]))),
                          child: PhotoGridItem(photo: state.photos[index]),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    final notifier = MainTabNotifier.maybeOf(context);
    notifier?.changeTab(index);
  }
}
