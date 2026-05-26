import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

/// EmailService menggunakan SMTP Gmail + App Password.
///
/// CARA SETUP:
/// 1. Pastikan akun Gmail sudah aktifkan 2FA
/// 2. Buka myaccount.google.com → Security → App Passwords
/// 3. Buat App Password baru → salin 16 karakter
/// 4. Isi _gmailUser dan _appPassword di bawah
class EmailService {
  // ── Gmail credentials ────────────────────────────────────────────────────
  static const String _gmailUser   = 'muhamadhisyamganteng@gmail.com'; // ← ganti
  static const String _appPassword = 'yyxxgsbokftqpjfn'; // ← App Password 16 karakter

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
      ..from = const Address(_gmailUser, 'Photopedia App')
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
