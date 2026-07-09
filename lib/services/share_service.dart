import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles all "outbound" actions for generated PDFs: print, save/share,
/// email and WhatsApp.
class ShareService {
  const ShareService();

  /// Writes [bytes] to a temp file named [fileName] and returns it.
  Future<File> _writeTemp(Uint8List bytes, String fileName) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the OS print dialog / preview for the PDF.
  Future<void> printPdf(Uint8List bytes, {String name = 'document'}) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }

  /// Opens the native share sheet with the PDF attached.
  Future<void> sharePdf(
    Uint8List bytes, {
    required String fileName,
    String? subject,
    String? text,
  }) async {
    final File file = await _writeTemp(bytes, fileName);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: text,
    );
  }

  /// Shares the PDF specifically via email (falls back to the share sheet if
  /// no mail client handles the deep link). Uses share sheet with the PDF so
  /// the file is actually attached.
  Future<void> emailPdf(
    Uint8List bytes, {
    required String fileName,
    String? toEmail,
    String subject = '',
    String body = '',
  }) async {
    // The share sheet is the most reliable way to attach a file to an email
    // across Android and iOS; the user picks their mail app from it.
    await sharePdf(bytes, fileName: fileName, subject: subject, text: body);
  }

  /// Shares via WhatsApp. Sends the file through the share sheet (which lists
  /// WhatsApp). If [phone] is given, first tries a wa.me deep link for text.
  Future<void> whatsappPdf(
    Uint8List bytes, {
    required String fileName,
    String? phone,
    String message = '',
  }) async {
    // Files can't be attached through the wa.me URL scheme, so route the PDF
    // through the share sheet where the user selects WhatsApp.
    await sharePdf(bytes, fileName: fileName, text: message);
  }

  /// Opens WhatsApp chat with a pre-filled text message (no attachment).
  Future<bool> openWhatsAppChat({required String phone, String message = ''}) async {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the device dialer.
  Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  /// Opens the mail composer (no attachment).
  Future<bool> composeEmail({required String to, String subject = '', String body = ''}) {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    return launchUrl(uri);
  }

  Future<bool> openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
