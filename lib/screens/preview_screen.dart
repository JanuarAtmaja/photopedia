import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/photo_state.dart';
import '../main.dart';
import 'email_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DEFINISI BINGKAI & SLOT
// ─────────────────────────────────────────────────────────────────────────────

class FrameSlot {
  final double leftFrac;
  final double topFrac;
  final double widthFrac;
  final double heightFrac;
  const FrameSlot(this.leftFrac, this.topFrac, this.widthFrac, this.heightFrac);
}

class FrameOption {
  final String id;
  final String label;
  final String? assetPath;
  final Color accent;
  final List<FrameSlot>? slots;
  final double frameAspectRatio;

  const FrameOption({
    required this.id,
    required this.label,
    required this.accent,
    this.assetPath,
    this.slots,
    this.frameAspectRatio = 290.0 / 860.0,
  });
}

const _slotsFilmStrip = [
  FrameSlot(0.055, 0.037, 0.890, 0.230),
  FrameSlot(0.055, 0.287, 0.890, 0.230),
  FrameSlot(0.055, 0.535, 0.890, 0.230),
];

const _slotsY2K = [
  FrameSlot(0.055, 0.037, 0.890, 0.230),
  FrameSlot(0.055, 0.287, 0.890, 0.230),
  FrameSlot(0.055, 0.535, 0.890, 0.230),
];

const _slotsMusic = [
  FrameSlot(0.055, 0.037, 0.890, 0.230),
  FrameSlot(0.055, 0.287, 0.890, 0.230),
  FrameSlot(0.055, 0.535, 0.890, 0.230),
];

final List<FrameOption> kFrames = [
  const FrameOption(id: 'none', label: 'Tanpa\nBingkai', accent: Colors.grey),
  const FrameOption(
    id: 'frame1',
    label: 'Film\nStrip',
    accent: Color(0xFF2D2D2D),
    assetPath: 'assets/frames/Frame_1.png',
    slots: _slotsFilmStrip,
    frameAspectRatio: 290.0 / 860.0,
  ),
  const FrameOption(
    id: 'frame2',
    label: 'Y2K\nVibes',
    accent: Color(0xFF5B62B3),
    assetPath: 'assets/frames/Frame_2.png',
    slots: _slotsY2K,
    frameAspectRatio: 290.0 / 860.0,
  ),
  const FrameOption(
    id: 'frame3',
    label: 'Music\nPlayer',
    accent: Color(0xFF7CB518),
    assetPath: 'assets/frames/Frame_3.png',
    slots: _slotsMusic,
    frameAspectRatio: 290.0 / 860.0,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PreviewScreen extends StatefulWidget {
  /// Bisa berisi 1–3 path foto. Slot frame diisi otomatis sesuai urutan.
  final List<String> photoPaths;

  const PreviewScreen({
    super.key,
    required this.photoPaths,
    // Backward compat: jika ada code lama yang pakai photoPath tunggal
    String? photoPath,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  FrameOption _selectedFrame = kFrames.first;
  final List<String?> _slotPaths = [null, null, null];
  bool _isSaving = false;
  bool _isCapturingFrame = false; // sembunyikan tombol UI saat capture
  final GlobalKey _renderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Isi slot sesuai photoPaths yang dikirim dari EditPhotoScreen
    for (int i = 0; i < widget.photoPaths.length && i < 3; i++) {
      _slotPaths[i] = widget.photoPaths[i];
    }
    // Jika ada frame, pilih frame pertama yang bukan 'none' supaya langsung terlihat
    if (widget.photoPaths.length > 1 && kFrames.length > 1) {
      _selectedFrame = kFrames[1]; // Film Strip
    }
  }

  String _getFileSize() {
    try {
      final path = widget.photoPaths.isNotEmpty ? widget.photoPaths.first : '';
      if (path.isEmpty) return '-';
      final bytes = File(path).lengthSync();
      return bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _captureAndSendEmail() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _isCapturingFrame = true; });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary =
          _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(
          dir.path, 'email_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmailScreen(preSelectedPhotoPath: outPath),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal memproses foto: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; _isCapturingFrame = false; });
    }
  }

  Future<void> _saveResult() async {
    if (_isSaving) return;
    // Sembunyikan tombol UI dulu agar tidak ikut ter-capture
    setState(() { _isSaving = true; _isCapturingFrame = true; });
    // Tunggu satu frame agar widget rebuild tanpa tombol
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary =
          _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(
          dir.path, 'frame_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(bytes);

      if (!mounted) return;
      final state = AppStateScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await state.addPhoto(outPath);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Foto tersimpan di galeri ✓'),
          backgroundColor: Color(0xFF5B62B3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; _isCapturingFrame = false; });
    }
  }

  Future<void> _handleSlotTap(int slotIndex) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Foto ${slotIndex + 1}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF5B62B3)),
              title: const Text('Ambil foto baru'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final path = await _captureImage(ImageSource.camera);
                if (path != null && mounted) {
                  setState(() => _slotPaths[slotIndex] = path);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF5B62B3)),
              title: const Text('Pilih dari galeri'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final path = await _captureImage(ImageSource.gallery);
                if (path != null && mounted) {
                  setState(() => _slotPaths[slotIndex] = path);
                }
              },
            ),
            _buildSavedPhotoStrip(slotIndex, sheetCtx),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _captureImage(ImageSource source) async {
    try {
      final xfile = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (xfile == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'slot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(xfile.path).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSavedPhotoStrip(int slotIndex, BuildContext sheetCtx) {
    // FIX: capture photos from widget's own context (which has AppStateScope),
    // not sheetCtx which may not have it
    final photos = AppStateScope.of(context).photos;
    if (photos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text('Dari foto tersimpan:',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: photos.length,
            itemBuilder: (_, i) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _slotPaths[slotIndex] = photos[i].path);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD1E8)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(File(photos[i].path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    final hasFrame = _selectedFrame.id != 'none';

    return Scaffold(
      backgroundColor: const Color(0xFFEDE2E0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE2E0),
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          color: const Color(0xFF5B62B3),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF5B62B3),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: hasFrame
                  ? _buildFrameView()
                  : RepaintBoundary(
                      key: _renderKey,
                      child: _buildSingleView(),
                    ),
            ),
          ),
          _buildFrameSelector(),
          if (hasFrame)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Ketuk foto untuk ganti/hapus',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          _buildMetadata(timeStr),
          const SizedBox(height: 8),
          _buildActions(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Widget _buildSingleView() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B62B3).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(widget.photoPaths.isNotEmpty ? widget.photoPaths.first : ""),
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 64)),
        ),
      ),
    );
  }

  Widget _buildFrameView() {
    final slots = _selectedFrame.slots ?? _slotsFilmStrip;
    final ratio = _selectedFrame.frameAspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: LayoutBuilder(builder: (ctx, constraints) {
          final W = constraints.maxWidth;
          final H = constraints.maxHeight;

          return Stack(
            children: [
              // ── Konten yang akan di-capture (tanpa tombol UI) ──────────
              RepaintBoundary(
                key: _renderKey,
                child: Stack(
                  children: [
                    // Layer 0: background hitam
                    Positioned.fill(child: Container(color: Colors.black)),

                    // Layer 1: foto di slot
                    for (int i = 0; i < slots.length; i++)
                      Positioned(
                        left: slots[i].leftFrac * W,
                        top: slots[i].topFrac * H,
                        width: slots[i].widthFrac * W,
                        height: slots[i].heightFrac * H,
                        child: _slotPaths[i] != null
                            ? Image.file(
                                File(_slotPaths[i]!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade900,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white54),
                                ),
                              )
                            : Container(color: Colors.grey.shade900),
                      ),

                    // Layer 2: PNG bingkai
                    Positioned.fill(
                      child: Image.asset(
                        _selectedFrame.assetPath!,
                        fit: BoxFit.fill,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Layer 3: tombol ganti + hapus (DI LUAR RepaintBoundary) ─
              // Sembunyikan saat capture agar tidak ikut tercetak
              if (!_isCapturingFrame)
              for (int i = 0; i < slots.length; i++) ...[
                // Placeholder tap area untuk slot kosong
                if (_slotPaths[i] == null)
                  Positioned(
                    left: slots[i].leftFrac * W,
                    top: slots[i].topFrac * H,
                    width: slots[i].widthFrac * W,
                    height: slots[i].heightFrac * H,
                    child: GestureDetector(
                      onTap: () => _handleSlotTap(i),
                      child: Container(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded,
                                color: Colors.white54, size: 28),
                            const SizedBox(height: 4),
                            Text('Foto ${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Tombol ganti (edit) — pojok kanan atas setiap slot
                Positioned(
                  right: (1 - slots[i].leftFrac - slots[i].widthFrac) * W + 4,
                  top: slots[i].topFrac * H + 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleSlotTap(i),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _slotPaths[i] != null
                            ? Colors.black54
                            : const Color(0xFF5B62B3).withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        _slotPaths[i] != null
                            ? Icons.edit_rounded
                            : Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Tombol hapus — pojok kiri atas (hanya jika slot sudah terisi)
                if (_slotPaths[i] != null)
                  Positioned(
                    left: slots[i].leftFrac * W + 4,
                    top: slots[i].topFrac * H + 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _slotPaths[i] = null),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFrameSelector() {
    return Container(
      height: 88,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kFrames.length,
        itemBuilder: (_, i) {
          final frame = kFrames[i];
          final isSelected = _selectedFrame.id == frame.id;

          return GestureDetector(
            onTap: () => setState(() => _selectedFrame = frame),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              width: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? frame.accent.withValues(alpha: 0.12)
                    : const Color(0xFFEDE2E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? frame.accent : Colors.grey.shade200,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (frame.assetPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        frame.assetPath!,
                        width: 36, height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.photo_size_select_large_rounded,
                          color: frame.accent,
                          size: 26,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.hide_image_outlined,
                        color: isSelected ? frame.accent : Colors.grey,
                        size: 26),
                  const SizedBox(height: 4),
                  Text(
                    frame.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.2,
                      color: isSelected ? frame.accent : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadata(String timeStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_camera_rounded,
                size: 15, color: Color(0xFF5B62B3)),
            const SizedBox(width: 6),
            Text(_getFileSize(),
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            Text('Diambil $timeStr',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _captureAndSendEmail,
              icon: const Icon(Icons.email_rounded),
              label: const Text('Kirim via Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B62B3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveResult,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5B62B3)),
                    foregroundColor: const Color(0xFF5B62B3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Ambil Lagi'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
