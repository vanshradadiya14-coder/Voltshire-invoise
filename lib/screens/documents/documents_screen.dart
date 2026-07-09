import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../models/document_file.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// Store and manage contracts, certificates, guarantees, planning docs, etc.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    final PlatformFile picked = result.files.single;

    if (!mounted) return;
    final String? category = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Document type'),
        children: AppConstants.documentCategories
            .map((String c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text(c),
                ))
            .toList(),
      ),
    );
    if (category == null) return;

    setState(() => _uploading = true);
    try {
      final String ext = picked.extension ?? '';
      await ref.read(documentRepositoryProvider).add(
            file: File(picked.path!),
            name: picked.name,
            category: category,
            contentType: _contentTypeFor(ext),
          );
      if (mounted) showSnack(context, 'Document uploaded.');
    } catch (e) {
      if (mounted) showSnack(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _delete(DocumentFile doc) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete document?',
      message: 'This permanently removes "${doc.name}".',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) await ref.read(documentRepositoryProvider).delete(doc);
  }

  IconData _iconFor(DocumentFile d) {
    if (d.isPdf) return Icons.picture_as_pdf_outlined;
    if (d.isImage) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DocumentFile>> docs = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: AsyncValueView<List<DocumentFile>>(
        value: docs,
        data: (List<DocumentFile> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              title: 'No documents',
              message:
                  'Attach contracts, certificates, guarantees, planning docs and receipts.',
              actionLabel: 'Upload document',
              onAction: _upload,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int i) {
              final DocumentFile d = list[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_iconFor(d))),
                  title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${d.category}'
                    '${d.sizeBytes > 0 ? ' · ${Formatters.fileSize(d.sizeBytes)}' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String v) {
                      if (v == 'open') {
                        ref.read(shareServiceProvider).openUrl(d.url);
                      } else if (v == 'delete') {
                        _delete(d);
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'open', child: Text('Open')),
                      PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => ref.read(shareServiceProvider).openUrl(d.url),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
