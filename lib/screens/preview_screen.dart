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

/// Deskripsi satu pilihan bingkai.
class FrameOption {
  final String id;
  final String label;
  final String? assetPath;
  final Color accent;

  /// Tiga slot foto yang cocok dengan desain PNG bingkai.
  final List<FrameSlot>? slots;

  const FrameOption({
    required this.id,
    required this.label,
    required this.accent,
    this.assetPath,
    this.slots,
  });
}

// ── Koordinat slot untuk setiap bingkai ──────────────────────────────────────
// Nilai dihitung berdasarkan proporsi visual PNG (lebar ~290px, tinggi ~860px)

const _slotsFilmStrip = [
  FrameSlot(0.10, 0.05, 0.80, 0.26), // kotak atas
  FrameSlot(0.10, 0.34, 0.80, 0.26), // kotak tengah
  FrameSlot(0.10, 0.63, 0.80, 0.26), // kotak bawah
];

const _slotsY2K = [
  FrameSlot(0.08, 0.04, 0.84, 0.25),
  FrameSlot(0.08, 0.32, 0.84, 0.25),
  FrameSlot(0.08, 0.60, 0.84, 0.25),
];

const _slotsMusic = [
  FrameSlot(0.07, 0.03, 0.86, 0.23),
  FrameSlot(0.07, 0.29, 0.86, 0.23),
  FrameSlot(0.07, 0.55, 0.86, 0.23),
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
  ),
  const FrameOption(
    id: 'frame2',
    label: 'Y2K\nVibes',
    accent: Color(0xFF6B4EFF),
    assetPath: 'assets/frames/Frame_2.png',
    slots: _slotsY2K,
  ),
  const FrameOption(
    id: 'frame3',
    label: 'Music\nPlayer',
    accent: Color(0xFF7CB518),
    assetPath: 'assets/frames/Frame_3.png',
    slots: _slotsMusic,
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
  // Bingkai yang dipilih — mulai tanpa bingkai
  FrameOption _selectedFrame = kFrames.first;

  // Tiga slot foto: slot[0] = foto dari kamera, slot[1..2] = kosong
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

  // ─── Simpan hasil render ke galeri ──────────────────────────────────────

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
      // Cache context-dependent objects sebelum await
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

  // ─── Pilih foto untuk slot ───────────────────────────────────────────────

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
            // Foto tersimpan di AppState
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    final hasFrame = _selectedFrame.id != 'none';
    final filledSlots =
        _slotPaths.where((s) => s != null).length;

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
      body: Column(
        children: [
          // ─── Area foto / frame ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: RepaintBoundary(
                key: _renderKey,
                child: hasFrame ? _buildFrameView() : _buildSingleView(),
              ),
            ),
          ),

          // ─── Pemilih bingkai ───────────────────────────────────────────
          _buildFrameSelector(),

          // ─── Info slot ─────────────────────────────────────────────────
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

          // ─── Metadata ──────────────────────────────────────────────────
          _buildMetadata(timeStr),

          const SizedBox(height: 8),

          // ─── Tombol aksi ───────────────────────────────────────────────
          _buildActions(),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  // ─── Tampilan tunggal (tanpa bingkai) ────────────────────────────────────

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

  // ─── FIX: Tampilan frame dengan slot foto ─────────────────────────────────

  Widget _buildFrameView() {
    final slots = _selectedFrame.slots ?? _slotsFilmStrip;

    return LayoutBuilder(builder: (ctx, constraints) {
      final W = constraints.maxWidth;
      final H = constraints.maxHeight;

      return Stack(
        children: [
          // Layer 0: background gelap agar slot kosong terlihat rapi
          Positioned.fill(
            child: Container(color: Colors.black),
          ),

          // Layer 1: foto-foto dalam slot
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
                            const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Colors.white54,
                                size: 28),
                            const SizedBox(height: 4),
                            Text('Foto ${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
            ),

          // Layer 2: PNG bingkai paling atas (overlay)
          Positioned.fill(
            child: Image.asset(
              _selectedFrame.assetPath!,
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Layer 3: tombol ganti foto di atas foto yang sudah terisi
          for (int i = 0; i < slots.length; i++)
            if (_slotPaths[i] != null)
              Positioned(
                right: (1 - slots[i].leftFrac - slots[i].widthFrac) * W + 4,
                top: slots[i].topFrac * H + 4,
                child: GestureDetector(
                  onTap: () => _handleSlotTap(i),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
        ],
      );
    });
  }

  // ─── Pemilih bingkai ─────────────────────────────────────────────────────

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
            // FIX: setState dipanggil langsung — tidak ada lapisan yang memblokir
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
                  // Thumbnail
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
