import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/photo_state.dart';

class EmailScreen extends StatefulWidget {
  final String? preSelectedPhotoPath;

  const EmailScreen({super.key, this.preSelectedPhotoPath});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController(
    text: 'Foto dari Photopedia',
  );
  final _bodyController = TextEditingController(
    text: 'Halo,\nBerikut foto yang diambil dari Photopedia\n\nSemoga menyukainya!\n\nSalam,\nPhotopedia App',
  );
  final _senderEmailController = TextEditingController();
  final _senderPasswordController = TextEditingController();

  String? _attachedPhotoPath;
  bool _isSending = false;
  bool _showSmtpConfig = false;

  @override
  void initState() {
    super.initState();
    _attachedPhotoPath = widget.preSelectedPhotoPath;
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _senderEmailController.dispose();
    _senderPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_toController.text.trim().isEmpty) {
      _showSnack('Masukkan alamat email tujuan', isError: true);
      return;
    }
    if (_senderEmailController.text.trim().isEmpty ||
        _senderPasswordController.text.trim().isEmpty) {
      setState(() => _showSmtpConfig = true);
      _showSnack('Lengkapi konfigurasi email pengirim', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      final smtpServer = gmail(
        _senderEmailController.text.trim(),
        _senderPasswordController.text.trim(),
      );

      final message = Message()
        ..from = Address(
            _senderEmailController.text.trim(), 'Photopedia App')
        ..recipients.add(_toController.text.trim())
        ..subject = _subjectController.text
        ..text = _bodyController.text;

      if (_attachedPhotoPath != null) {
        message.attachments.add(
          FileAttachment(File(_attachedPhotoPath!))
            ..location = Location.attachment,
        );
      }

      await send(message, smtpServer);
      _showSnack('Email berhasil dikirim! 🎉');
    } on MailerException catch (e) {
      _showSnack('Gagal mengirim: ${e.message}', isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : const Color(0xFF6B4EFF),
    ));
  }

  void _pickPhoto() {
    final state = AppStateScope.of(context);
    if (state.photos.isEmpty) {
      _showSnack('Belum ada foto di galeri', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Foto',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: state.photos.length,
                itemBuilder: (ctx, i) {
                  final photo = state.photos[i];
                  final isSelected = _attachedPhotoPath == photo.path;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _attachedPhotoPath = photo.path);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF6B4EFF), width: 3)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      appBar: AppBar(
        title: const Text('Kirim Email'),
        centerTitle: false,
        leading: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.menu_rounded, color: Color(0xFF6B4EFF)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SMTP Config toggle
            GestureDetector(
              onTap: () => setState(() => _showSmtpConfig = !_showSmtpConfig),
              child: Row(
                children: [
                  const Icon(Icons.settings_rounded,
                      color: Color(0xFF6B4EFF), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Konfigurasi Email Pengirim',
                    style: TextStyle(
                        color: Color(0xFF6B4EFF),
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(
                    _showSmtpConfig
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF6B4EFF),
                  ),
                ],
              ),
            ),
            if (_showSmtpConfig) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _senderEmailController,
                label: 'Gmail Pengirim',
                hint: 'emailkamu@gmail.com',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _senderPasswordController,
                label: 'App Password Gmail',
                hint: 'xxxx xxxx xxxx xxxx',
                icon: Icons.lock_outlined,
                obscure: true,
              ),
              const SizedBox(height: 4),
              const Text(
                '* Gunakan App Password dari Google Account, bukan password biasa.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 20),

            // To field
            _buildTextField(
              controller: _toController,
              label: 'Kepada',
              hint: 'nama@gmail.com',
              icon: Icons.person_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            // Subject field
            _buildTextField(
              controller: _subjectController,
              label: 'Subjek',
              hint: 'Tulis subjek email...',
              icon: Icons.subject_rounded,
            ),
            const SizedBox(height: 14),

            // Body field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _bodyController,
                maxLines: 6,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'Tulis pesan...',
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Attachment
            const Text(
              'Lampiran',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD8D0FF)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _attachedPhotoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_attachedPhotoPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.attach_file_rounded,
                              color: Color(0xFF6B4EFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedPhotoPath != null
                                ? _attachedPhotoPath!.split('/').last
                                : 'Ketuk untuk pilih foto',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2D2D),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_attachedPhotoPath != null)
                            Text(
                              _getFileSize(_attachedPhotoPath!),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (_attachedPhotoPath != null)
                      IconButton(
                        onPressed: () =>
                            setState(() => _attachedPhotoPath = null),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.grey, size: 18),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendEmail,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Mengirim...' : 'Kirim'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF6B4EFF), size: 20),
          labelStyle: const TextStyle(color: Color(0xFF6B4EFF), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  String _getFileSize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }
}
