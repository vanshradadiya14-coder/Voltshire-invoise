import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// Renders an [AsyncValue] with consistent loading, error and data states.
///
/// Used everywhere a screen consumes a streamed provider so the loading and
/// error UX is identical across the app.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (Object error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: error.toString(),
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      ),
    );
  }
}
