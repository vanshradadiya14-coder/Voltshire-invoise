import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'ui_helpers.dart';

/// Presents the standard set of actions for a generated PDF: preview/print,
/// share, email and WhatsApp. [buildBytes] is called lazily so the PDF is only
/// rendered when an action is chosen.
Future<void> showPdfActions(
  BuildContext context,
  WidgetRef ref, {
  required Future<Uint8List> Function() buildBytes,
  required String fileName,
  required String shareSubject,
  String shareText = '',
  String? customerEmail,
  String? customerPhone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      Future<Uint8List> withProgress() async {
        return buildBytes();
      }

      Future<void> run(Future<void> Function(Uint8List bytes) action) async {
        Navigator.pop(ctx);
        try {
          final Uint8List bytes = await withProgress();
          await action(bytes);
        } catch (e) {
          if (context.mounted) showSnack(context, 'PDF error: $e', error: true);
        }
      }

      final share = ref.read(shareServiceProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print / Preview'),
              onTap: () => run((Uint8List b) => share.printPdf(b, name: fileName)),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share / Download'),
              onTap: () => run((Uint8List b) => share.sharePdf(
                    b,
                    fileName: fileName,
                    subject: shareSubject,
                  )),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Email'),
              onTap: () => run((Uint8List b) => share.emailPdf(
                    b,
                    fileName: fileName,
                    toEmail: customerEmail,
                    subject: shareSubject,
                  )),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => run((Uint8List b) => share.whatsappPdf(
                    b,
                    fileName: fileName,
                    phone: customerPhone,
                    message: shareSubject,
                  )),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
