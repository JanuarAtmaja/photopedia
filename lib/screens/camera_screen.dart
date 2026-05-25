import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/photo_state.dart';
import '../main.dart';
import 'edit_photo_screen.dart';

// ─── Definisi Filter (single source of truth) ─────────────────────────────────
// Dipakai baik di live preview kamera maupun di edit_photo_screen.dart
// sehingga filter yang dilihat saat preview = filter yang dihasilkan foto.
class CameraFilter {
  final String id;
  final String label;
  final Color chipColor;

  // Matrix 5×4 untuk ColorFilter.matrix() (live preview)
  final List<double> matrix;

  // Fungsi yang sama diterapkan ke img.Image saat bake-in filter ke file foto
  final img.Image Function(img.Image)? applyToImage;

  const CameraFilter({
    required this.id,
    required this.label,
    required this.chipColor,
    required this.matrix,
    this.applyToImage,
  });
}

/// Daftar filter — satu definisi, dipakai di kamera & editor.
final List<CameraFilter> kAppFilters = [
  const CameraFilter(
    id: 'none',
    label: 'Asli',
    chipColor: Colors.grey,
    matrix: [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    applyToImage: null,
  ),
  const CameraFilter(
    id: 'bw',
    label: 'B&W',
    chipColor: Colors.blueGrey,
    matrix: [
      0.21, 0.71, 0.07, 0, 0,
      0.21, 0.71, 0.07, 0, 0,
      0.21, 0.71, 0.07, 0, 0,
      0, 0, 0, 1, 0,
    ],
    applyToImage: _applyBW,
  ),
  const CameraFilter(
    id: 'sepia',
    label: 'Sepia',
    chipColor: Colors.brown,
    matrix: [
      0.39, 0.76, 0.18, 0, 0,
      0.34, 0.68, 0.16, 0, 0,
      0.27, 0.53, 0.13, 0, 0,
      0, 0, 0, 1, 0,
    ],
    applyToImage: _applySepia,
  ),
  const CameraFilter(
    id: 'invert',
    label: 'Invert',
    chipColor: Colors.teal,
    matrix: [
      -1, 0, 0, 0, 255,
       0,-1, 0, 0, 255,
       0, 0,-1, 0, 255,
       0, 0, 0, 1, 0,
    ],
    applyToImage: _applyInvert,
  ),
  const CameraFilter(
    id: 'vintage',
    label: 'Vintage',
    chipColor: Colors.orange,
    matrix: [
      0.9, 0.5, 0.1, 0, 0,
      0.3, 0.8, 0.1, 0, 0,
      0.2, 0.3, 0.5, 0, 0,
      0, 0, 0, 1, 0,
    ],
    applyToImage: _applyVintage,
  ),
];

// ─── Implementasi filter pada img.Image (bake-in) ──────────────────────────
img.Image _applyBW(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final gray =
          (px.r * 0.21 + px.g * 0.71 + px.b * 0.07).clamp(0, 255).toInt();
      out.setPixelRgba(x, y, gray, gray, gray, px.a.toInt());
    }
  }
  return out;
}

img.Image _applySepia(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
      out.setPixelRgba(
        x, y,
        (r * 0.39 + g * 0.76 + b * 0.18).clamp(0, 255).toInt(),
        (r * 0.34 + g * 0.68 + b * 0.16).clamp(0, 255).toInt(),
        (r * 0.27 + g * 0.53 + b * 0.13).clamp(0, 255).toInt(),
        px.a.toInt(),
      );
    }
  }
  return out;
}

img.Image _applyInvert(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      out.setPixelRgba(
          x, y, 255 - px.r.toInt(), 255 - px.g.toInt(), 255 - px.b.toInt(), px.a.toInt());
    }
  }
  return out;
}

img.Image _applyVintage(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toDouble(), g = px.g.toDouble(), b = px.b.toDouble();
      out.setPixelRgba(
        x, y,
        (r * 0.9 + g * 0.5 + b * 0.1).clamp(0, 255).toInt(),
        (r * 0.3 + g * 0.8 + b * 0.1).clamp(0, 255).toInt(),
        (r * 0.2 + g * 0.3 + b * 0.5).clamp(0, 255).toInt(),
        px.a.toInt(),
      );
    }
  }
  return out;
}

// ─── CameraScreen ──────────────────────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _showPicker = false;

  // Filter aktif — mulai dari "Asli"
  CameraFilter _activeFilter = kAppFilters[0];

  // ─── Inisialisasi ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _setupCamera(_cameras.first);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    // Tutup controller lama jika ada
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _isInitialized = false);
    await old?.dispose();

    // Performa: gunakan medium agar preview tidak terlalu berat
    // takePicture() tetap menghasilkan resolusi max dari sensor
    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // ← turun dari high → ringan di UI
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;
    try {
      await controller.initialize();
      // Kunci orientasi agar tidak rotate saat diputar
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(ctrl.description);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // ─── Logika switch kamera ─────────────────────────────────────────────────

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return;
    final currentLens = _controller!.description.lensDirection;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != currentLens,
      orElse: () => _cameras.first,
    );
    await _setupCamera(next);
  }

  bool get _isFrontCamera =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  // ─── Pengambilan gambar + bake-in filter + mirror selfie ─────────────────

  Future<void> _takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final XFile xfile = await ctrl.takePicture();
      final rawBytes = await xfile.readAsBytes();

      // Proses di isolate agar UI tidak freeze
      final processedBytes = await _processImageBytes(
        rawBytes,
        filter: _activeFilter,
        mirror: _isFrontCamera, // ← mirror jika selfie
      );

      final dir = await getApplicationDocumentsDirectory();
      final savedPath = p.join(
          dir.path, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(savedPath).writeAsBytes(processedBytes);

      if (!mounted) return;
      await AppStateScope.of(context).addPhoto(savedPath);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditPhotoScreen(
            photoPath: savedPath,
            initialFilterId: _activeFilter.id, // ← kirim filter yang aktif
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Proses bytes gambar: decode → mirror (selfie) → apply filter → encode
  static Future<Uint8List> _processImageBytes(
    Uint8List rawBytes, {
    required CameraFilter filter,
    required bool mirror,
  }) async {
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) return rawBytes;

    // FIX MIRRORING SELFIE:
    // Kamera depan Android biasanya tidak mirror hasil file-nya.
    // Kita flip secara horizontal agar hasil = apa yang pengguna lihat.
    if (mirror) {
      image = img.flipHorizontal(image);
    }

    // FIX KONSISTENSI FILTER:
    // Terapkan filter yang sama dengan yang ditampilkan di live preview.
    if (filter.applyToImage != null) {
      image = filter.applyToImage!(image);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  // ─── Upload dari galeri ────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    setState(() => _showPicker = false);
    try {
      final XFile? picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final savedPath = p.join(
          dir.path, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(picked.path).copy(savedPath);

      if (!mounted) return;
      await AppStateScope.of(context).addPhoto(savedPath);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EditPhotoScreen(photoPath: savedPath)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memilih foto: $e')));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('CAMERA',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () =>
              MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Stack(
        children: [
          // ─── Viewport kamera ──────────────────────────────────────────
          Positioned.fill(child: _buildCameraPreview()),

          // ─── Panel kontrol bawah ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),

          // ─── Overlay picker galeri ────────────────────────────────────
          if (_showPicker) _buildPickerModal(),
        ],
      ),
    );
  }

  // ─── FIX ASPECT RATIO ────────────────────────────────────────────────────
  // Masalah: CameraPreview tanpa wrapper aspect ratio akan stretch
  // mengisi container induknya sehingga tampak gepeng.
  // Solusi: Bungkus CameraPreview dengan AspectRatio menggunakan nilai
  // controller.value.aspectRatio agar proporsional, lalu Center agar
  // tidak ada distorsi di layar manapun.
  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final ctrl = _controller!;

    // Rasio asli sensor kamera (misal 4:3 atau 16:9)
    final camAspect = ctrl.value.aspectRatio;

    Widget preview = AspectRatio(
      aspectRatio: camAspect,
      child: CameraPreview(ctrl),
    );

    // FIX MIRRORING SELFIE di live preview:
    // Bungkus dengan Transform.scale(scaleX: -1) agar layar menampilkan
    // gambar seperti cermin, sesuai ekspektasi pengguna selfie.
    if (_isFrontCamera) {
      preview = Transform.scale(
        scaleX: -1, // flip horizontal
        child: preview,
      );
    }

    // Terapkan filter real-time via ColorFilter.matrix
    Widget filtered = ColorFiltered(
      colorFilter: ColorFilter.matrix(_activeFilter.matrix),
      child: preview,
    );

    // Gunakan OverflowBox + Center agar mengisi layar penuh
    // tanpa stretch — mirip object-fit: cover di CSS.
    return LayoutBuilder(builder: (context, constraints) {
      final screenAspect = constraints.maxWidth / constraints.maxHeight;
      double scale;
      if (camAspect > screenAspect) {
        // Kamera lebih lebar → scale berdasarkan tinggi
        scale = constraints.maxHeight / (constraints.maxWidth / camAspect);
      } else {
        // Kamera lebih tinggi → scale berdasarkan lebar
        scale = constraints.maxWidth / (constraints.maxHeight * camAspect);
      }
      return ClipRect(
        child: OverflowBox(
          maxWidth: constraints.maxWidth * scale,
          maxHeight: constraints.maxHeight * scale,
          child: filtered,
        ),
      );
    });
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 48, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Filter chips ──────────────────────────────────────────
          SizedBox(
            height: 82,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // itemExtent agar ListView tidak rebuild semua item
              itemExtent: 66,
              itemCount: kAppFilters.length,
              itemBuilder: (_, i) {
                final f = kAppFilters[i];
                final selected = _activeFilter.id == f.id;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: f.chipColor,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(
                                    color: Colors.white, width: 3)
                                : null,
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: f.chipColor
                                            .withValues(alpha: 0.6),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f.label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // ─── Tombol kontrol kamera ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Galeri
              _CamButton(
                icon: Icons.photo_library_rounded,
                onTap: () => setState(() => _showPicker = true),
              ),

              // Shutter
              GestureDetector(
                onTap: _isCapturing ? null : _takePicture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _isCapturing ? 72 : 80,
                  height: _isCapturing ? 72 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing
                        ? Colors.white30
                        : Colors.transparent,
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : Container(
                          margin: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle),
                        ),
                ),
              ),

              // Switch kamera
              _CamButton(
                icon: Icons.cameraswitch_rounded,
                onTap: _switchCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerModal() {
    return GestureDetector(
      onTap: () => setState(() => _showPicker = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // block tap through
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 48, color: Color(0xFF6B4EFF)),
                  const SizedBox(height: 12),
                  const Text('Pilih dari Galeri',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text('Format: JPG, PNG, WEBP',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Buka Galeri'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _showPicker = false),
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CamButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CamButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
