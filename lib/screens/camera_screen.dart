import 'dart:io';
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

// ─────────────────────────────────────────────────────────────────────────────
// FILTER MODEL (dipakai juga oleh EditPhotoScreen)
// ─────────────────────────────────────────────────────────────────────────────

class CameraFilter {
  final String id;
  final String label;
  final Color chipColor;
  final List<double> matrix;
  final img.Image Function(img.Image)? applyToImage;

  const CameraFilter({
    required this.id,
    required this.label,
    required this.chipColor,
    required this.matrix,
    this.applyToImage,
  });
}

final List<CameraFilter> kAppFilters = [
  const CameraFilter(
    id: 'none', label: 'Asli', chipColor: Colors.grey,
    matrix: [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0],
  ),
  const CameraFilter(
    id: 'bw', label: 'B&W', chipColor: Colors.blueGrey,
    matrix: [0.21,0.71,0.07,0,0, 0.21,0.71,0.07,0,0, 0.21,0.71,0.07,0,0, 0,0,0,1,0],
    applyToImage: _applyBW,
  ),
  const CameraFilter(
    id: 'sepia', label: 'Sepia', chipColor: Colors.brown,
    matrix: [0.39,0.76,0.18,0,0, 0.34,0.68,0.16,0,0, 0.27,0.53,0.13,0,0, 0,0,0,1,0],
    applyToImage: _applySepia,
  ),
  const CameraFilter(
    id: 'invert', label: 'Invert', chipColor: Colors.teal,
    matrix: [-1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0],
    applyToImage: _applyInvert,
  ),
  const CameraFilter(
    id: 'vintage', label: 'Vintage', chipColor: Colors.orange,
    matrix: [0.9,0.5,0.1,0,0, 0.3,0.8,0.1,0,0, 0.2,0.3,0.5,0,0, 0,0,0,1,0],
    applyToImage: _applyVintage,
  ),
];

img.Image _applyBW(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++)
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final g = (px.r * 0.21 + px.g * 0.71 + px.b * 0.07).clamp(0,255).toInt();
      out.setPixelRgba(x, y, g, g, g, px.a.toInt());
    }
  return out;
}

img.Image _applySepia(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++)
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toInt(); final g = px.g.toInt(); final b = px.b.toInt();
      out.setPixelRgba(x, y,
        (r*0.39+g*0.76+b*0.18).clamp(0,255).toInt(),
        (r*0.34+g*0.68+b*0.16).clamp(0,255).toInt(),
        (r*0.27+g*0.53+b*0.13).clamp(0,255).toInt(),
        px.a.toInt());
    }
  return out;
}

img.Image _applyInvert(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++)
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      out.setPixelRgba(x, y, 255-px.r.toInt(), 255-px.g.toInt(), 255-px.b.toInt(), px.a.toInt());
    }
  return out;
}

img.Image _applyVintage(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++)
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toDouble(); final g = px.g.toDouble(); final b = px.b.toDouble();
      out.setPixelRgba(x, y,
        (r*0.9+g*0.5+b*0.1).clamp(0,255).toInt(),
        (r*0.3+g*0.8+b*0.1).clamp(0,255).toInt(),
        (r*0.2+g*0.3+b*0.5).clamp(0,255).toInt(),
        px.a.toInt());
    }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA SCREEN — tangkap 3 foto, lalu lanjut ke edit overlay
// ─────────────────────────────────────────────────────────────────────────────

const int kRequiredPhotos = 3;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  CameraFilter _activeFilter = kAppFilters[0];

  // Daftar path foto yang sudah diambil (max 3)
  final List<String> _capturedPaths = [];

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
    } catch (e) { debugPrint('Camera init error: $e'); }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _isInitialized = false);
    await old?.dispose();

    final controller = CameraController(
      camera, ResolutionPreset.medium,
      enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) { debugPrint('Camera setup error: $e'); }
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

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _controller == null) return;
    final currentLens = _controller!.description.lensDirection;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != currentLens, orElse: () => _cameras.first);
    await _setupCamera(next);
  }

  bool get _isFrontCamera =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  // Ambil 1 foto → simpan ke list. Kalau sudah 3, lanjut ke edit.
  Future<void> _takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;
    if (_capturedPaths.length >= kRequiredPhotos) return;

    setState(() => _isCapturing = true);
    try {
      final XFile xfile = await ctrl.takePicture();
      final rawBytes = await xfile.readAsBytes();
      final processedBytes = await _processImageBytes(
        rawBytes, filter: _activeFilter, mirror: _isFrontCamera);

      final dir = await getApplicationDocumentsDirectory();
      final savedPath = p.join(
          dir.path, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(savedPath).writeAsBytes(processedBytes);

      setState(() => _capturedPaths.add(savedPath));

      // Feedback haptic tiap foto
      HapticFeedback.mediumImpact();

      // Kalau sudah 3 foto, langsung navigasi ke EditPhotoScreen
      if (_capturedPaths.length >= kRequiredPhotos) {
        if (!mounted) return;
        // Simpan semua ke state dulu
        final state = AppStateScope.of(context);
        for (final path in _capturedPaths) {
          await state.addPhoto(path);
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditPhotoScreen(
              photoPaths: List.from(_capturedPaths),
              initialFilterId: _activeFilter.id,
            ),
          ),
        ).then((_) {
          // Setelah kembali dari edit, reset supaya bisa ambil 3 foto baru
          if (mounted) setState(() => _capturedPaths.clear());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  static Future<Uint8List> _processImageBytes(Uint8List rawBytes,
      {required CameraFilter filter, required bool mirror}) async {
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) return rawBytes;
    if (mirror) image = img.flipHorizontal(image);
    if (filter.applyToImage != null) image = filter.applyToImage!(image);
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  // Hapus foto terakhir dari list
  void _removeLastPhoto() {
    if (_capturedPaths.isEmpty) return;
    setState(() => _capturedPaths.removeLast());
  }

  // Pilih dari galeri — langsung masuk ke EditPhotoScreen sebagai 1 foto
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> picked = await ImagePicker().pickMultiImage(
        imageQuality: 90, limit: kRequiredPhotos);
      if (picked.isEmpty || !mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final List<String> paths = [];
      for (final xfile in picked.take(kRequiredPhotos)) {
        final savedPath = p.join(
            dir.path, 'photo_${DateTime.now().millisecondsSinceEpoch}_${paths.length}.jpg');
        await File(xfile.path).copy(savedPath);
        paths.add(savedPath);
      }

      if (!mounted) return;
      final state = AppStateScope.of(context);
      for (final path in paths) await state.addPhoto(path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditPhotoScreen(photoPaths: paths),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('CAMERA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          // Strip thumbnail foto yang sudah diambil
          Positioned(top: 100, left: 12, child: _buildCapturedStrip()),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildControls()),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final ctrl = _controller!;
    Widget preview = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.previewSize?.height ?? 480,
          height: ctrl.value.previewSize?.width ?? 640,
          child: CameraPreview(ctrl),
        ),
      ),
    );
    if (_isFrontCamera) {
      preview = Transform.scale(scaleX: -1.0, child: preview);
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_activeFilter.matrix),
      child: preview,
    );
  }

  // Strip kecil di pojok kiri atas yang menampilkan foto-foto yang sudah diambil
  Widget _buildCapturedStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indikator progress
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(kRequiredPhotos, (i) {
              final taken = i < _capturedPaths.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: taken ? const Color(0xFF5B62B3) : Colors.white38,
                  border: Border.all(color: Colors.white54, width: 1),
                ),
              );
            }),
          ),
        ),
        if (_capturedPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Thumbnail foto yang sudah diambil
          for (int i = 0; i < _capturedPaths.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: 52, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5B62B3), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(_capturedPaths[i]),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image, color: Colors.white54),
                ),
              ),
            ),
          // Tombol hapus foto terakhir
          GestureDetector(
            onTap: _removeLastPhoto,
            child: Container(
              width: 52, height: 26,
              decoration: BoxDecoration(
                color: Colors.red.shade700.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.undo_rounded, color: Colors.white, size: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControls() {
    final remaining = kRequiredPhotos - _capturedPaths.length;
    final allTaken = remaining == 0;

    return Container(
      padding: const EdgeInsets.only(bottom: 48, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filter chips
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: kAppFilters.map((f) {
                  final selected = _activeFilter.id == f.id;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: f.chipColor,
                              borderRadius: BorderRadius.circular(12),
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [BoxShadow(
                                      color: f.chipColor.withValues(alpha: 0.6),
                                      blurRadius: 8)]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(f.label,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Label sisa foto
          Text(
            allTaken
                ? 'Semua foto sudah diambil!'
                : 'Foto ${_capturedPaths.length + 1} dari $kRequiredPhotos',
            style: TextStyle(
              color: allTaken ? const Color(0xFF5B62B3) : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CamButton(
                icon: Icons.photo_library_rounded,
                onTap: _pickFromGallery,
              ),
              // Tombol shutter — nonaktif kalau sudah 3 foto
              GestureDetector(
                onTap: (_isCapturing || allTaken) ? null : _takePicture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _isCapturing ? 72 : 80,
                  height: _isCapturing ? 72 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allTaken ? const Color(0xFF5B62B3) : Colors.white,
                      width: 4,
                    ),
                    color: allTaken
                        ? const Color(0xFF5B62B3).withValues(alpha: 0.3)
                        : _isCapturing
                            ? Colors.white30
                            : Colors.transparent,
                  ),
                  child: _isCapturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: allTaken
                                ? const Color(0xFF5B62B3)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
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
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
