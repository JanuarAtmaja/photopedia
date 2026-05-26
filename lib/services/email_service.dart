import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// EmailService menggunakan Gmail API via HTTP (REST).
///
/// CARA SETUP:
/// 1. Buka console.cloud.google.com → buat project
/// 2. Aktifkan Gmail API
/// 3. Buat OAuth2 credentials (type: Web Application)
/// 4. Isi _clientId, _clientSecret, _refreshToken di bawah
///
/// Atau gunakan EmailJS (tidak perlu backend):
/// 1. Daftar di emailjs.com
/// 2. Buat Email Service (Gmail) + Email Template
/// 3. Isi _emailJsServiceId, _emailJsTemplateId, _emailJsPublicKey
class EmailService {
  // ── EmailJS credentials (lebih mudah, tanpa OAuth) ───────────────────────
  // Daftar gratis di https://www.emailjs.com
  static const String _emailJsServiceId  = 'YOUR_SERVICE_ID';
  static const String _emailJsTemplateId = 'YOUR_TEMPLATE_ID';
  static const String _emailJsPublicKey  = 'YOUR_PUBLIC_KEY';

  static const String _emailJsUrl =
      'https://api.emailjs.com/api/v1.0/email/send';

  /// Kirim email via EmailJS REST API.
  /// Tidak memerlukan SMTP langsung dari device — tidak ada masalah
  /// SocketException / Failed host lookup.
  static Future<void> sendPhotoEmail({
    required String toName,
    required String toEmail,
    Uint8List? photoBytes,
    String? photoFileName,
    String subject = 'Foto dari Photopedia',
    String? body,
  }) async {
    final emailBody = body ??
        'Halo $toName,\n\n'
        'Berikut foto yang diambil dari Photopedia.\n'
        'Semoga menyukainya!\n\n'
        'Salam,\nPhotopedia App';

    // Encode foto ke base64 jika ada
    String? base64Photo;
    if (photoBytes != null) {
      base64Photo = base64Encode(photoBytes);
    }

    final payload = {
      'service_id': _emailJsServiceId,
      'template_id': _emailJsTemplateId,
      'user_id': _emailJsPublicKey,
      'template_params': {
        'to_name': toName,
        'to_email': toEmail,
        'subject': subject,
        'message': emailBody,
        if (base64Photo != null) 'photo_base64': base64Photo,
        if (photoFileName != null) 'photo_filename': photoFileName,
      },
    };

    try {
      final response = await http
          .post(
            Uri.parse(_emailJsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return;

      // Tangani error HTTP
      if (response.statusCode == 400) {
        throw const EmailServiceException(
          'Konfigurasi EmailJS tidak valid. '
          'Pastikan Service ID, Template ID, dan Public Key sudah benar.',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const EmailServiceException(
          'Akses EmailJS ditolak. Periksa Public Key kamu.',
        );
      } else {
        throw EmailServiceException(
            'Gagal mengirim email. Status: ${response.statusCode}');
      }
    } on EmailServiceException {
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('failed host') ||
          msg.contains('network')) {
        throw const EmailServiceException(
          'Tidak ada koneksi internet. Periksa jaringan kamu.',
        );
      } else if (msg.contains('timeout') || msg.contains('timed out')) {
        throw const EmailServiceException(
          'Koneksi timeout. Periksa jaringan internet kamu.',
        );
      }
      throw EmailServiceException('Terjadi kesalahan: $e');
    }
  }

  /// Validasi format email.
  static bool isValidEmail(String email) {
    final regex =
        RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }
}

class EmailServiceException implements Exception {
  final String message;
  const EmailServiceException(this.message);

  @override
  String toString() => message;
}
