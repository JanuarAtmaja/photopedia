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
// FRAME DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class FrameSlot {
  final double leftFrac, topFrac, widthFrac, heightFrac;
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
    required this.id, required this.label, required this.accent,
    this.assetPath, this.slots, this.frameAspectRatio = 290.0 / 860.0,
  });
}

const _slots3 = [
  FrameSlot(0.055, 0.037, 0.890, 0.230),
  FrameSlot(0.055, 0.287, 0.890, 0.230),
  FrameSlot(0.055, 0.535, 0.890, 0.230),
];

// Slot untuk 1 foto sudah tidak dipakai — frame langsung gunakan slots aslinya

final List<FrameOption> kFrames = [
  const FrameOption(id: 'none', label: 'Tanpa\nBingkai', accent: Colors.grey),
  const FrameOption(id: 'frame1', label: 'Film\nStrip', accent: Color(0xFF2D2D2D),
      assetPath: 'assets/frames/Frame_1.png', slots: _slots3,
      frameAspectRatio: 290.0 / 860.0),
  const FrameOption(id: 'frame2', label: 'Y2K\nVibes', accent: Color(0xFF5B62B3),
      assetPath: 'assets/frames/Frame_2.png', slots: _slots3,
      frameAspectRatio: 290.0 / 860.0),
  const FrameOption(id: 'frame3', label: 'Music\nPlayer', accent: Color(0xFF7CB518),
      assetPath: 'assets/frames/Frame_3.png', slots: _slots3,
      frameAspectRatio: 290.0 / 860.0),
];

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PreviewScreen extends StatefulWidget {
  final List<String> photoPaths;
  const PreviewScreen({super.key, required this.photoPaths, String? photoPath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late FrameOption _selectedFrame;
  final List<String?> _slotPaths = [null, null, null];
  bool _isSaving = false;
  bool _isCapturing = false;
  final GlobalKey _renderKey = GlobalKey();

  bool get _isSinglePhoto => widget.photoPaths.length == 1;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.photoPaths.length && i < 3; i++) {
      _slotPaths[i] = widget.photoPaths[i];
    }
    // Request 3 fix: 1 foto tetap bisa pakai semua frame, default 'none'
    _selectedFrame = _isSinglePhoto ? kFrames.first : kFrames[1];
  }

  // Slot aktif untuk frame saat ini
  List<FrameSlot> _slotsForFrame(FrameOption frame) {
    if (frame.slots == null) return [];
    // Selalu gunakan slots asli dari frame — 1 foto masuk slot 1, sisanya kosong
    return frame.slots!;
  }

  String _getFileSize() {
    try {
      final path = widget.photoPaths.isNotEmpty ? widget.photoPaths.first : '';
      if (path.isEmpty) return '-';
      final bytes = File(path).lengthSync();
      return bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) { return '-'; }
  }

  Future<void> _captureAndSendEmail() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _isCapturing = true; });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary = _renderKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(dir.path, 'email_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(bytes);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => EmailScreen(preSelectedPhotoPath: outPath)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; _isCapturing = false; });
    }
  }

  Future<void> _saveResult() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _isCapturing = true; });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary = _renderKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');
      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(dir.path, 'frame_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(bytes);
      if (!mounted) return;
      final state = AppStateScope.of(context);
      await state.addPhoto(outPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto tersimpan di galeri ✓'),
              backgroundColor: kPrimary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; _isCapturing = false; });
    }
  }

  Future<void> _handleSlotTap(int slotIndex) async {
    final isDark = ThemeModeScope.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? kSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('Foto ${slotIndex + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: kPrimary),
            title: const Text('Ambil foto baru'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final path = await _captureImage(ImageSource.camera);
              if (path != null && mounted) setState(() => _slotPaths[slotIndex] = path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: kPrimary),
            title: const Text('Pilih dari galeri'),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final path = await _captureImage(ImageSource.gallery);
              if (path != null && mounted) setState(() => _slotPaths[slotIndex] = path);
            },
          ),
          _buildSavedPhotoStrip(slotIndex, sheetCtx),
          const SizedBox(height: 8),
        ],
      )),
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
    } catch (_) { return null; }
  }

  Widget _buildSavedPhotoStrip(int slotIndex, BuildContext sheetCtx) {
    final photos = AppStateScope.of(context).photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text('Dari foto tersimpan:',
              style: TextStyle(color: Colors.grey, fontSize: 12))),
      SizedBox(height: 76, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: photos.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            Navigator.pop(sheetCtx);
            setState(() => _slotPaths[slotIndex] = photos[i].path);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8), width: 68,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCFD1E8))),
            child: ClipRRect(borderRadius: BorderRadius.circular(7),
              child: Image.file(File(photos[i].path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
          ),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    final bg = isDark ? kBackgroundDark : kBackground;
    final cardBg = isDark ? kSurfaceDark : Colors.white;
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    final hasFrame = _selectedFrame.id != 'none';

    return Scaffold(
      backgroundColor: bg,
      drawer: buildAppDrawer(context, currentRoute: ''),
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Preview',
            style: TextStyle(color: kPrimary,
                fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: kPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: kPrimary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Foto preview
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: hasFrame ? _buildFrameView() : _buildSingleView(),
          )),

          // Frame selector
          _buildFrameSelector(cardBg, isDark),

          // Hint
          if (hasFrame && !_isSinglePhoto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(children: [
                Icon(Icons.info_outline, size: 12,
                    color: isDark ? Colors.white38 : Colors.grey),
                const SizedBox(width: 4),
                Text('Ketuk foto untuk ganti • Seret untuk tukar posisi',
                    style: TextStyle(fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey)),
              ]),
            ),

          // Metadata
          _buildMetadata(timeStr, cardBg, isDark),
          const SizedBox(height: 8),
          _buildActions(isDark),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  // Tanpa bingkai: foto penuh dengan sudut rounded mengikuti aspect ratio asli
  Widget _buildSingleView() {
    return RepaintBoundary(
      key: _renderKey,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: kPrimary.withValues(alpha: 0.15),
              blurRadius: 20, offset: const Offset(0, 6),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(widget.photoPaths.isNotEmpty ? widget.photoPaths.first : ''),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 64)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrameView() {
    final slots = _slotsForFrame(_selectedFrame);
    final ratio = _selectedFrame.frameAspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: LayoutBuilder(builder: (ctx, constraints) {
          final W = constraints.maxWidth;
          final H = constraints.maxHeight;
          return Stack(children: [
            // ── Konten yang di-capture ──────────────────────────────────
            RepaintBoundary(
              key: _renderKey,
              child: Stack(children: [
                Positioned.fill(child: Container(color: Colors.black)),
                for (int i = 0; i < slots.length; i++)
                  Positioned(
                    left: slots[i].leftFrac * W,
                    top: slots[i].topFrac * H,
                    width: slots[i].widthFrac * W,
                    height: slots[i].heightFrac * H,
                    child: _slotPaths[i] != null
                        ? Image.file(File(_slotPaths[i]!),
                            fit: BoxFit.cover, width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.grey.shade900,
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.white54)))
                        : Container(color: Colors.grey.shade900),
                  ),
                Positioned.fill(child: Image.asset(
                  _selectedFrame.assetPath!,
                  fit: BoxFit.fill,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )),
              ]),
            ),

            // ── Kontrol slot (tidak ikut di-capture) ────────────────────
            if (!_isCapturing)
              for (int i = 0; i < slots.length; i++) ...[
                // DragTarget
                Positioned(
                  left: slots[i].leftFrac * W, top: slots[i].topFrac * H,
                  width: slots[i].widthFrac * W, height: slots[i].heightFrac * H,
                  child: DragTarget<int>(
                    onWillAcceptWithDetails: (d) => d.data != i,
                    onAcceptWithDetails: (d) {
                      setState(() {
                        final tmp = _slotPaths[d.data];
                        _slotPaths[d.data] = _slotPaths[i];
                        _slotPaths[i] = tmp;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Slot ${d.data + 1} ↔ Slot ${i + 1} ditukar'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: kPrimary,
                      ));
                    },
                    builder: (ctx, candidates, _) => Container(
                      decoration: candidates.isNotEmpty ? BoxDecoration(
                        border: Border.all(color: kPrimary, width: 3),
                        color: kPrimary.withValues(alpha: 0.2),
                      ) : null,
                    ),
                  ),
                ),

                // Placeholder jika slot kosong
                if (_slotPaths[i] == null)
                  Positioned(
                    left: slots[i].leftFrac * W, top: slots[i].topFrac * H,
                    width: slots[i].widthFrac * W, height: slots[i].heightFrac * H,
                    child: GestureDetector(
                      onTap: () => _handleSlotTap(i),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const Icon(Icons.add_photo_alternate_rounded,
                            color: Colors.white54, size: 28),
                        Text('Foto ${i + 1}', style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                      ]),
                    ),
                  ),

                // Drag handle (hanya jika ada foto + lebih dari 1 slot)
                if (_slotPaths[i] != null && slots.length > 1)
                  Positioned(
                    left: slots[i].leftFrac * W + (slots[i].widthFrac * W / 2) - 15,
                    top: slots[i].topFrac * H + 4,
                    child: Draggable<int>(
                      data: i,
                      onDragStarted: () => setState(() {}),
                      onDragEnd: (_) => setState(() {}),
                      onDraggableCanceled: (_, __) => setState(() {}),
                      feedback: Material(color: Colors.transparent,
                        child: Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kPrimary, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                          ),
                          child: ClipRRect(borderRadius: BorderRadius.circular(6),
                              child: Image.file(File(_slotPaths[i]!), fit: BoxFit.cover)),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.4, child: Container(
                        width: 30, height: 20,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )),
                      child: Container(
                        width: 30, height: 20,
                        decoration: BoxDecoration(color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white38)),
                        child: const Icon(Icons.drag_handle_rounded,
                            color: Colors.white70, size: 14),
                      ),
                    ),
                  ),

                // Tombol edit (kanan atas slot)
                Positioned(
                  right: (1 - slots[i].leftFrac - slots[i].widthFrac) * W + 4,
                  top: slots[i].topFrac * H + 4,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleSlotTap(i),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _slotPaths[i] != null
                            ? Colors.black54
                            : kPrimary.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(_slotPaths[i] != null
                          ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),

                // Tombol hapus (kiri atas slot)
                if (_slotPaths[i] != null)
                  Positioned(
                    left: slots[i].leftFrac * W + 4, top: slots[i].topFrac * H + 4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _slotPaths[i] = null),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
          ]);
        }),
      ),
    );
  }

  Widget _buildFrameSelector(Color cardBg, bool isDark) {
    return Container(
      height: 92,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: kFrames.length,
        itemBuilder: (_, i) {
          final frame = kFrames[i];
          final isSelected = _selectedFrame.id == frame.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedFrame = frame),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              width: 70,
              decoration: BoxDecoration(
                color: isSelected
                    ? frame.accent.withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F2F0)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? frame.accent
                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                frame.assetPath != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.asset(frame.assetPath!, width: 38, height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.photo_size_select_large_rounded,
                                    color: frame.accent, size: 26)))
                    : Icon(Icons.hide_image_outlined,
                        color: isSelected ? frame.accent : Colors.grey, size: 26),
                const SizedBox(height: 5),
                Text(frame.label, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, height: 1.2,
                      color: isSelected ? frame.accent : Colors.grey.shade500,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadata(String timeStr, Color cardBg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.photo_camera_rounded, size: 14, color: kPrimary),
          ),
          const SizedBox(width: 10),
          Text(_getFileSize(),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('Diambil $timeStr',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _captureAndSendEmail,
            icon: const Icon(Icons.email_rounded, size: 18),
            label: const Text('Kirim via Email'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveResult,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kPrimary, width: 1.5),
              foregroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: const Text('Ambil Lagi'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
        ]),
      ]),
    );
  }
}
