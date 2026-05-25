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

/// Koordinat satu slot foto dalam bingkai (nilai 0.0–1.0, relatif terhadap
/// dimensi total bingkai). Dipakai di LayoutBuilder agar responsif.
class FrameSlot {
  final double leftFrac;
  final double topFrac;
  final double widthFrac;
  final double heightFrac;
  const FrameSlot(
      this.leftFrac, this.topFrac, this.widthFrac, this.heightFrac);
}

class FrameOption {
  final String id;
  final String label;
  final String? assetPath;
  final Color accent;
  final List<FrameSlot>? slots;
  // Rasio aspek asli PNG bingkai (width/height)
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

// ── FIX 1: Koordinat slot dikalibrasi ulang dengan mengukur PNG frame ────────
// Frame_1 (Film Strip): tiga slot foto horizontal, ada border hitam atas/bawah
const _slotsFilmStrip = [
  FrameSlot(0.055, 0.055, 0.890, 0.245), // slot atas
  FrameSlot(0.055, 0.330, 0.890, 0.245), // slot tengah
  FrameSlot(0.055, 0.610, 0.890, 0.245), // slot bawah
];

// Frame_2 (Y2K): background grid biru, pink blob, tiga slot
const _slotsY2K = [
  FrameSlot(0.055, 0.038, 0.890, 0.245),
  FrameSlot(0.055, 0.315, 0.890, 0.245),
  FrameSlot(0.055, 0.595, 0.890, 0.245),
];

// Frame_3 (Music Player): abu-abu, music player UI bawah, tiga slot foto
const _slotsMusic = [
  FrameSlot(0.055, 0.038, 0.890, 0.230),
  FrameSlot(0.055, 0.300, 0.890, 0.230),
  FrameSlot(0.055, 0.560, 0.890, 0.230),
];

/// Daftar semua bingkai yang tersedia — satu source of truth.
final List<FrameOption> kFrames = [
  const FrameOption(
    id: 'none',
    label: 'Tanpa\nBingkai',
    accent: Colors.grey,
  ),
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
    accent: Color(0xFF6B4EFF),
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
  final String photoPath;
  const PreviewScreen({super.key, required this.photoPath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  FrameOption _selectedFrame = kFrames.first;
  final List<String?> _slotPaths = [null, null, null];
  bool _isSaving = false;
  final GlobalKey _renderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _slotPaths[0] = widget.photoPath;
  }

  String _getFileSize() {
    try {
      final bytes = File(widget.photoPath).lengthSync();
      return bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)} KB'
          : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _saveResult() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary =
          _renderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');

      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          p.join(dir.path, 'frame_${DateTime.now().millisecondsSinceEpoch}.png');
      await File(outPath).writeAsBytes(bytes);

      if (!mounted) return;
      final state = AppStateScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await state.addPhoto(outPath);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Foto tersimpan di galeri ✓'),
          backgroundColor: Color(0xFF6B4EFF),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // FIX 2: Tombol FAB tambah foto — tidak lagi mengandalkan tap pada frame
  void _showAddPhotoDialog() {
    // Cari slot kosong pertama
    int emptySlot = -1;
    for (int i = 0; i < _slotPaths.length; i++) {
      if (_slotPaths[i] == null) {
        emptySlot = i;
        break;
      }
    }

    if (_selectedFrame.id == 'none') {
      _showSnack('Pilih bingkai terlebih dahulu untuk menambah foto.');
      return;
    }

    if (emptySlot == -1) {
      // Semua slot terisi, tanya mau ganti yang mana
      showModalBottomSheet(
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
              const Text('Semua slot terisi. Pilih slot yang ingin diganti:',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 8),
              for (int i = 0; i < _slotPaths.length; i++)
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(_slotPaths[i]!),
                        width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  title: Text('Slot ${i + 1}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _handleSlotTap(i);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    } else {
      _handleSlotTap(emptySlot);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF6B4EFF)),
    );
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
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: Color(0xFF6B4EFF)),
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
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF6B4EFF)),
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
      final xfile = await ImagePicker()
          .pickImage(source: source, imageQuality: 90);
      if (xfile == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(
          dir.path, 'slot_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(xfile.path).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Widget _buildSavedPhotoStrip(int slotIndex, BuildContext sheetCtx) {
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
                    border: Border.all(color: const Color(0xFFD8D0FF)),
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
    final filledSlots = _slotPaths.where((s) => s != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          color: const Color(0xFF6B4EFF),
          onPressed: () =>
              MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF6B4EFF),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      // FIX 2: FAB di kanan bawah untuk tambah foto
      floatingActionButton: hasFrame && filledSlots < 3
          ? FloatingActionButton.small(
              onPressed: _showAddPhotoDialog,
              backgroundColor: const Color(0xFF6B4EFF),
              tooltip: 'Tambah foto ke slot',
              child: const Icon(Icons.add_photo_alternate_rounded,
                  color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: RepaintBoundary(
                key: _renderKey,
                child: hasFrame ? _buildFrameView() : _buildSingleView(),
              ),
            ),
          ),
          _buildFrameSelector(),
          if (hasFrame)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Ketuk kotak kosong untuk mengisi ($filledSlots/3 terisi)',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
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
            color: const Color(0xFF6B4EFF).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(widget.photoPath),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image,
                  color: Colors.grey, size: 64)),
        ),
      ),
    );
  }

  // FIX 1: Frame view yang tepat — PNG di atas, foto di slot yang presisi
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
              // Layer 0: background hitam
              Positioned.fill(child: Container(color: Colors.black)),

              // Layer 1: foto dalam slot — PRESISI sesuai koordinat
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
                      : GestureDetector(
                          onTap: () => _handleSlotTap(i),
                          child: Container(
                            color: Colors.grey.shade900,
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

              // Layer 2: PNG bingkai di atas — FILL agar menutupi tepat
              Positioned.fill(
                child: Image.asset(
                  _selectedFrame.assetPath!,
                  fit: BoxFit.fill, // fill agar pas menutupi frame
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              // Layer 3: tombol ganti foto di slot terisi
              for (int i = 0; i < slots.length; i++)
                if (_slotPaths[i] != null)
                  Positioned(
                    right: (1 - slots[i].leftFrac - slots[i].widthFrac) * W + 4,
                    top: slots[i].topFrac * H + 4,
                    child: GestureDetector(
                      onTap: () => _handleSlotTap(i),
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
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
                    : const Color(0xFFF8F5FF),
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
                        width: 36,
                        height: 36,
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
                      fontWeight: isSelected
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
    );
  }

  Widget _buildMetadata(String timeStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_camera_rounded,
                size: 15, color: Color(0xFF6B4EFF)),
            const SizedBox(width: 6),
            Text(_getFileSize(),
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
            const Spacer(),
            Text('Diambil $timeStr',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11)),
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmailScreen(
                      preSelectedPhotoPath: widget.photoPath),
                ),
              ),
              icon: const Icon(Icons.email_rounded),
              label: const Text('Kirim via Email'),
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
                    side: const BorderSide(color: Color(0xFF6B4EFF)),
                    foregroundColor: const Color(0xFF6B4EFF),
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
