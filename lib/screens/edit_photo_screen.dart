import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/photo_state.dart';
import 'camera_screen.dart' show kAppFilters, CameraFilter;
import 'preview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL OVERLAY ITEM (teks / emoji — draggable di atas foto)
// ─────────────────────────────────────────────────────────────────────────────

class OverlayItem {
  final String id;
  final String type; // 'text' | 'emoji'
  final String content;
  Offset position;
  Color color;
  double fontSize;
  String fontFamily;

  OverlayItem({
    required this.id,
    required this.type,
    required this.content,
    required this.position,
    this.color = Colors.white,
    this.fontSize = 28,
    this.fontFamily = 'Default',
    
  });

  OverlayItem copyWith({
    Offset? position,
    Color? color,
    double? fontSize,
    String? fontFamily,
  }) =>
      OverlayItem(
        id: id,
        type: type,
        content: content,
        position: position ?? this.position,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PHOTO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditPhotoScreen extends StatefulWidget {
  final String photoPath;
  final bool isEditing;

  /// Filter yang dipilih di kamera — agar langsung aktif di editor.
  final String initialFilterId;

  const EditPhotoScreen({
    super.key,
    required this.photoPath,
    this.isEditing = false,
    this.initialFilterId = 'none',
  });

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  // ─── State foto & filter ────────────────────────────────────────────────
  Uint8List? _originalBytes;
  Uint8List? _previewBytes;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  late CameraFilter _activeFilter;
  double _brightness = 0; // -100 … +100

  // ─── Overlay items (teks & emoji) ───────────────────────────────────────
  final List<OverlayItem> _overlays = [];

  // ─── RepaintBoundary key untuk render akhir ─────────────────────────────
  final GlobalKey _repaintKey = GlobalKey();

  // ─── Pilihan font ────────────────────────────────────────────────────────
  static const List<String> _fontFamilies = [
    'Default',
    'Serif',
    'Monospace',
    'Cursive',
    'Fantasy',
  ];

  // ─── Warna teks ─────────────────────────────────────────────────────────
  static const List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.cyan,
    Colors.green,
    Color(0xFFFF69B4), // hot pink
    Color(0xFF6B4EFF), // purple
  ];

  // ─── Emoji yang tersedia ─────────────────────────────────────────────────
  static const List<String> _emojiList = [
    '😀','😂','🥰','😎','🤩','🥳','😜','🤔',
    '❤️','🔥','✨','🌟','🎉','🎊','🎈','🎁',
    '🌈','🦋','🌸','🌺','🍀','🌙','⭐','💫',
    '📸','🎬','🎵','🎶','💎','👑','🏆','🎯',
    '🍕','🍦','🧋','☕','🍓','🍑','🍊','🍋',
    '🐱','🐶','🐰','🐸','🦊','🐼','🦁','🐨',
  ];

  @override
  void initState() {
    super.initState();
    _activeFilter = kAppFilters.firstWhere(
      (f) => f.id == widget.initialFilterId,
      orElse: () => kAppFilters.first,
    );
    _loadImage();
  }

  // ─── Load & proses gambar ────────────────────────────────────────────────

  Future<void> _loadImage() async {
    try {
      _originalBytes = await File(widget.photoPath).readAsBytes();
      await _applyCurrentFilter();
    } catch (e) {
      _errorMessage = 'Gagal memuat gambar: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Terapkan filter + brightness ke _originalBytes → _previewBytes.
  /// Dijalankan di compute agar tidak memblokir UI thread.
  Future<void> _applyCurrentFilter() async {
    if (_originalBytes == null) return;

    final bytes = await _computeFilter(
      _originalBytes!,
      _activeFilter,
      _brightness.toInt(),
    );
    if (mounted) setState(() => _previewBytes = bytes);
  }

  static Future<Uint8List> _computeFilter(
    Uint8List raw,
    CameraFilter filter,
    int brightness,
  ) async {
    img.Image? image = img.decodeImage(raw);
    if (image == null) return raw;

    // 1. Terapkan filter warna
    if (filter.applyToImage != null) {
      image = filter.applyToImage!(image);
    }

    // 2. Terapkan brightness
    if (brightness != 0) {
      image = _applyBrightness(image, brightness);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  static img.Image _applyBrightness(img.Image src, int value) {
    final out = img.Image(width: src.width, height: src.height);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final px = src.getPixel(x, y);
        out.setPixelRgba(
          x, y,
          (px.r.toInt() + value).clamp(0, 255),
          (px.g.toInt() + value).clamp(0, 255),
          (px.b.toInt() + value).clamp(0, 255),
          px.a.toInt(),
        );
      }
    }
    return out;
  }

  // ─── Simpan hasil akhir ──────────────────────────────────────────────────

  Future<void> _saveAndNext() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Render boundary tidak ditemukan.');

      final uiImage = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final resultBytes = byteData!.buffer.asUint8List();

      // Simpan ke file baru
      final dir = await getApplicationDocumentsDirectory();
      final outPath = p.join(
          dir.path, 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(outPath).writeAsBytes(resultBytes);

      // Update path di AppState
      if (mounted) {
        final state = AppStateScope.of(context);
        // Cari photo lama dan update pathnya
        final existing = state.photos
            .where((ph) => ph.path == widget.photoPath)
            .firstOrNull;
        if (existing != null) {
          await state.updatePhotoPath(existing.id, outPath);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(photoPath: outPath),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Tambah teks ─────────────────────────────────────────────────────────

  Future<void> _showAddTextDialog() async {
    String inputText = '';
    Color selectedColor = Colors.white;
    String selectedFont = 'Default';
    double selectedSize = 28;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tambah Teks',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // Input teks
              TextField(
                autofocus: true,
                onChanged: (v) => inputText = v,
                decoration: InputDecoration(
                  hintText: 'Ketik teks kamu...',
                  filled: true,
                  fillColor: const Color(0xFFF8F5FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pilih warna
              const Text('Warna Teks',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _textColors.map((c) {
                    final isSel = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setBS(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        width: isSel ? 36 : 30,
                        height: isSel ? 36 : 30,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF6B4EFF)
                                : Colors.grey.shade300,
                            width: isSel ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Pilih font
              const Text('Jenis Font',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _fontFamilies.map((font) {
                    final isSel = selectedFont == font;
                    return GestureDetector(
                      onTap: () => setBS(() => selectedFont = font),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF6B4EFF)
                              : const Color(0xFFF0EDFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          font,
                          style: TextStyle(
                            fontFamily: font == 'Default' ? null : font,
                            color: isSel
                                ? Colors.white
                                : const Color(0xFF6B4EFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Ukuran font
              const Text('Ukuran',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Slider(
                value: selectedSize,
                min: 14,
                max: 64,
                divisions: 25,
                activeColor: const Color(0xFF6B4EFF),
                label: selectedSize.toInt().toString(),
                onChanged: (v) => setBS(() => selectedSize = v),
              ),
              const SizedBox(height: 8),

              // Tombol tambah
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (inputText.trim().isEmpty) return;
                    setState(() {
                      _overlays.add(OverlayItem(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        type: 'text',
                        content: inputText.trim(),
                        position: const Offset(60, 60),
                        color: selectedColor,
                        fontSize: selectedSize,
                        fontFamily: selectedFont,
                      ));
                    });
                  },
                  child: const Text('Tambahkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tambah emoji ────────────────────────────────────────────────────────

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Pilih Emoji',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _emojiList.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _overlays.add(OverlayItem(
                      id: DateTime.now()
                          .millisecondsSinceEpoch
                          .toString(),
                      type: 'emoji',
                      content: _emojiList[i],
                      position: const Offset(100, 100),
                      fontSize: 40,
                    ));
                  });
                },
                child: Center(
                  child: Text(_emojiList[i],
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reset ──────────────────────────────────────────────────────────────

  void _resetAll() {
    setState(() {
      _activeFilter = kAppFilters.first;
      _brightness = 0;
      _overlays.clear();
    });
    _applyCurrentFilter();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Edit Foto',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset',
            onPressed: _resetAll,
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF6B4EFF)),
                  tooltip: 'Simpan & Lanjut',
                  onPressed: _saveAndNext,
                ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // ─── Preview foto ─────────────────────────────────────
                    Expanded(child: _buildPhotoPreview()),

                    // ─── Kontrol bawah ───────────────────────────────────
                    Container(
                      color: const Color(0xFF12122A),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Filter chips
                          _buildFilterRow(),
                          // Brightness slider
                          _buildBrightnessSlider(),
                          // Overlay toolbar (teks, emoji)
                          _buildOverlayToolbar(),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 8),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ─── Widget: foto + overlay ──────────────────────────────────────────────

  Widget _buildPhotoPreview() {
    if (_previewBytes == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6B4EFF)));
    }
    return Center(
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          children: [
            // Foto hasil filter
            Image.memory(_previewBytes!, fit: BoxFit.contain),
            // Overlay items (teks & emoji) — draggable
            ..._overlays.map((item) => _buildDraggableOverlay(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOverlay(OverlayItem item) {
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final idx = _overlays.indexWhere((o) => o.id == item.id);
            if (idx != -1) {
              _overlays[idx] = _overlays[idx].copyWith(
                position: item.position + d.delta,
              );
            }
          });
        },
        onLongPress: () {
          // Long press → hapus overlay
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Hapus?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() =>
                        _overlays.removeWhere((o) => o.id == item.id));
                  },
                  child: const Text('Hapus'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.content,
            style: TextStyle(
              fontSize: item.fontSize,
              color: item.type == 'emoji' ? null : item.color,
              fontFamily:
                  item.fontFamily == 'Default' ? null : item.fontFamily,
              fontWeight: FontWeight.bold,
              shadows: item.type == 'text'
                  ? const [
                      Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(1, 1))
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget: filter row ──────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemExtent: 68,
        itemCount: kAppFilters.length,
        itemBuilder: (_, i) {
          final f = kAppFilters[i];
          final isActive = _activeFilter.id == f.id;
          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = f);
              _applyCurrentFilter();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: f.chipColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: isActive
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

  // ─── Widget: brightness slider ───────────────────────────────────────────

  Widget _buildBrightnessSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.brightness_low, color: Colors.white54, size: 20),
          Expanded(
            child: Slider(
              value: _brightness,
              min: -100,
              max: 100,
              divisions: 200,
              activeColor: const Color(0xFF6B4EFF),
              inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => _brightness = v),
              onChangeEnd: (_) => _applyCurrentFilter(),
            ),
          ),
          const Icon(Icons.brightness_high, color: Color(0xFF6B4EFF), size: 20),
        ],
      ),
    );
  }

  // ─── Widget: toolbar overlay ─────────────────────────────────────────────

  Widget _buildOverlayToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarBtn(
            icon: Icons.text_fields_rounded,
            label: 'Teks',
            onTap: _showAddTextDialog,
          ),
          _ToolbarBtn(
            icon: Icons.emoji_emotions_rounded,
            label: 'Emoji',
            onTap: _showEmojiPicker,
          ),
          _ToolbarBtn(
            icon: Icons.layers_clear_rounded,
            label: 'Hapus Semua',
            onTap: () => setState(() => _overlays.clear()),
            color: Colors.red.shade300,
          ),
        ],
      ),
    );
  }
}

// ─── Tombol toolbar kecil ─────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF6B4EFF);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: c.withValues(alpha: 0.2),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
