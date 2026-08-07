import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_layout.dart';
import '../../providers/dashboard_layout_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui_helpers.dart';

/// Reorder and show/hide dashboard sections.
///
/// Uses an explicit drag handle rather than long-press-to-drag: with switches
/// on the same row, an always-on drag gesture would fight the toggle.
class CustomizeDashboardScreen extends ConsumerWidget {
  const CustomizeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DashboardLayout layout = ref.watch(dashboardLayoutProvider);
    final DashboardLayoutController controller =
        ref.read(dashboardLayoutProvider.notifier);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customise dashboard'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              final bool ok = await showConfirmDialog(
                context,
                title: 'Reset layout?',
                message: 'This restores the default order and shows every section.',
                confirmLabel: 'Reset',
              );
              if (ok) controller.reset();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
            child: Text(
              'Drag to reorder. Switch off anything you never look at — the '
              'dashboard loads faster with fewer sections.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  Insets.gutter, 0, Insets.gutter, Insets.scrollBottom),
              itemCount: layout.order.length,
              onReorder: controller.reorder,
              proxyDecorator: (Widget child, int index, Animation<double> a) {
                return AnimatedBuilder(
                  animation: a,
                  builder: (BuildContext context, Widget? c) => Material(
                    elevation: 6 * a.value,
                    color: Colors.transparent,
                    borderRadius: Radii.card,
                    child: c,
                  ),
                  child: child,
                );
              },
              itemBuilder: (BuildContext context, int i) {
                final DashboardSection s = layout.order[i];
                final bool visible = layout.isVisible(s);

                return Padding(
                  key: ValueKey<DashboardSection>(s),
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Card(
                    child: Opacity(
                      opacity: visible ? 1 : 0.55,
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(
                            left: Insets.sm, right: Insets.sm),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.sm),
                            child: Icon(
                              Icons.drag_indicator,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Row(
                          children: <Widget>[
                            Icon(s.icon,
                                size: 17,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: Insets.sm),
                            Flexible(
                              child: Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (s.isLocked) ...<Widget>[
                              const SizedBox(width: Insets.sm),
                              Icon(Icons.lock_outline,
                                  size: 13,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          s.isLocked ? 'Always shown' : s.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Switch(
                          value: visible,
                          onChanged:
                              s.isLocked ? null : (_) => controller.toggle(s),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
