import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import 'camera_screen.dart' show kAppFilters, CameraFilter;
import 'preview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE FILTER — runs image processing off the main thread
// ─────────────────────────────────────────────────────────────────────────────

class _FilterRequest {
  final Uint8List raw;
  final String filterId;
  final int brightness;
  const _FilterRequest({required this.raw, required this.filterId, required this.brightness});
}

/// Top-level function for compute() isolate.
Uint8List _runFilter(_FilterRequest req) {
  img.Image? image = img.decodeImage(req.raw);
  if (image == null) return req.raw;

  final filter = kAppFilters.firstWhere(
    (f) => f.id == req.filterId,
    orElse: () => kAppFilters.first,
  );
  if (filter.applyToImage != null) image = filter.applyToImage!(image);
  if (req.brightness != 0) {
    final out = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final px = image.getPixel(x, y);
        out.setPixelRgba(x, y,
          (px.r.toInt() + req.brightness).clamp(0, 255),
          (px.g.toInt() + req.brightness).clamp(0, 255),
          (px.b.toInt() + req.brightness).clamp(0, 255),
          px.a.toInt());
      }
    }
    image = out;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY ITEM
// ─────────────────────────────────────────────────────────────────────────────

class OverlayItem {
  final String id;
  final String type; // 'text' | 'emoji'
  String content;
  Offset position;    // posisi relatif terhadap area foto (dalam foto-coords)
  Color color;
  double fontSize;
  String fontFamily;
  Size canvasSize;    // ukuran canvas saat item ditambahkan

  OverlayItem({
    required this.id,
    required this.type,
    required this.content,
    required this.position,
    this.color = Colors.white,
    this.fontSize = 28,
    this.fontFamily = 'Default',
    this.canvasSize = Size.zero,
  });

  OverlayItem copyWith({
    Offset? position,
    Color? color,
    double? fontSize,
    String? fontFamily,
    String? content,
    Size? canvasSize,
  }) =>
      OverlayItem(
        id: id,
        type: type,
        content: content ?? this.content,
        position: position ?? this.position,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        canvasSize: canvasSize ?? this.canvasSize,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PHOTO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditPhotoScreen extends StatefulWidget {
  final List<String> photoPaths;
  final String initialFilterId;
  /// true jika foto sudah ter-bake filter-nya (dari kamera), skip re-apply
  final bool filterAlreadyBaked;

  const EditPhotoScreen({
    super.key,
    required this.photoPaths,
    this.initialFilterId = 'none',
    this.filterAlreadyBaked = false,
    String? photoPath,
  });

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  int _activeIndex = 0;

  late List<Uint8List?> _previewBytes;
  late List<Uint8List?> _originalBytes;
  late List<bool> _isLoading;

  late Map<int, CameraFilter> _activeFilters;
  late Map<int, double> _brightnessMap;

  late Map<int, List<OverlayItem>> _overlaysMap;
  String? _selectedOverlayId;

  // ── FIX Bug 2: track canvas & image rect untuk koordinat akurat ──
  Size _lastCanvasSize = Size.zero;
  Rect _lastImageRect = Rect.zero; // area gambar yang sebenarnya tampil (BoxFit.contain)

  // Cache dimensi gambar per-index (diisi saat load)
  final Map<int, Size> _imageSizeCache = {};

  bool _isSaving = false;

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
    final defaultFilter = kAppFilters.firstWhere(
      (f) => f.id == widget.initialFilterId,
      orElse: () => kAppFilters.first,
    );
    _activeFilters = {for (int i = 0; i < n; i++) i: defaultFilter};
    _brightnessMap = {for (int i = 0; i < n; i++) i: 0.0};
    _previewBytes = List.filled(n, null);
    _originalBytes = List.filled(n, null);
    _isLoading = List.filled(n, true);
    _overlaysMap = {for (int i = 0; i < n; i++) i: []};
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

      // Cache dimensi gambar untuk koordinat overlay yang akurat
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        _imageSizeCache[index] =
            Size(decoded.width.toDouble(), decoded.height.toDouble());
      }

      // Jika filter sudah ter-bake (dari kamera), langsung pakai bytes mentah
      // sebagai preview tanpa apply filter ulang agar tidak double-filter.
      final Uint8List preview;
      if (widget.filterAlreadyBaked) {
        preview = bytes;
      } else {
        preview = await _computeFilter(
            bytes, _activeFilters[index]!, _brightnessMap[index]!.toInt());
      }
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

  Future<void> _applyFilterToActive() async {
    final orig = _originalBytes[_activeIndex];
    if (orig == null) return;
    final preview = await _computeFilter(
        orig, _activeFilters[_activeIndex]!, _brightnessMap[_activeIndex]!.toInt());
    if (mounted) setState(() => _previewBytes[_activeIndex] = preview);
  }

  /// Process filter in an isolate to avoid blocking the UI thread.
  static Future<Uint8List> _computeFilter(
    Uint8List raw, CameraFilter filter, int brightness,
  ) async {
    return compute(_runFilter, _FilterRequest(
      raw: raw, filterId: filter.id, brightness: brightness,
    ));
  }

  // ── FIX Bug 1: hitung Rect gambar aktual di dalam canvas (BoxFit.contain) ──
  // Menggunakan dimensi yang di-cache saat loadPhoto agar bisa dipanggil secara sinkron.
  Rect _computeImageRect(Size canvasSize, [int? index]) {
    final imgSize = _imageSizeCache[index ?? _activeIndex];
    if (imgSize == null || imgSize.width == 0 || imgSize.height == 0) {
      // Fallback: anggap gambar memenuhi canvas
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }

    final canvasAR = canvasSize.width / canvasSize.height;
    final imgAR    = imgSize.width / imgSize.height;

    double renderedW, renderedH;
    if (imgAR > canvasAR) {
      renderedW = canvasSize.width;
      renderedH = canvasSize.width / imgAR;
    } else {
      renderedH = canvasSize.height;
      renderedW = canvasSize.height * imgAR;
    }

    final left = (canvasSize.width  - renderedW) / 2;
    final top  = (canvasSize.height - renderedH) / 2;
    return Rect.fromLTWH(left, top, renderedW, renderedH);
  }

  Future<Uint8List> _renderPhotoWithOverlays(int index) async {
    final baseBytes = _previewBytes[index] ?? _originalBytes[index];
    if (baseBytes == null) {
      return await File(widget.photoPaths[index]).readAsBytes();
    }

    final overlays = _overlaysMap[index] ?? [];
    if (overlays.isEmpty) return baseBytes;

    final codec = await ui.instantiateImageCodec(baseBytes);
    final frame = await codec.getNextFrame();
    final baseImage = frame.image;
    final W = baseImage.width.toDouble();
    final H = baseImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, W, H));
    canvas.drawImage(baseImage, Offset.zero, Paint());

    for (final item in overlays) {
      // canvasSize tersimpan saat overlay ditambahkan; gunakan untuk menghitung
      // imageRect di canvas tersebut. Jika belum ada, fallback ke full gambar.
      final Rect iRect;
      if (item.canvasSize != Size.zero) {
        iRect = _computeImageRect(item.canvasSize, index);
      } else {
        // Fallback: anggap posisi tersimpan dalam koordinat gambar langsung
        iRect = Rect.fromLTWH(0, 0, W, H);
      }

      // Offset posisi relatif terhadap pojok kiri atas imageRect
      final relX = item.position.dx - iRect.left;
      final relY = item.position.dy - iRect.top;

      // Scale ke koordinat gambar asli
      final scaleX = iRect.width  > 0 ? W / iRect.width  : 1.0;
      final scaleY = iRect.height > 0 ? H / iRect.height : 1.0;
      final avgScale = (scaleX + scaleY) / 2;

      final textStyle = ui.TextStyle(
        color: item.type == 'emoji' ? null : item.color,
        fontSize: item.fontSize * avgScale,
        fontFamily: item.fontFamily == 'Default' ? null : item.fontFamily,
        fontWeight: FontWeight.bold,
        shadows: item.type == 'text'
            ? const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))]
            : null,
      );
      final builder = ui.ParagraphBuilder(
          ui.ParagraphStyle(textDirection: TextDirection.ltr))
        ..pushStyle(textStyle)
        ..addText(item.content);
      final para = builder.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
      canvas.drawParagraph(para, Offset(relX * scaleX, relY * scaleY));
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(W.toInt(), H.toInt());
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _saveAndNext() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _selectedOverlayId = null;
    });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final List<String> savedPaths = [];
      final dir = await getApplicationDocumentsDirectory();
      for (int i = 0; i < widget.photoPaths.length; i++) {
        final outPath = p.join(
            dir.path, 'edited_${DateTime.now().millisecondsSinceEpoch}_$i.png');
        final resultBytes = await _renderPhotoWithOverlays(i);
        await File(outPath).writeAsBytes(resultBytes);
        savedPaths.add(outPath);
      }
      if (!mounted) return;
      Navigator.push(
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

  List<OverlayItem> get _currentOverlays => _overlaysMap[_activeIndex] ?? [];

  void _deleteOverlay(String id) {
    setState(() {
      _overlaysMap[_activeIndex]?.removeWhere((o) => o.id == id);
      if (_selectedOverlayId == id) _selectedOverlayId = null;
    });
  }

  // ── FIX Bug 2: update overlay langsung tanpa double-setState ──
  void _updateOverlayDirect(String id, OverlayItem updated) {
    final list = _overlaysMap[_activeIndex];
    if (list == null) return;
    final idx = list.indexWhere((o) => o.id == id);
    if (idx != -1) list[idx] = updated;
  }

  Future<void> _showAddTextDialog({OverlayItem? editing}) async {
    final result = await showModalBottomSheet<_TextOverlayResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => _TextOverlaySheet(editing: editing),
    );

    if (result == null || !mounted) return;

    final cs = _lastCanvasSize;
    setState(() {
      if (editing != null) {
        _updateOverlayDirect(editing.id, editing.copyWith(
          content: result.text,
          color: result.color,
          fontSize: result.fontSize,
          fontFamily: result.fontFamily,
        ));
      } else {
        _overlaysMap[_activeIndex] ??= [];
        _overlaysMap[_activeIndex]!.add(OverlayItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'text',
          content: result.text,
          position: Offset(_lastImageRect.left + 60, _lastImageRect.top + 60),
          color: result.color,
          fontSize: result.fontSize,
          fontFamily: result.fontFamily,
          canvasSize: cs,
        ));
      }
    });
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Column(
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
                  Navigator.pop(sheetCtx);
                  if (!mounted) return;
                  setState(() {
                    final cs = _lastCanvasSize;
                    _overlaysMap[_activeIndex] ??= [];
                    _overlaysMap[_activeIndex]!.add(OverlayItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: 'emoji',
                      content: _emojiList[i],
                      // posisi awal di tengah imageRect
                      position: Offset(
                        _lastImageRect.left + _lastImageRect.width  / 2 - 20,
                        _lastImageRect.top  + _lastImageRect.height / 2 - 20,
                      ),
                      fontSize: 40,
                      canvasSize: cs,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
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
                      color: kPrimary),
                  tooltip: 'Selesai edit, pilih frame',
                  onPressed: _saveAndNext,
                ),
        ],
      ),
      body: Column(
        children: [
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
                  color: isActive ? kPrimary : Colors.white24,
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
                  if (overlayCount > 0)
                    Positioned(
                      top: 2, right: 2,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                          color: kPrimary,
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
          child: CircularProgressIndicator(color: kPrimary));
    }
    if (bytes == null) {
      return const Center(
          child: Text('Gagal memuat foto',
              style: TextStyle(color: Colors.red)));
    }

    return GestureDetector(
      key: ValueKey(_activeIndex),
      onTap: () => setState(() => _selectedOverlayId = null),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          _lastCanvasSize = canvasSize;
          // ── FIX Bug 1: hitung imageRect setiap frame ──
          _lastImageRect = _computeImageRect(canvasSize);

          return Stack(
            alignment: Alignment.center,
            children: [
              Image.memory(bytes, fit: BoxFit.contain),
              ..._currentOverlays.map((item) => _buildDraggableOverlay(item)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDraggableOverlay(OverlayItem item) {
    final isSelected = _selectedOverlayId == item.id;

    return _DraggableOverlayWrapper(
      key: ValueKey(item.id),
      item: item,
      isSelected: isSelected,
      onTap: () => setState(() {
        _selectedOverlayId = isSelected ? null : item.id;
      }),
      // Dipanggil HANYA saat drag/scale selesai (finger up) — setState mahal
      onDragEnd: (updatedItem) {
        _updateOverlayDirect(item.id, updatedItem);
        setState(() {}); // rebuild sekali saat selesai
      },
      onDelete: () => _deleteOverlay(item.id),
      onEdit: item.type == 'text'
          ? () => _showAddTextDialog(editing: item)
          : null,
    );
  }

  Widget _buildSelectedLayerPanel() {
    final list = _currentOverlays;
    if (list.isEmpty) return const SizedBox.shrink();
    final selId = _selectedOverlayId;
    if (selId == null) return const SizedBox.shrink();
    final idx = list.indexWhere((o) => o.id == selId);
    if (idx == -1) return const SizedBox.shrink();
    final item = list[idx];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  item.type == 'emoji' ? item.content : '"${item.content}"',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: item.type == 'emoji' ? 22 : 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.type == 'text')
                TextButton.icon(
                  onPressed: () => _showAddTextDialog(editing: item),
                  icon: const Icon(Icons.edit, size: 14, color: kPrimary),
                  label: const Text('Edit',
                      style: TextStyle(color: kPrimary, fontSize: 12)),
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
          // Slider ukuran
          Row(
            children: [
              const Icon(Icons.text_decrease, color: Colors.white54, size: 14),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 2,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: kPrimary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: item.fontSize.clamp(10.0, 120.0),
                    min: 10, max: 120,
                    onChanged: (v) {
                      setState(() => list[idx] = item.copyWith(fontSize: v));
                    },
                  ),
                ),
              ),
              const Icon(Icons.text_increase, color: Colors.white54, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 96,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: kAppFilters.map((f) {
            final isActive = (_activeFilters[_activeIndex] ?? kAppFilters.first).id == f.id;
            return GestureDetector(
              onTap: () {
                setState(() => _activeFilters[_activeIndex] = f);
                _applyFilterToActive();
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
          }).toList(),
        ),
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
              value: _brightnessMap[_activeIndex] ?? 0,
              min: -100, max: 100, divisions: 200,
              activeColor: kPrimary,
              inactiveColor: Colors.white24,
              onChanged: (v) => setState(() => _brightnessMap[_activeIndex] = v),
              onChangeEnd: (_) => _applyFilterToActive(),
            ),
          ),
          const Icon(Icons.brightness_high,
              color: kPrimary, size: 20),
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

// ─────────────────────────────────────────────────────────────────────────────
// _DraggableOverlayWrapper
// Menggunakan local state untuk drag/scale → hanya widget ini yang rebuild
// setiap frame, bukan seluruh canvas. setState parent dipanggil SEKALI
// saat finger diangkat (onDragEnd) untuk sync ke model.
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableOverlayWrapper extends StatefulWidget {
  final OverlayItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(OverlayItem updated) onDragEnd;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const _DraggableOverlayWrapper({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onDragEnd,
    required this.onDelete,
    this.onEdit,
  });

  @override
  State<_DraggableOverlayWrapper> createState() => _DraggableOverlayWrapperState();
}

class _DraggableOverlayWrapperState extends State<_DraggableOverlayWrapper> {
  late Offset _pos;
  late double _fontSize;
  double _fontSizeAtStart = 28.0;
  Offset _lastFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pos = widget.item.position;
    _fontSize = widget.item.fontSize;
  }

  @override
  void didUpdateWidget(_DraggableOverlayWrapper old) {
    super.didUpdateWidget(old);
    if (old.item.position != widget.item.position) _pos = widget.item.position;
    if (old.item.fontSize != widget.item.fontSize) _fontSize = widget.item.fontSize;
  }

  void _commitToParent() {
    widget.onDragEnd(widget.item.copyWith(position: _pos, fontSize: _fontSize));
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final item = widget.item;

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: (details) {
          _fontSizeAtStart = _fontSize;
          _lastFocalPoint = details.localFocalPoint;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              final delta = details.localFocalPoint - _lastFocalPoint;
              _pos = _pos + delta;
              _lastFocalPoint = details.localFocalPoint;
            }
            if (details.pointerCount >= 2) {
              _fontSize = (_fontSizeAtStart * details.scale).clamp(10.0, 120.0);
            }
          });
        },
        onScaleEnd: (_) => _commitToParent(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? kPrimary
                      : Colors.white.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.content,
                style: TextStyle(
                  fontSize: _fontSize,
                  color: item.type == 'emoji' ? null : item.color,
                  fontFamily: item.fontFamily == 'Default' ? null : item.fontFamily,
                  fontWeight: FontWeight.bold,
                  shadows: item.type == 'text'
                      ? const [Shadow(color: Colors.black54, blurRadius: 4,
                          offset: Offset(1, 1))]
                      : null,
                ),
              ),
            ),
            if (isSelected) ...[
              Positioned(
                top: -10, right: -10,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
              if (widget.onEdit != null)
                Positioned(
                  top: -10, left: -10,
                  child: GestureDetector(
                    onTap: widget.onEdit,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: kPrimary, shape: BoxShape.circle),
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
    final c = color ?? kPrimary;
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

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS hasil dialog teks
// ─────────────────────────────────────────────────────────────────────────────

class _TextOverlayResult {
  final String text;
  final Color color;
  final double fontSize;
  final String fontFamily;
  const _TextOverlayResult({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _TextOverlaySheet
// ─────────────────────────────────────────────────────────────────────────────

class _TextOverlaySheet extends StatefulWidget {
  final OverlayItem? editing;
  const _TextOverlaySheet({this.editing});

  @override
  State<_TextOverlaySheet> createState() => _TextOverlaySheetState();
}

class _TextOverlaySheetState extends State<_TextOverlaySheet> {
  late TextEditingController _ctrl;
  late Color _color;
  late String _font;
  late double _size;

  static const _fontFamilies = ['Default', 'Serif', 'Monospace', 'Cursive', 'Fantasy'];
  static const _textColors = [
    Colors.white, Colors.black, Colors.yellow, Colors.red,
    Colors.cyan, Colors.green, Color(0xFFFF69B4), kPrimary,
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _ctrl = TextEditingController(text: e?.content ?? '');
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    _color = e?.color ?? Colors.white;
    _font = e?.fontFamily ?? 'Default';
    _size = e?.fontSize ?? 28;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
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
              widget.editing != null ? 'Edit Teks' : 'Tambah Teks',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _ctrl.text.isEmpty ? 'Preview teks...' : _ctrl.text,
                style: TextStyle(
                  fontFamily: _font == 'Default' ? null : _font,
                  fontSize: _size.clamp(14.0, 36.0),
                  color: _ctrl.text.isEmpty ? Colors.grey : _color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: widget.editing == null,
              controller: _ctrl,
              onChanged: (_) => setState(() {}),
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
            const Text('Warna Teks',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _textColors.map((c) {
                  final isSel = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      width: isSel ? 36 : 30,
                      height: isSel ? 36 : 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? kPrimary : Colors.grey.shade300,
                          width: isSel ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Jenis Font',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _fontFamilies.map((font) {
                  final isSel = _font == font;
                  return GestureDetector(
                    onTap: () => setState(() => _font = font),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? kPrimary : const Color(0xFFEEEDF8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        font,
                        style: TextStyle(
                          fontFamily: font == 'Default' ? null : font,
                          color: isSel ? Colors.white : kPrimary,
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
            const Text('Ukuran',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Slider(
              value: _size,
              min: 14, max: 64, divisions: 25,
              activeColor: kPrimary,
              label: _size.toInt().toString(),
              onChanged: (v) => setState(() => _size = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary),
                onPressed: () {
                  final t = _ctrl.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(context, _TextOverlayResult(
                    text: t,
                    color: _color,
                    fontSize: _size,
                    fontFamily: _font,
                  ));
                },
                child: Text(widget.editing != null ? 'Simpan' : 'Tambahkan',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
