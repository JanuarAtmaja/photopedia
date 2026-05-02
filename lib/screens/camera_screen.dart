import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/photo_state.dart';
import 'edit_photo_screen.dart';

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
  bool _showDragDrop = false;
  FlashMode _flashMode = FlashMode.off;

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
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera setup error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller!.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(dir.path, fileName);
      await File(photo.path).copy(savedPath);

      if (mounted) {
        final state = AppStateScope.of(context);
        state.addPhoto(savedPath);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditPhotoScreen(photoPath: savedPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(dir.path, fileName);
      await File(image.path).copy(savedPath);

      final state = AppStateScope.of(context);
      state.addPhoto(savedPath);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditPhotoScreen(photoPath: savedPath),
          ),
        );
        setState(() => _showDragDrop = false);
      }
    }
  }

  void _toggleFlash() {
    if (_controller == null) return;
    final next = _flashMode == FlashMode.off
        ? FlashMode.always
        : _flashMode == FlashMode.always
            ? FlashMode.auto
            : FlashMode.off;
    _controller!.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final current = _controller?.description;
    final next = _cameras.firstWhere((c) => c != current, orElse: () => _cameras.first);
    await _controller?.dispose();
    setState(() => _isInitialized = false);
    await _setupCamera(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'CAMERA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full Screen Camera Preview (Anti-Stretch Fix)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _isInitialized && _controller != null
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxWidth * _controller!.value.aspectRatio,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: _controller!.description.lensDirection ==
                                          CameraLensDirection.front
                                      ? Matrix4.rotationY(3.14159)
                                      : Matrix4.identity(),
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),

          // 2. UI Overlay (Transparent Controls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.only(bottom: 48, top: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter selection label
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Lihat Semua', style: TextStyle(color: Color(0xFFB39DFF), fontSize: 12)),
                      ],
                    ),
                  ),
                  // Filter chips row
                  SizedBox(
                    height: 80,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(label: 'Asli', color: Colors.grey.shade800, selected: true),
                        _FilterChip(label: 'B&W', color: Colors.grey.shade600),
                        _FilterChip(label: 'Blur', color: Colors.indigo.shade900),
                        _FilterChip(label: 'Warm', color: Colors.orange.shade700),
                        _FilterChip(label: 'Cool', color: Colors.blue.shade700),
                        _FilterChip(label: 'Vivid', color: Colors.purple.shade700),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        icon: Icons.upload_file_rounded,
                        onTap: () => setState(() => _showDragDrop = true),
                      ),
                      // Shutter
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: _isCapturing ? 40 : 68,
                              height: _isCapturing ? 40 : 68,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _ControlButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: _switchCamera,
                        color: const Color(0xFF6B4EFF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Flash button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: Icon(
                  _flashMode == FlashMode.off
                      ? Icons.flash_off
                      : _flashMode == FlashMode.always
                          ? Icons.flash_on
                          : Icons.flash_auto,
                  color: Colors.white,
                ),
                onPressed: _toggleFlash,
              ),
            ),
          ),

          // Drag & Drop modal
          if (_showDragDrop)
            _DragDropModal(
              onClose: () => setState(() => _showDragDrop = false),
              onPickFile: _pickFromGallery,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;

  const _FilterChip({
    required this.label,
    required this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: const Color(0xFF6B4EFF), width: 3)
                  : Border.all(color: Colors.white24, width: 1),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 10,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ControlButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _DragDropModal extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onPickFile;

  const _DragDropModal({required this.onClose, required this.onPickFile});

  @override
  State<_DragDropModal> createState() => _DragDropModalState();
}

class _DragDropModalState extends State<_DragDropModal> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.black54),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        setState(() => _isDragging = true);
                        return true;
                      },
                      onLeave: (_) => setState(() => _isDragging = false),
                      onAcceptWithDetails: (details) {
                        setState(() => _isDragging = false);
                        widget.onPickFile();
                      },
                      builder: (context, candidateData, rejectedData) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: _isDragging ? const Color(0xFFF0EEFF) : const Color(0xFFF8F8FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFB39DFF),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_upload_rounded, size: 56, color: Color(0xFF6B4EFF)),
                              const SizedBox(height: 16),
                              const Text('Pilih atau seret foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('Maksimal ukuran file 10MB', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onPickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B4EFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
