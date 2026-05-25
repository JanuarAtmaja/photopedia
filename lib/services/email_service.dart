import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

/// EmailService menggunakan Gmail SMTP dengan App Password.
///
/// CARA SETUP (wajib dilakukan sekali):
/// 1. Buka myaccount.google.com → Security → 2-Step Verification → aktifkan
/// 2. Masih di Security → App passwords → Generate
///    (pilih app: Mail, device: Other → ketik "Photopedia")
/// 3. Salin 16 karakter yang muncul (hapus spasi)
/// 4. Isi _gmailUser dan _gmailAppPassword di bawah
///
/// CATATAN KEAMANAN:
/// Untuk aplikasi pribadi/internal ini aman.
/// Jangan publish ke Play Store dengan kredensial hardcoded.
class EmailService {
  // ── Ganti dengan akun Gmail dan App Password kamu ────────────────────────
  static const String _gmailUser = 'muhamadhisyamganteng@gmail.com';
  static const String _gmailAppPassword = 'nvdrhfvmhzxuftij'; // 16 karakter, tanpa spasi

  /// Kirim email dengan lampiran foto opsional.
  static Future<void> sendPhotoEmail({
    required String toName,
    required String toEmail,
    Uint8List? photoBytes,
    String? photoFileName,
    String subject = 'Foto dari Photopedia',
    String? body,
  }) async {
    final smtpServer = gmail(_gmailUser, _gmailAppPassword);

    final emailBody = body ??
        'Halo $toName,\n\n'
        'Berikut foto yang diambil dari Photopedia.\n'
        'Semoga menyukainya!\n\n'
        'Salam,\nPhotopedia App';

    // Bangun pesan email
    final message = Message()
      ..from = const Address(_gmailUser, 'Photopedia App')
      ..recipients.add(Address(toEmail, toName))
      ..subject = subject
      ..text = emailBody;

    // Tambah lampiran jika ada foto
    if (photoBytes != null) {
      final fileName = photoFileName ?? 'foto_photopedia.jpg';
      message.attachments.add(
        StreamAttachment(
          Stream.fromIterable([photoBytes]),
          _mimeType(fileName),
          fileName: fileName,
        ),
      );
    }

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      // Terjemahkan error mailer ke pesan yang ramah
      final msg = e.problems.isNotEmpty
          ? e.problems.first.msg
          : e.toString();

      if (msg.contains('535') || msg.contains('Username and Password')) {
        throw const EmailServiceException(
          'Login Gmail gagal. Pastikan App Password sudah benar '
          'dan 2-Step Verification sudah aktif.',
        );
      } else if (msg.contains('timeout') || msg.contains('timed out')) {
        throw const EmailServiceException(
          'Koneksi timeout. Periksa jaringan internet kamu.',
        );
      }
      throw EmailServiceException('Gagal mengirim email: $msg');
    } catch (e) {
      throw EmailServiceException('Terjadi kesalahan: $e');
    }
  }

  /// Deteksi MIME type berdasarkan ekstensi file.
  static String _mimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
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
