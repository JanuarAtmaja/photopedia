import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

/// EmailService menggunakan SMTP Gmail + App Password.
///
/// Kredensial dibaca dari file .env (TIDAK di-commit ke git).
/// Salin .env.example → .env lalu isi GMAIL_USER dan GMAIL_APP_PASSWORD.
class EmailService {
  // ── Gmail credentials — dibaca dari .env ────────────────────────────────
  static String get _gmailUser =>
      dotenv.env['GMAIL_USER'] ?? (throw const EmailServiceException(
        'GMAIL_USER tidak ditemukan di .env',
      ));

  static String get _appPassword =>
      dotenv.env['GMAIL_APP_PASSWORD'] ?? (throw const EmailServiceException(
        'GMAIL_APP_PASSWORD tidak ditemukan di .env',
      ));

  /// Kirim email via SMTP Gmail dengan attachment foto opsional.
  static Future<void> sendPhotoEmail({
    required String toName,
    required String toEmail,
    Uint8List? photoBytes,
    String? photoFileName,
    String subject = 'Foto dari Photopedia',
    String? body,
  }) async {
    final smtpServer = gmail(_gmailUser, _appPassword);

    final emailBody = body ??
        'Halo $toName,\n\n'
        'Berikut foto yang diambil dari Photopedia.\n'
        'Semoga menyukainya!\n\n'
        'Salam,\nPhotopedia App';

    final message = Message()
      ..from = Address(_gmailUser, 'Photopedia App')
      ..recipients.add(toEmail)
      ..subject = subject
      ..text = emailBody;

    if (photoBytes != null && photoFileName != null) {
      message.attachments.add(
        StreamAttachment(
          Stream.fromIterable([photoBytes]),
          'image/jpeg',
          fileName: photoFileName,
        ),
      );
    }

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      final detail = e.problems.map((p) => p.msg).join(', ');
      final lower = detail.toLowerCase();
      if (lower.contains('535') ||
          lower.contains('invalid') ||
          lower.contains('username') ||
          lower.contains('password')) {
        throw const EmailServiceException(
          'Autentikasi Gmail gagal. Pastikan App Password sudah benar.',
        );
      }
      throw EmailServiceException('Gagal mengirim email: $detail');
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
