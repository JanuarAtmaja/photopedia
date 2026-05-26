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
// OVERLAY ITEM
// ─────────────────────────────────────────────────────────────────────────────

class OverlayItem {
  final String id;
  final String type; // 'text' | 'emoji'
  String content;
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
    String? content,
  }) =>
      OverlayItem(
        id: id,
        type: type,
        content: content ?? this.content,
        position: position ?? this.position,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PHOTO SCREEN
// Terima List<String> photoPaths (3 foto).
// User bisa overlay teks/emoji ke semua foto.
// Setelah selesai, teruskan 3 foto ke PreviewScreen (pemilihan frame).
// ─────────────────────────────────────────────────────────────────────────────

class EditPhotoScreen extends StatefulWidget {
  /// List path foto (biasanya 3). Wajib diisi.
  final List<String> photoPaths;
  final String initialFilterId;

  const EditPhotoScreen({
    super.key,
    required this.photoPaths,
    this.initialFilterId = 'none',
    // Kept for back-compat jika ada code lain yang masih pakai photoPath tunggal
    String? photoPath,
  });

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  // ─── Foto yang sedang aktif diedit ──────────────────────────────────────
  int _activeIndex = 0;

  // Untuk setiap foto: bytes hasil filter
  late List<Uint8List?> _previewBytes;
  late List<Uint8List?> _originalBytes;
  late List<bool> _isLoading;

  // Filter & brightness
  late CameraFilter _activeFilter;
  double _brightness = 0;

  // Overlay per-foto (Map index → list overlay)
  late Map<int, List<OverlayItem>> _overlaysMap;
  String? _selectedOverlayId;

  // RepaintBoundary key per foto
  late List<GlobalKey> _repaintKeys;

  bool _isSaving = false;

  static const List<String> _fontFamilies = [
    'Default', 'Serif', 'Monospace', 'Cursive', 'Fantasy',
  ];

  static const List<Color> _textColors = [
    Colors.white, Colors.black, Colors.yellow, Colors.red,
    Colors.cyan, Colors.green, Color(0xFFFF69B4), Color(0xFF5B62B3),
  ];

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
    final n = widget.photoPaths.length;
    _activeFilter = kAppFilters.firstWhere(
      (f) => f.id == widget.initialFilterId,
      orElse: () => kAppFilters.first,
    );
    _previewBytes = List.filled(n, null);
    _originalBytes = List.filled(n, null);
    _isLoading = List.filled(n, true);
    _overlaysMap = {for (int i = 0; i < n; i++) i: []};
    _repaintKeys = List.generate(n, (_) => GlobalKey());
    _loadAll();
  }

  Future<void> _loadAll() async {
    for (int i = 0; i < widget.photoPaths.length; i++) {
      await _loadPhoto(i);
    }
  }

  Future<void> _loadPhoto(int index) async {
    try {
      final bytes = await File(widget.photoPaths[index]).readAsBytes();
      _originalBytes[index] = bytes;
      final preview = await _computeFilter(bytes, _activeFilter, _brightness.toInt());
      if (mounted) {
        setState(() {
          _previewBytes[index] = preview;
          _isLoading[index] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading[index] = false);
    }
  }

  Future<void> _applyFilterToAll() async {
    for (int i = 0; i < widget.photoPaths.length; i++) {
      final orig = _originalBytes[i];
      if (orig == null) continue;
      final preview = await _computeFilter(orig, _activeFilter, _brightness.toInt());
      if (mounted) setState(() => _previewBytes[i] = preview);
    }
  }

  static Future<Uint8List> _computeFilter(
    Uint8List raw, CameraFilter filter, int brightness,
  ) async {
    img.Image? image = img.decodeImage(raw);
    if (image == null) return raw;
    if (filter.applyToImage != null) image = filter.applyToImage!(image);
    if (brightness != 0) {
      final out = img.Image(width: image.width, height: image.height);
      for (int y = 0; y < image.height; y++)
        for (int x = 0; x < image.width; x++) {
          final px = image.getPixel(x, y);
          out.setPixelRgba(x, y,
            (px.r.toInt() + brightness).clamp(0, 255),
            (px.g.toInt() + brightness).clamp(0, 255),
            (px.b.toInt() + brightness).clamp(0, 255),
            px.a.toInt());
        }
      image = out;
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  // ─── Simpan semua foto dan navigasi ke PreviewScreen ─────────────────────

  Future<void> _saveAndNext() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final List<String> savedPaths = [];
      for (int i = 0; i < widget.photoPaths.length; i++) {
        final key = _repaintKeys[i];
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          savedPaths.add(widget.photoPaths[i]);
          continue;
        }
        final uiImage = await boundary.toImage(pixelRatio: 3.0);
        final byteData =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);
        final resultBytes = byteData!.buffer.asUint8List();

        final dir = await getApplicationDocumentsDirectory();
        final outPath = p.join(
            dir.path, 'edited_${DateTime.now().millisecondsSinceEpoch}_$i.png');
        await File(outPath).writeAsBytes(resultBytes);
        savedPaths.add(outPath);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(photoPaths: savedPaths),
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

  // ─── Overlay helpers ─────────────────────────────────────────────────────

  List<OverlayItem> get _currentOverlays => _overlaysMap[_activeIndex] ?? [];

  void _deleteOverlay(String id) {
    setState(() {
      _overlaysMap[_activeIndex]?.removeWhere((o) => o.id == id);
      if (_selectedOverlayId == id) _selectedOverlayId = null;
    });
  }

  void _updateOverlay(String id, OverlayItem updated) {
    setState(() {
      final list = _overlaysMap[_activeIndex];
      if (list == null) return;
      final idx = list.indexWhere((o) => o.id == id);
      if (idx != -1) list[idx] = updated;
    });
  }

  // ─── Dialog tambah / edit teks ───────────────────────────────────────────

  Future<void> _showAddTextDialog({OverlayItem? editing}) async {
    String inputText = editing?.content ?? '';
    Color selectedColor = editing?.color ?? Colors.white;
    String selectedFont = editing?.fontFamily ?? 'Default';
    double selectedSize = editing?.fontSize ?? 28;

    // Controller dibuat SEKALI di sini — di luar StatefulBuilder.
    // Kalau dibuat di dalam StatefulBuilder, setiap setBS() trigger rebuild
    // dan controller reset → teks hanya bisa 1 karakter.
    final textCtrl = TextEditingController(text: inputText);
    textCtrl.selection = TextSelection.collapsed(offset: textCtrl.text.length);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                editing != null ? 'Edit Teks' : 'Tambah Teks',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // Live preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  inputText.isEmpty ? 'Preview teks...' : inputText,
                  style: TextStyle(
                    fontFamily: selectedFont == 'Default' ? null : selectedFont,
                    fontSize: selectedSize.clamp(14.0, 36.0),
                    color: inputText.isEmpty ? Colors.grey : selectedColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Input teks — gunakan textCtrl yang dibuat di luar
              TextField(
                autofocus: editing == null,
                controller: textCtrl,
                onChanged: (v) {
                  inputText = v;
                  setBS(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Ketik teks kamu...',
                  filled: true,
                  fillColor: const Color(0xFFF5F0FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pilih warna
              const Text('Warna Teks',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
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
                                ? const Color(0xFF5B62B3)
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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                              ? const Color(0xFF5B62B3)
                              : const Color(0xFFEEEDF8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          font,
                          style: TextStyle(
                            fontFamily: font == 'Default' ? null : font,
                            color: isSel ? Colors.white : const Color(0xFF5B62B3),
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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Slider(
                value: selectedSize,
                min: 14, max: 64, divisions: 25,
                activeColor: const Color(0xFF5B62B3),
                label: selectedSize.toInt().toString(),
                onChanged: (v) => setBS(() => selectedSize = v),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B62B3),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (inputText.trim().isEmpty) return;
                    setState(() {
                      if (editing != null) {
                        _updateOverlay(editing.id, editing.copyWith(
                          content: inputText.trim(),
                          color: selectedColor,
                          fontSize: selectedSize,
                          fontFamily: selectedFont,
                        ));
                      } else {
                        _overlaysMap[_activeIndex] ??= [];
                        _overlaysMap[_activeIndex]!.add(OverlayItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: 'text',
                          content: inputText.trim(),
                          position: const Offset(60, 60),
                          color: selectedColor,
                          fontSize: selectedSize,
                          fontFamily: selectedFont,
                        ));
                      }
                    });
                  },
                  child: Text(editing != null ? 'Simpan' : 'Tambahkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Dispose setelah modal tertutup
    textCtrl.dispose();
  }

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8, childAspectRatio: 1,
                crossAxisSpacing: 4, mainAxisSpacing: 4,
              ),
              itemCount: _emojiList.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _overlaysMap[_activeIndex] ??= [];
                    _overlaysMap[_activeIndex]!.add(OverlayItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: 'emoji',
                      content: _emojiList[i],
                      position: const Offset(100, 100),
                      fontSize: 40,
                    ));
                  });
                },
                child: Center(
                  child: Text(_emojiList[i], style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(
          'Edit Foto ${_activeIndex + 1}/${widget.photoPaths.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset overlay foto ini',
            onPressed: () => setState(() {
              _overlaysMap[_activeIndex] = [];
              _selectedOverlayId = null;
            }),
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF5B62B3)),
                  tooltip: 'Selesai edit, pilih frame',
                  onPressed: _saveAndNext,
                ),
        ],
      ),
      body: Column(
        children: [
          // Strip pilih foto mana yang diedit
          _buildPhotoTabs(),
          Expanded(child: _buildPhotoCanvas()),
          Container(
            color: const Color(0xFF12122A),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterRow(),
                _buildBrightnessSlider(),
                _buildOverlayToolbar(),
                if (_selectedOverlayId != null) _buildSelectedLayerPanel(),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab strip atas: thumbnail 3 foto + indikator overlay
  Widget _buildPhotoTabs() {
    return Container(
      height: 72,
      color: const Color(0xFF12122A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.photoPaths.length, (i) {
          final isActive = _activeIndex == i;
          final overlayCount = _overlaysMap[i]?.length ?? 0;
          return GestureDetector(
            onTap: () => setState(() {
              _activeIndex = i;
              _selectedOverlayId = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: isActive ? 56 : 48,
              height: isActive ? 56 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? const Color(0xFF5B62B3) : Colors.white24,
                  width: isActive ? 2.5 : 1,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewBytes[i] != null
                        ? Image.memory(_previewBytes[i]!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity)
                        : Container(
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.image,
                                color: Colors.white38, size: 20)),
                  ),
                  // Badge jumlah overlay
                  if (overlayCount > 0)
                    Positioned(
                      top: 2, right: 2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5B62B3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$overlayCount',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhotoCanvas() {
    final bytes = _previewBytes[_activeIndex];
    if (_isLoading[_activeIndex]) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B62B3)));
    }
    if (bytes == null) {
      return const Center(
          child: Text('Gagal memuat foto',
              style: TextStyle(color: Colors.red)));
    }
    return GestureDetector(
      onTap: () => setState(() => _selectedOverlayId = null),
      child: Center(
        child: RepaintBoundary(
          key: _repaintKeys[_activeIndex],
          child: Stack(
            children: [
              Image.memory(bytes, fit: BoxFit.contain),
              ..._currentOverlays.map(_buildDraggableOverlay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableOverlay(OverlayItem item) {
    final isSelected = _selectedOverlayId == item.id;
    return Positioned(
      left: item.position.dx,
      top: item.position.dy,
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedOverlayId = isSelected ? null : item.id;
        }),
        onPanUpdate: (d) => _updateOverlay(
          item.id,
          item.copyWith(position: item.position + d.delta),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF5B62B3)
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
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
            if (isSelected) ...[
              // Hapus
              Positioned(
                top: -10, right: -10,
                child: GestureDetector(
                  onTap: () => _deleteOverlay(item.id),
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
              // Edit (khusus teks)
              if (item.type == 'text')
                Positioned(
                  top: -10, left: -10,
                  child: GestureDetector(
                    onTap: () => _showAddTextDialog(editing: item),
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: Color(0xFF5B62B3), shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 13),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLayerPanel() {
    final list = _currentOverlays;
    final item = list.firstWhere(
      (o) => o.id == _selectedOverlayId,
      orElse: () => list.first,
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B62B3), width: 1),
      ),
      child: Row(
        children: [
          Text(
            item.type == 'emoji' ? item.content : '"${item.content}"',
            style: TextStyle(
                color: Colors.white,
                fontSize: item.type == 'emoji' ? 22 : 13),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (item.type == 'text')
            TextButton.icon(
              onPressed: () => _showAddTextDialog(editing: item),
              icon: const Icon(Icons.edit, size: 14, color: Color(0xFF5B62B3)),
              label: const Text('Edit',
                  style: TextStyle(color: Color(0xFF5B62B3), fontSize: 12)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          TextButton.icon(
            onPressed: () => _deleteOverlay(item.id),
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            label: const Text('Hapus',
                style: TextStyle(color: Colors.red, fontSize: 12)),
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: kAppFilters.length,
        itemBuilder: (_, i) {
          final f = kAppFilters[i];
          final isActive = _activeFilter.id == f.id;
          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = f);
              _applyFilterToAll();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: f.chipColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(f.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.white54,
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrightnessSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.brightness_low, color: Colors.white54, size: 20),
          Expanded(
            child: Slider(
              value: _brightness,
              min: -100, max: 100, divisions: 200,
              activeColor: const Color(0xFF5B62B3),
              inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => _brightness = v),
              onChangeEnd: (_) => _applyFilterToAll(),
            ),
          ),
          const Icon(Icons.brightness_high,
              color: Color(0xFF5B62B3), size: 20),
        ],
      ),
    );
  }

  Widget _buildOverlayToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarBtn(
            icon: Icons.text_fields_rounded,
            label: 'Teks',
            onTap: () => _showAddTextDialog(),
          ),
          _ToolbarBtn(
            icon: Icons.emoji_emotions_rounded,
            label: 'Emoji',
            onTap: _showEmojiPicker,
          ),
          _ToolbarBtn(
            icon: Icons.layers_clear_rounded,
            label: 'Hapus Semua',
            color: Colors.red.shade300,
            onTap: () => setState(() {
              _overlaysMap[_activeIndex] = [];
              _selectedOverlayId = null;
            }),
          ),
        ],
      ),
    );
  }
}

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
    final c = color ?? const Color(0xFF5B62B3);
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
