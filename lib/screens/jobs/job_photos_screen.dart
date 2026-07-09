import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../models/job_photo.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// Manage before/progress/completed photos for a job.
class JobPhotosScreen extends ConsumerStatefulWidget {
  const JobPhotosScreen({required this.jobId, super.key});
  final String jobId;

  @override
  ConsumerState<JobPhotosScreen> createState() => _JobPhotosScreenState();
}

class _JobPhotosScreenState extends ConsumerState<JobPhotosScreen> {
  bool _uploading = false;

  Future<void> _add() async {
    final _PickChoice? choice = await showModalBottomSheet<_PickChoice>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, const _PickChoice(ImageSource.camera)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, const _PickChoice(ImageSource.gallery)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (choice == null) return;

    final XFile? file = await ImagePicker().pickImage(
      source: choice.source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return;

    // Ask for the category.
    if (!mounted) return;
    final String? category = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Photo category'),
        children: AppConstants.photoCategories
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
      await ref.read(photoRepositoryProvider).add(
            jobId: widget.jobId,
            file: File(file.path),
            category: category,
          );
      if (mounted) showSnack(context, 'Photo added.');
    } catch (e) {
      if (mounted) showSnack(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(JobPhoto photo) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete photo?',
      message: 'This permanently removes the photo.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(photoRepositoryProvider).delete(photo);
    if (mounted) showSnack(context, 'Photo deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobPhoto>> photos =
        ref.watch(photosForJobProvider(widget.jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('Job photos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _add,
        icon: _uploading
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add photo'),
      ),
      body: AsyncValueView<List<JobPhoto>>(
        value: photos,
        data: (List<JobPhoto> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No photos',
              message: 'Add before, progress and completed work photos.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: <Widget>[
              for (final String cat in AppConstants.photoCategories)
                ..._categorySection(context, cat,
                    list.where((JobPhoto p) => p.category == cat).toList()),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(
      BuildContext context, String category, List<JobPhoto> list) {
    if (list.isEmpty) return <Widget>[];
    return <Widget>[
      SectionHeader('$category (${list.length})'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: list
            .map((JobPhoto p) => GestureDetector(
                  onLongPress: () => _delete(p),
                  onTap: () => _viewPhoto(context, p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: p.url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
    ];
  }

  void _viewPhoto(BuildContext context, JobPhoto p) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InteractiveViewer(
              child: CachedNetworkImage(imageUrl: p.url, fit: BoxFit.contain),
            ),
            OverflowBar(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _delete(p);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickChoice {
  const _PickChoice(this.source);
  final ImageSource source;
}
