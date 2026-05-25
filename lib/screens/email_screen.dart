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
        photoBytes: photoBytes,
        photoFileName: photoFileName,
      );

      // ─── Catat ke analitik: foto berhasil dikirim ──────────────────────
      if (!mounted) return;
      // Cache state sebelum await agar tidak ada async gap
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
    final state = AppStateScope.of(context);
    if (state.photos.isEmpty) {
      _showSnack('Galeri kosong.', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Foto Lampiran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF6B4EFF), width: 3)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(photo.path), fit: BoxFit.cover),
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
      backgroundColor:
          isError ? Colors.red.shade600 : const Color(0xFF6B4EFF),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text('Kirim Email'),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () =>
              MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            color: const Color(0xFF6B4EFF),
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nama Penerima',
              hint: 'Budi Santoso',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _toController,
              label: 'Kepada',
              hint: 'nama@gmail.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _subjectController,
              label: 'Subjek',
              hint: 'Tulis subjek...',
              icon: Icons.subject_rounded,
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD8D0FF)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded,
                        color: Color(0xFF6B4EFF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachedPhotoPath != null
                            ? 'Foto Terlampir ✓'
                            : 'Pilih foto lampiran',
                        overflow: TextOverflow.ellipsis,
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
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendEmail,
                child: Text(_isSending ? 'Mengirim...' : 'Kirim Email'),
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
  }) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !_isSending,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF6B4EFF), size: 20),
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 70,
            color: success ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(success ? 'Berhasil!' : 'Gagal',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            success
                ? 'Email terkirim ke $toEmail.'
                : (errorMessage ?? 'Gagal mengirim.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: onClose, child: const Text('Tutup'))),
              if (onRetry != null) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                        onPressed: onRetry, child: const Text('Ulangi'))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
