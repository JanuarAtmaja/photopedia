import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/photo_state.dart';
import '../services/email_service.dart';
import '../services/analytics_service.dart';
import '../main.dart';

class EmailScreen extends StatefulWidget {
  final String? preSelectedPhotoPath;

  const EmailScreen({super.key, this.preSelectedPhotoPath});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _nameController = TextEditingController();
  final _toController = TextEditingController();
  final _subjectController =
      TextEditingController(text: 'Foto dari Photopedia');
  final _bodyController = TextEditingController(
    text:
        'Halo,\nBerikut foto yang diambil dari Photopedia\n\nSemoga menyukainya!\n\nSalam,\nPhotopedia App',
  );

  String? _attachedPhotoPath;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _attachedPhotoPath = widget.preSelectedPhotoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String? _validateFields() {
    final name = _nameController.text.trim();
    final email = _toController.text.trim();
    final subject = _subjectController.text.trim();

    if (name.isEmpty) return 'Nama penerima tidak boleh kosong.';
    if (email.isEmpty) return 'Alamat email tujuan tidak boleh kosong.';
    if (!EmailService.isValidEmail(email)) return 'Format email tidak valid.';
    if (subject.isEmpty) return 'Subjek email tidak boleh kosong.';
    return null;
  }

  Future<void> _sendEmail() async {
    final error = _validateFields();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      Uint8List? photoBytes;
      String? photoFileName;
      if (_attachedPhotoPath != null) {
        photoBytes = await File(_attachedPhotoPath!).readAsBytes();
        photoFileName = _attachedPhotoPath!.split('/').last;
      }

      await EmailService.sendPhotoEmail(
        toName: _nameController.text.trim(),
        toEmail: _toController.text.trim(),
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
        photoBytes: photoBytes,
        photoFileName: photoFileName,
      );

      // ─── Catat ke analitik: foto berhasil dikirim ──────────────────────
      if (!mounted) return;
      final state = AppStateScope.of(context);
      String? photoId;
      if (_attachedPhotoPath != null) {
        try {
          photoId = state.photos
              .firstWhere((p) => p.path == _attachedPhotoPath)
              .id;
        } catch (_) {}
      }
      await AnalyticsService.instance.logPhotoSent(photoId: photoId);

      if (mounted) _showStatusModal(success: true);
    } on EmailServiceException catch (e) {
      if (mounted) _showStatusModal(success: false, errorMessage: e.message);
    } catch (e) {
      if (mounted) {
        _showStatusModal(success: false, errorMessage: 'Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showStatusModal({required bool success, String? errorMessage}) {
    final isDark = ThemeModeScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? kSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StatusModal(
        success: success,
        toEmail: _toController.text.trim(),
        errorMessage: errorMessage,
        onClose: () => Navigator.pop(context),
        onRetry: success
            ? null
            : () {
                Navigator.pop(context);
                _sendEmail();
              },
      ),
    );
  }

  void _pickPhoto() {
    final isDark = ThemeModeScope.of(context);
    final state = AppStateScope.of(context);
    if (state.photos.isEmpty) {
      _showSnack('Galeri kosong.', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? kSurfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(20),
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
            const Text('Pilih Foto Lampiran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: state.photos.length,
                itemBuilder: (ctx, i) {
                  final photo = state.photos[i];
                  final isSelected = _attachedPhotoPath == photo.path;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _attachedPhotoPath = photo.path);
                      Navigator.pop(sheetCtx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 95,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: kPrimary, width: 3)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(photo.path), fit: BoxFit.cover,
                          cacheWidth: 200),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : kPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeModeScope.of(context);
    final bg = isDark ? kBackgroundDark : kBackground;
    final fieldBg = isDark ? kSurfaceDark : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      drawer: buildAppDrawer(context, currentRoute: 'email'),
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Kirim Email'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: kPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: kPrimary),
            tooltip: 'Ke Beranda',
            onPressed: () => Navigator.of(context)
                .popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nama Penerima',
              hint: 'Budi Santoso',
              icon: Icons.person_outline_rounded,
              fieldBg: fieldBg,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _toController,
              label: 'Kepada',
              hint: 'nama@gmail.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              fieldBg: fieldBg,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _subjectController,
              label: 'Subjek',
              hint: 'Tulis subjek...',
              icon: Icons.subject_rounded,
              fieldBg: fieldBg,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _attachedPhotoPath != null ? kPrimary : (isDark ? Colors.white12 : Colors.grey.shade200),
                    width: _attachedPhotoPath != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachedPhotoPath != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                      color: _attachedPhotoPath != null ? kPrimary : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachedPhotoPath != null
                            ? 'Foto Terlampir ✓'
                            : 'Pilih foto lampiran',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _attachedPhotoPath != null ? kPrimary : null,
                          fontWeight: _attachedPhotoPath != null ? FontWeight.w500 : null,
                        ),
                      ),
                    ),
                    if (_attachedPhotoPath != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _attachedPhotoPath = null),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.grey, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendEmail,
                icon: _isSending
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
                label: Text(_isSending ? 'Mengirim...' : 'Kirim Email'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Color fieldBg,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !_isSending,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: kPrimary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _StatusModal extends StatelessWidget {
  final bool success;
  final String toEmail;
  final String? errorMessage;
  final VoidCallback onClose;
  final VoidCallback? onRetry;

  const _StatusModal({
    required this.success,
    required this.toEmail,
    required this.onClose,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: (success ? Colors.green : Colors.red).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 40,
              color: success ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Text(success ? 'Berhasil!' : 'Gagal',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            success
                ? 'Email berhasil dikirim ke $toEmail.'
                : (errorMessage ?? 'Gagal mengirim.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Ulangi'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}