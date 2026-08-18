import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/formatters.dart';
import '../models/line_item.dart';
import '../models/price_item.dart';
import '../models/trade_enums.dart';
import '../providers/data_providers.dart';
import '../providers/trade_providers.dart';
import '../routes/app_routes.dart';
import '../theme/app_spacing.dart';

/// Multi-select picker over the saved price list.
///
/// Returns the chosen prices as ready-to-use [LineItem]s, or null if cancelled.
///
/// Multi-select is the whole point: a bathroom refit is eight saved lines, and
/// picking them one at a time through a sheet that closes after each would be
/// exactly the tedium the price list exists to remove.
Future<List<LineItem>?> showPriceListPicker(BuildContext context) {
  return showModalBottomSheet<List<LineItem>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) => const _PriceListPicker(),
  );
}

class _PriceListPicker extends ConsumerStatefulWidget {
  const _PriceListPicker();

  @override
  ConsumerState<_PriceListPicker> createState() => _PriceListPickerState();
}

class _PriceListPickerState extends ConsumerState<_PriceListPicker> {
  final TextEditingController _search = TextEditingController();

  /// Chosen items and the quantity for each.
  final Map<String, double> _selected = <String, double>{};

  LineCategory? _category;

  @override
  void initState() {
    super.initState();
    // Create the starter list on first use, so the picker is never an empty
    // screen with a "you have no prices" message.
    ref.read(priceListSeedProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PriceItem> _visible(List<PriceItem> all) {
    final String term = _search.text.trim().toLowerCase();
    return all.where((PriceItem p) {
      if (_category != null && p.category != _category) return false;
      if (term.isEmpty) return true;
      return p.searchText.contains(term);
    }).toList();
  }

  void _confirm(List<PriceItem> all) {
    final List<LineItem> lines = <LineItem>[];
    final List<String> usedIds = <String>[];

    for (final PriceItem p in all) {
      final double? qty = _selected[p.id];
      if (qty == null) continue;
      lines.add(p.toLineItem(quantity: qty));
      usedIds.add(p.id);
    }

    // Bump usage counters so the most-reached-for prices float to the top.
    // Fire-and-forget — a failed counter must not block adding the lines.
    final repo = ref.read(priceItemRepositoryProvider);
    for (final String id in usedIds) {
      repo?.recordUse(id);
    }

    Navigator.of(context).pop(lines);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String symbol = ref.watch(currencySymbolProvider);
    final AsyncValue<List<PriceItem>> async = ref.watch(priceItemsProvider);
    final List<PriceItem> all = async.valueOrNull ?? const <PriceItem>[];
    final List<PriceItem> visible = _visible(all);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.xl, 0, Insets.xl, Insets.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Price list',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.priceList);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: SearchBar(
                controller: _search,
                hintText: 'Search your prices',
                leading: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: Insets.md),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final LineCategory c in LineCategory.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: FilterChip(
                        label: Text(c.label),
                        selected: _category == c,
                        onSelected: (_) => setState(
                            () => _category = _category == c ? null : c),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: async.isLoading && all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? _EmptyPrices(hasAny: all.isNotEmpty)
                      : ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(
                              Insets.xl, 0, Insets.xl, Insets.lg),
                          itemCount: visible.length,
                          itemBuilder: (BuildContext context, int i) {
                            final PriceItem p = visible[i];
                            final double? qty = _selected[p.id];
                            return _PriceRow(
                              item: p,
                              symbol: symbol,
                              quantity: qty,
                              onToggle: () => setState(() {
                                if (qty == null) {
                                  _selected[p.id] = p.defaultQuantity;
                                } else {
                                  _selected.remove(p.id);
                                }
                              }),
                              onQuantity: (double v) => setState(() {
                                if (v <= 0) {
                                  _selected.remove(p.id);
                                } else {
                                  _selected[p.id] = v;
                                }
                              }),
                            );
                          },
                        ),
            ),
            _PickerFooter(
              count: _selected.length,
              total: _selectedTotal(all),
              symbol: symbol,
              onAdd: _selected.isEmpty ? null : () => _confirm(all),
            ),
          ],
        );
      },
    );
  }

  double _selectedTotal(List<PriceItem> all) {
    double total = 0;
    for (final PriceItem p in all) {
      final double? qty = _selected[p.id];
      if (qty != null) total += qty * p.unitPrice;
    }
    return total;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.item,
    required this.symbol,
    required this.quantity,
    required this.onToggle,
    required this.onQuantity,
  });

  final PriceItem item;
  final String symbol;
  final double? quantity;
  final VoidCallback onToggle;
  final ValueChanged<double> onQuantity;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool selected = quantity != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: onToggle,
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: Insets.cardTight,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: Radii.card,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 21,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  item.category.color.withValues(alpha: 0.16),
                              borderRadius: Radii.chip,
                            ),
                            child: Text(
                              item.category.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: item.category.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(
                            item.priceLabel(symbol),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  _QuantityStepper(
                    value: quantity!,
                    onChanged: onQuantity,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline quantity control, so the amount is set without leaving the picker.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Step by a sensible amount for the magnitude — stepping 500 bricks up one
    // at a time is useless.
    final double step = value >= 100 ? 10 : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepButton(
          icon: Icons.remove,
          onTap: () => onChanged((value - step).clamp(0, 1000000)),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value == value.roundToDouble()
                ? value.toStringAsFixed(0)
                : value.toStringAsFixed(1),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: () => onChanged(value + step),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: Radii.chip,
        ),
        child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _PickerFooter extends StatelessWidget {
  const _PickerFooter({
    required this.count,
    required this.total,
    required this.symbol,
    required this.onAdd,
  });

  final int count;
  final double total;
  final String symbol;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            Insets.xl, Insets.md, Insets.xl, Insets.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    count == 0
                        ? 'Nothing selected'
                        : '$count ${count == 1 ? 'item' : 'items'}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (count > 0)
                    Text(
                      '${Formatters.money(total, symbol: symbol)} net',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add to document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPrices extends StatelessWidget {
  const _EmptyPrices({required this.hasAny});
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              hasAny ? Icons.search_off : Icons.list_alt,
              size: 38,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: Insets.md),
            Text(
              hasAny ? 'Nothing matches' : 'Setting up your price list…',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              hasAny
                  ? 'Try a different search or category.'
                  : 'A starter list of common trade prices is being created. '
                      'Edit them to match what you actually charge.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
