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
// FILTER MODEL
// ─────────────────────────────────────────────────────────────────────────────

class CameraFilter {
  final String id;
  final String label;
  final Color chipColor;
  final List<double> matrix;
  final img.Image Function(img.Image)? applyToImage;

  const CameraFilter({
    required this.id, required this.label,
    required this.chipColor, required this.matrix,
    this.applyToImage,
  });
}

final List<CameraFilter> kAppFilters = [
  const CameraFilter(id: 'none', label: 'Asli', chipColor: Colors.grey,
      matrix: [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0]),
  const CameraFilter(id: 'bw', label: 'B&W', chipColor: Colors.blueGrey,
      matrix: [0.21,0.71,0.07,0,0, 0.21,0.71,0.07,0,0, 0.21,0.71,0.07,0,0, 0,0,0,1,0],
      applyToImage: _applyBW),
  const CameraFilter(id: 'sepia', label: 'Sepia', chipColor: Colors.brown,
      matrix: [0.39,0.76,0.18,0,0, 0.34,0.68,0.16,0,0, 0.27,0.53,0.13,0,0, 0,0,0,1,0],
      applyToImage: _applySepia),
  const CameraFilter(id: 'invert', label: 'Invert', chipColor: Colors.teal,
      matrix: [-1,0,0,0,255, 0,-1,0,0,255, 0,0,-1,0,255, 0,0,0,1,0],
      applyToImage: _applyInvert),
  const CameraFilter(id: 'vintage', label: 'Vintage', chipColor: Colors.orange,
      matrix: [0.9,0.5,0.1,0,0, 0.3,0.8,0.1,0,0, 0.2,0.3,0.5,0,0, 0,0,0,1,0],
      applyToImage: _applyVintage),
];

img.Image _applyBW(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final g = (px.r * 0.21 + px.g * 0.71 + px.b * 0.07).clamp(0, 255).toInt();
      out.setPixelRgba(x, y, g, g, g, px.a.toInt());
    }
  }
  return out;
}

img.Image _applySepia(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toInt(); final g = px.g.toInt(); final b = px.b.toInt();
      out.setPixelRgba(x, y,
        (r*0.39+g*0.76+b*0.18).clamp(0,255).toInt(),
        (r*0.34+g*0.68+b*0.16).clamp(0,255).toInt(),
        (r*0.27+g*0.53+b*0.13).clamp(0,255).toInt(), px.a.toInt());
    }
  }
  return out;
}

img.Image _applyInvert(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      out.setPixelRgba(x, y, 255-px.r.toInt(), 255-px.g.toInt(), 255-px.b.toInt(), px.a.toInt());
    }
  }
  return out;
}

img.Image _applyVintage(img.Image src) {
  final out = img.Image(width: src.width, height: src.height);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toDouble(); final g = px.g.toDouble(); final b = px.b.toDouble();
      out.setPixelRgba(x, y,
        (r*0.9+g*0.5+b*0.1).clamp(0,255).toInt(),
        (r*0.3+g*0.8+b*0.1).clamp(0,255).toInt(),
        (r*0.2+g*0.3+b*0.5).clamp(0,255).toInt(), px.a.toInt());
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMERA SCREEN
// ─────────────────────────────────────────────────────────────────────────────

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
  final List<String> _capturedPaths = [];
  bool _mirrorFront = true;
  bool _showCuttingFrame = true;
  int _photoCount = 3;

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
    } catch (e) { debugPrint('Camera init: $e'); }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _isInitialized = false);
    await old?.dispose();
    final controller = CameraController(camera, ResolutionPreset.medium,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) { debugPrint('Camera setup: $e'); }
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

  Future<void> _takePicture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isCapturing) return;
    if (_capturedPaths.length >= _photoCount) return;
    setState(() => _isCapturing = true);
    try {
      final XFile xfile = await ctrl.takePicture();
      final rawBytes = await xfile.readAsBytes();
      // Simpan foto RAW (hanya mirror jika kamera depan) — filter TIDAK di-bake.
      // Edit screen akan apply filter dari raw bytes agar user bisa ganti bebas.
      final processedBytes = await _processImageBytes(rawBytes,
          filter: kAppFilters.first, mirror: _isFrontCamera);
      final dir = await getApplicationDocumentsDirectory();
      final savedPath = p.join(dir.path, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(savedPath).writeAsBytes(processedBytes);
      setState(() => _capturedPaths.add(savedPath));
      HapticFeedback.mediumImpact();
      if (_capturedPaths.length >= _photoCount) {
        if (!mounted) return;
        final state = AppStateScope.of(context);
        final navigator = Navigator.of(context);
        for (final path in _capturedPaths) {
          await state.addPhoto(path);
          if (!mounted) return;
        }
        navigator.push(MaterialPageRoute(
          builder: (_) => EditPhotoScreen(
            photoPaths: List.from(_capturedPaths),
            // kirim filter aktif agar chip di edit screen terpilih & langsung apply
            initialFilterId: _activeFilter.id,
            filterAlreadyBaked: false,
          ),
        )).then((_) {
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

  void _removeLastPhoto() {
    if (_capturedPaths.isEmpty) return;
    setState(() => _capturedPaths.removeLast());
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> picked = await ImagePicker().pickMultiImage(
          imageQuality: 90, limit: _photoCount);
      if (picked.isEmpty || !mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final List<String> paths = [];
      for (final xfile in picked.take(_photoCount)) {
        final savedPath = p.join(dir.path,
            'photo_${DateTime.now().millisecondsSinceEpoch}_${paths.length}.jpg');
        await File(xfile.path).copy(savedPath);
        paths.add(savedPath);
      }
      if (!mounted) return;
      final state = AppStateScope.of(context);
      final navigator = Navigator.of(context);
      for (final path in paths) {
        await state.addPhoto(path);
        if (!mounted) return;
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => EditPhotoScreen(photoPaths: paths, initialFilterId: 'none'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        title: const Text('KAMERA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          if (_showCuttingFrame) Positioned.fill(child: _buildCuttingFrameOverlay()),
          // Thumbnail strip pojok kiri — di bawah AppBar
          Positioned(top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
              left: 8, child: _buildCapturedStrip()),
          // Controls panel bawah
          Positioned(bottom: 0, left: 0, right: 0,
              child: _buildControls(isDark)),
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
    if (_isFrontCamera && _mirrorFront) {
      preview = Transform.scale(scaleX: -1.0, child: preview);
    }
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(_activeFilter.matrix),
      child: preview,
    );
  }

  Widget _buildCuttingFrameOverlay() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final W = constraints.maxWidth;
      final H = constraints.maxHeight;
      final boxW = W * 0.55;
      final boxH = H * 0.38;
      final boxLeft = (W - boxW) / 2;
      final boxTop = (H - boxH) / 2 - H * 0.04;
      return Stack(children: [
        Positioned(
          left: boxLeft, top: boxTop, width: boxW, height: boxH,
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5B62B3), width: 2.5)),
            child: Stack(children: [
              Positioned(
                top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B62B3).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Posisikan wajah di sini',
                      style: TextStyle(color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              _cornerBracket(Alignment.topLeft),
              _cornerBracket(Alignment.topRight),
              _cornerBracket(Alignment.bottomLeft),
              _cornerBracket(Alignment.bottomRight),
            ]),
          ),
        ),
      ]);
    });
  }

  Widget _cornerBracket(Alignment alignment) {
    const size = 16.0;
    const thick = 3.0;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop  = alignment == Alignment.topLeft  || alignment == Alignment.topRight;
    return Align(
      alignment: alignment,
      child: SizedBox(width: size, height: size,
        child: CustomPaint(painter: _CornerPainter(
            isLeft: isLeft, isTop: isTop, thickness: thick))),
    );
  }

  Widget _buildCapturedStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot progress
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_photoCount, (i) {
              final taken = i < _capturedPaths.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8, height: 8,
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
          const SizedBox(height: 6),
          for (int i = 0; i < _capturedPaths.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF5B62B3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(_capturedPaths[i]),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, color: Colors.white54)),
              ),
            ),
          GestureDetector(
            onTap: _removeLastPhoto,
            child: Container(
              width: 48, height: 24,
              decoration: BoxDecoration(
                  color: Colors.red.shade700.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.undo_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControls(bool isDark) {
    final remaining = _photoCount - _capturedPaths.length;
    final allTaken = remaining == 0;

    return Container(
      // Solid semi-transparan agar tidak tembus ke konten di atasnya
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12, left: 12, right: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.92), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Filter chips ───────────────────────────────────────
          SizedBox(
            height: 72,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: kAppFilters.map((f) {
                final selected = _activeFilter.id == f.id;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: f.chipColor,
                            borderRadius: BorderRadius.circular(10),
                            border: selected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                            boxShadow: selected
                                ? [BoxShadow(color: f.chipColor.withValues(alpha: 0.6),
                                    blurRadius: 6)]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(f.label, style: TextStyle(
                          color: selected ? Colors.white : Colors.white60,
                          fontSize: 9,
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

          const SizedBox(height: 8),

          // ── Row 2: Jumlah foto + label ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Toggle 1/3 foto — hanya tampil sebelum mulai ambil foto
              if (_capturedPaths.isEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _PhotoCountChip(label: '1 Foto', selected: _photoCount == 1,
                      onTap: () => setState(() => _photoCount = 1)),
                  const SizedBox(width: 6),
                  _PhotoCountChip(label: '3 Foto', selected: _photoCount == 3,
                      onTap: () => setState(() => _photoCount = 3)),
                ])
              else
                const SizedBox.shrink(),

              // Label progress
              Text(
                allTaken ? 'Siap!' : 'Foto ${_capturedPaths.length + 1} / $_photoCount',
                style: TextStyle(
                  color: allTaken ? const Color(0xFF5B62B3) : Colors.white70,
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Row 3: Tombol aksi ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Kiri: galeri + frame-guide
              Column(mainAxisSize: MainAxisSize.min, children: [
                _CamButton(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
                const SizedBox(height: 8),
                _CamButton(
                  icon: _showCuttingFrame ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                  onTap: () => setState(() => _showCuttingFrame = !_showCuttingFrame),
                ),
              ]),

              // Tengah: shutter
              GestureDetector(
                onTap: (_isCapturing || allTaken) ? null : _takePicture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: _isCapturing ? 68 : 76,
                  height: _isCapturing ? 68 : 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allTaken ? const Color(0xFF5B62B3) : Colors.white,
                      width: 3.5,
                    ),
                    color: allTaken
                        ? const Color(0xFF5B62B3).withValues(alpha: 0.25)
                        : Colors.transparent,
                  ),
                  child: _isCapturing
                      ? const Padding(padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
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

              // Kanan: switch + mirror
              Column(mainAxisSize: MainAxisSize.min, children: [
                _CamButton(icon: Icons.cameraswitch_rounded, onTap: _switchCamera),
                const SizedBox(height: 8),
                _isFrontCamera
                    ? _CamButton(
                        icon: _mirrorFront ? Icons.flip_rounded : Icons.flip_outlined,
                        onTap: () => setState(() => _mirrorFront = !_mirrorFront))
                    : const SizedBox(width: 44, height: 44),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Widgets kamera ───────────────────────────────────────────────────────────

class _CamButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CamButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isLeft, isTop;
  final double thickness;
  const _CornerPainter({required this.isLeft, required this.isTop,
      required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white ..strokeWidth = thickness
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.square;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop  ? 0.0 : size.height;
    canvas.drawLine(Offset(x, y), Offset(x + (isLeft ? size.width : -size.width), y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + (isTop ? size.height : -size.height)), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _PhotoCountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PhotoCountChip({required this.label, required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5B62B3)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF5B62B3) : Colors.white38,
            width: 1.5,
          ),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 11,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }
}
