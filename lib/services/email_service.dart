import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Ganti dengan API key kamu dari dashboard Resend
  static const String _apiKey = 're_7YKHVBpZ_MLu21t2f6UvxW2JQPsS4PGE8';

  // Mode test: pakai onboarding@resend.dev
  // Mode production: pakai email domain kamu sendiri
  static const String _fromEmail = 'onboarding@resend.dev';
  static const String _fromName = 'Photopedia App';

  static const String _apiUrl = 'https://api.resend.com/emails';

  /// Kirim email dengan lampiran foto.
  /// [photoBytes] adalah bytes mentah file foto (bukan dataURL).
  static Future<void> sendPhotoEmail({
    required String toName,
    required String toEmail,
    List<int>? photoBytes,
    String? photoFileName,
  }) async {
    // Bangun body request
    final Map<String, dynamic> payload = {
      'from': '$_fromName <$_fromEmail>',
      'to': [toEmail],
      'subject': 'Foto dari Photopedia',
      'text':
          'Halo $toName,\n\nBerikut foto yang diambil dari Photopedia.\nSemoga menyukainya!\n\nSalam,\nPhotopedia App',
    };

    // Tambah attachment jika ada foto
    if (photoBytes != null) {
      payload['attachments'] = [
        {
          'filename': photoFileName ?? 'foto_photopedia.jpg',
          // Resend butuh base64 murni, tanpa prefix "data:image/..."
          'content': base64Encode(photoBytes),
        }
      ];
    }

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw const EmailServiceException(
            'Koneksi timeout. Periksa jaringan kamu.',
          ),
        );

    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw EmailServiceException(
        body['message'] ?? 'Gagal mengirim email (${response.statusCode})',
      );
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