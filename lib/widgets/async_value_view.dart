import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/error_boundary.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'empty_state.dart';

/// Renders an [AsyncValue] with consistent loading, error and data states.
///
/// The error branch shows a human message (via [ErrorPresenter]) rather than a
/// raw exception, and distinguishes "you're offline" from "something broke" —
/// the first needs reassurance, the second needs a retry button.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.errorTitle,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final String? errorTitle;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const _Loading(),
      error: (Object error, StackTrace stack) {
        final bool offline = ErrorPresenter.isOffline(error);
        return EmptyState(
          icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
          title: errorTitle ??
              (offline ? "You're offline" : 'Something went wrong'),
          message: ErrorPresenter.message(error),
          actionLabel: onRetry != null ? 'Try again' : null,
          onAction: onRetry,
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// A shimmering placeholder list, shown while data loads.
///
/// Preferable to a bare spinner on list screens: it communicates the shape of
/// what's coming, so the layout does not jump when data arrives.
class SkeletonList extends StatefulWidget {
  const SkeletonList({this.itemCount = 6, this.itemHeight = 72, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView.separated(
      padding: Insets.pageTop,
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
      itemBuilder: (BuildContext context, int i) => AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) => Opacity(
          opacity: 0.35 + (_controller.value * 0.35),
          child: Container(
            height: widget.itemHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: Radii.card,
            ),
          ),
        ),
      ),
    );
  }
}

/// A slim banner shown when the device is offline.
///
/// Wording matters here: Firestore queues writes locally and syncs later, so
/// the honest message is "saved on this device", not "cannot save".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({this.pendingWrites = 0, super.key});

  final int pendingWrites;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors c = AppColors.of(context);

    return Material(
      color: c.warning.withValues(alpha: c.isDark ? 0.22 : 0.14),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.gutter, vertical: Insets.sm),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, size: 17, color: c.warning),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  pendingWrites > 0
                      ? "Offline — $pendingWrites ${pendingWrites == 1 ? 'change' : 'changes'} will sync when you're back"
                      : 'Offline — your changes are saved on this device',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
