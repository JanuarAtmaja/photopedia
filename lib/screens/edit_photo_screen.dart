import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/photo_state.dart';
import 'preview_screen.dart';

const _kFilters = [
  {'name': 'Asli', 'matrix': null},
  {'name': 'B&W', 'matrix': 'bw'},
  {'name': 'Blur', 'matrix': 'blur'},
  {'name': 'Warm', 'matrix': 'warm'},
  {'name': 'Cool', 'matrix': 'cool'},
  {'name': 'Vivid', 'matrix': 'vivid'},
];

class EditPhotoScreen extends StatefulWidget {
  final String photoPath;
  final bool isEditing;

  const EditPhotoScreen({
    super.key,
    required this.photoPath,
    this.isEditing = false,
  });

  @override
  State<EditPhotoScreen> createState() => _EditPhotoScreenState();
}

class _EditPhotoScreenState extends State<EditPhotoScreen> {
  int _selectedTab = 0; // 0=Sesuaikan, 1=Filter, 2=Bingkai, 3=Teks, 4=Stiker
  String? _selectedFilter;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  String? _selectedFrame;
  bool _isSaving = false;

  final List<String> _tabs = ['Sesuaikan', 'Filter', 'Bingkai', 'Teks', 'Stiker'];

  ColorFilter? _buildColorFilter() {
    if (_selectedFilter == 'bw') {
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    } else if (_selectedFilter == 'warm') {
      return const ColorFilter.matrix([
        1.2, 0, 0, 0, 20,
        0, 1.0, 0, 0, 5,
        0, 0, 0.8, 0, -10,
        0, 0, 0, 1, 0,
      ]);
    } else if (_selectedFilter == 'cool') {
      return const ColorFilter.matrix([
        0.8, 0, 0, 0, -10,
        0, 1.0, 0, 0, 5,
        0, 0, 1.3, 0, 20,
        0, 0, 0, 1, 0,
      ]);
    } else if (_selectedFilter == 'vivid') {
      return const ColorFilter.matrix([
        1.4, -0.1, -0.1, 0, 0,
        -0.1, 1.4, -0.1, 0, 0,
        -0.1, -0.1, 1.4, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    }
    // Apply brightness/contrast/saturation without filter
    final b = _brightness / 100 * 128;
    final c = (_contrast + 100) / 100;
    final s = (_saturation + 100) / 100;
    // Saturation matrix
    final sr = (1 - s) * 0.2126;
    final sg = (1 - s) * 0.7152;
    final sb = (1 - s) * 0.0722;
    return ColorFilter.matrix([
      (sr + s) * c, sg * c, sb * c, 0, b + 128 * (1 - c),
      sr * c, (sg + s) * c, sb * c, 0, b + 128 * (1 - c),
      sr * c, sg * c, (sb + s) * c, 0, b + 128 * (1 - c),
      0, 0, 0, 1, 0,
    ]);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      // In a real app, use image package to apply filters to file
      // For this demo, we just navigate to preview
      final state = AppStateScope.of(context);
      // Find the photo that matches the path
      final photo = state.photos.firstWhere(
        (ph) => ph.path == widget.photoPath,
        orElse: () => state.photos.first,
      );
      state.updatePhotoFilter(photo.id, _selectedFilter);
      state.updatePhotoAdjustments(photo.id, _brightness, _contrast, _saturation);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(photoPath: widget.photoPath),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FF),
        title: const Text('Edit Foto'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {},
          color: const Color(0xFF6B4EFF),
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
          // Photo preview with filter applied
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: _buildColorFilter() ??
                          const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ),
                      child: Image.file(
                        File(widget.photoPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    // Frame overlay
                    if (_selectedFrame != null)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedFrame == 'white'
                                  ? Colors.white
                                  : _selectedFrame == 'black'
                                      ? Colors.black
                                      : const Color(0xFF6B4EFF),
                              width: 12,
                            ),
                          ),
                        ),
                      ),
                    // Navigation arrows
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 30),
                        onPressed: () {},
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white, size: 30),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab row
          Container(
            color: Colors.white,
            child: Row(
              children: _tabs
                  .asMap()
                  .entries
                  .map((e) => Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == e.key
                                      ? const Color(0xFF6B4EFF)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedTab == e.key
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _selectedTab == e.key
                                    ? const Color(0xFF6B4EFF)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Tab content
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildTabContent(),
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Perubahan'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildAdjustTab();
      case 1:
        return _buildFilterTab();
      case 2:
        return _buildFrameTab();
      case 3:
        return _buildTextTab();
      case 4:
        return _buildStickerTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAdjustTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _AdjustSlider(
            label: 'Kecerahan',
            value: _brightness,
            onChanged: (v) => setState(() => _brightness = v),
          ),
          _AdjustSlider(
            label: 'Kontras',
            value: _contrast,
            onChanged: (v) => setState(() => _contrast = v),
          ),
          _AdjustSlider(
            label: 'Saturasi',
            value: _saturation,
            onChanged: (v) => setState(() => _saturation = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: _kFilters.map((f) {
        final filterKey = f['matrix'] as String?;
        final isSelected = _selectedFilter == filterKey;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilter = filterKey),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF6B4EFF), width: 2.5)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColorFiltered(
                      colorFilter: filterKey != null
                          ? (_getFilterForPreview(filterKey) ??
                              const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply))
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.multiply),
                      child: Image.file(
                        File(widget.photoPath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  f['name'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? const Color(0xFF6B4EFF)
                        : Colors.grey,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  ColorFilter? _getFilterForPreview(String key) {
    switch (key) {
      case 'bw':
        return const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      case 'warm':
        return const ColorFilter.matrix([
          1.2, 0, 0, 0, 20,
          0, 1.0, 0, 0, 5,
          0, 0, 0.8, 0, -10,
          0, 0, 0, 1, 0,
        ]);
      case 'cool':
        return const ColorFilter.matrix([
          0.8, 0, 0, 0, -10,
          0, 1.0, 0, 0, 5,
          0, 0, 1.3, 0, 20,
          0, 0, 0, 1, 0,
        ]);
      case 'vivid':
        return const ColorFilter.matrix([
          1.4, -0.1, -0.1, 0, 0,
          -0.1, 1.4, -0.1, 0, 0,
          -0.1, -0.1, 1.4, 0, 0,
          0, 0, 0, 1, 0,
        ]);
      default:
        return null;
    }
  }

  Widget _buildFrameTab() {
    final frames = [
      {'label': 'Tanpa', 'color': Colors.grey.shade200, 'key': null},
      {'label': 'Putih', 'color': Colors.white, 'key': 'white'},
      {'label': 'Hitam', 'color': Colors.black, 'key': 'black'},
      {'label': 'Ungu', 'color': const Color(0xFF6B4EFF), 'key': 'purple'},
      {'label': 'Pink', 'color': Colors.pink.shade200, 'key': 'pink'},
    ];
    return ListView(
      scrollDirection: Axis.horizontal,
      children: frames.map((f) {
        final key = f['key'] as String?;
        final isSelected = _selectedFrame == key;
        return GestureDetector(
          onTap: () => setState(() => _selectedFrame = key),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF6B4EFF), width: 2.5)
                        : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: key != null
                            ? Border.all(color: f['color'] as Color, width: 4)
                            : null,
                        color: key == null ? Colors.grey.shade100 : null,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(f['label'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.text_fields_rounded,
              color: Color(0xFF6B4EFF), size: 36),
          const SizedBox(height: 8),
          const Text('Ketuk untuk menambahkan teks ke foto',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _showAddTextDialog(),
            child: const Text('Tambah Teks'),
          ),
        ],
      ),
    );
  }

  void _showAddTextDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Teks'),
        content: const TextField(
          decoration: InputDecoration(hintText: 'Tulis teks disini...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tambah')),
        ],
      ),
    );
  }

  Widget _buildStickerTab() {
    final stickers = ['😊', '❤️', '⭐', '🌟', '✨', '🎉', '🌸', '🦋', '🌈', '🎨'];
    return GridView.count(
      crossAxisCount: 5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stickers
          .map((s) => GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(s, style: const TextStyle(fontSize: 24))),
                ),
              ))
          .toList(),
    );
  }
}

class _AdjustSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _AdjustSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A4A6A))),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFF6B4EFF),
                thumbColor: const Color(0xFF6B4EFF),
                inactiveTrackColor: const Color(0xFFD8D0FF),
                overlayColor: const Color(0xFF6B4EFF).withOpacity(0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                min: -100,
                max: 100,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              (value >= 0 ? '+' : '') + value.round().toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B4EFF),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
