import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/photo_state.dart';
import 'edit_photo_screen.dart';
import 'email_screen.dart';

class PreviewScreen extends StatelessWidget {
  final String photoPath;

  const PreviewScreen({super.key, required this.photoPath});

  String _getFileSize() {
    try {
      final file = File(photoPath);
      final bytes = file.lengthSync();
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);

    // Find applied filter
    PhotoItem? photo;
    try {
      photo = state.photos.firstWhere((p) => p.path == photoPath);
    } catch (_) {}

    ColorFilter? filter;
    if (photo?.appliedFilter == 'bw') {
      filter = const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    } else if (photo?.appliedFilter == 'warm') {
      filter = const ColorFilter.matrix([
        1.2, 0, 0, 0, 20,
        0, 1.0, 0, 0, 5,
        0, 0, 0.8, 0, -10,
        0, 0, 0, 1, 0,
      ]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5FF),
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          color: const Color(0xFF6B4EFF),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF6B4EFF),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Photo preview
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B4EFF).withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: filter != null
                      ? ColorFiltered(
                          colorFilter: filter,
                          child: Image.file(
                            File(photoPath),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Metadata row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (photo?.appliedFilter != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4EFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _filterName(photo?.appliedFilter),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '+Filter',
                        style: TextStyle(
                            color: Color(0xFF6B4EFF), fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${_getFileSize()}  JPEG',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Diambil hari ini, $timeStr',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmailScreen(
                        preSelectedPhotoPath: photoPath,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.email_rounded),
                label: const Text('Simpan & Kirim Email'),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Foto disimpan ke galeri!'),
                          backgroundColor: Color(0xFF6B4EFF),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6B4EFF)),
                      foregroundColor: const Color(0xFF6B4EFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditPhotoScreen(photoPath: photoPath, isEditing: true),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Edit Ulang'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _filterName(String? filter) {
    switch (filter) {
      case 'bw':
        return 'B&W';
      case 'warm':
        return 'Warm';
      case 'cool':
        return 'Cool';
      case 'vivid':
        return 'Vivid';
      default:
        return filter ?? 'Filter';
    }
  }
}
