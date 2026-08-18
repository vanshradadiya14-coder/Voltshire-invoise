import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/calculations.dart';
import '../../core/utils/validators.dart';
import '../../models/price_item.dart';
import '../../models/trade_enums.dart';
import '../../providers/data_providers.dart';
import '../../providers/trade_providers.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ui_helpers.dart';

/// Manage the saved price list.
///
/// The library a builder pulls from when quoting. Seeded on first open with
/// realistic trade defaults so it is useful before anything has been typed.
class PriceListScreen extends ConsumerStatefulWidget {
  const PriceListScreen({super.key});

  @override
  ConsumerState<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends ConsumerState<PriceListScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(priceListSeedProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit({PriceItem? item}) async {
    final PriceItem? result = await showModalBottomSheet<PriceItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _PriceEditorSheet(item: item),
    );
    if (result == null) return;

    final repo = ref.read(priceItemRepositoryProvider);
    if (item == null) {
      await repo?.create(result);
      if (mounted) showSnack(context, 'Price saved.');
    } else {
      await repo?.update(result);
      if (mounted) showSnack(context, 'Price updated.');
    }
  }

  Future<void> _delete(PriceItem item) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete this price?',
      message: '"${item.description}" will be removed from your price list. '
          'Documents that already use it are unaffected.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(priceItemRepositoryProvider)?.delete(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String symbol = ref.watch(currencySymbolProvider);
    final AsyncValue<List<PriceItem>> async = ref.watch(priceItemsProvider);
    final List<PriceItem> all = async.valueOrNull ?? const <PriceItem>[];
    final LineCategory? filter = ref.watch(priceCategoryFilterProvider);
    final List<PriceItem> visible = ref.watch(filteredPriceItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price list'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String v) async {
              if (v == 'clear_seeded') {
                final bool ok = await showConfirmDialog(
                  context,
                  title: 'Remove starter prices?',
                  message: 'This removes only the examples that came with the '
                      'app. Anything you added yourself is kept.',
                  confirmLabel: 'Remove',
                  destructive: true,
                );
                if (!ok) return;
                final int n =
                    await ref.read(priceItemRepositoryProvider)?.clearSeeded() ??
                        0;
                if (context.mounted) {
                  showSnack(context, 'Removed $n starter prices.');
                }
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'clear_seeded',
                child: Text('Remove starter prices'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New price'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.sm, Insets.gutter, Insets.sm),
            child: SearchBar(
              controller: _search,
              hintText: 'Search prices',
              leading: const Icon(Icons.search),
              onChanged: (String v) =>
                  ref.read(priceSearchTermProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: FilterChip(
                    label: Text('All (${all.length})'),
                    selected: filter == null,
                    onSelected: (_) => ref
                        .read(priceCategoryFilterProvider.notifier)
                        .state = null,
                  ),
                ),
                for (final LineCategory c in LineCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: Insets.sm),
                    child: FilterChip(
                      label: Text(c.label),
                      avatar: Icon(c.icon, size: 15),
                      selected: filter == c,
                      onSelected: (_) => ref
                          .read(priceCategoryFilterProvider.notifier)
                          .state = filter == c ? null : c,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? EmptyState(
                    icon: Icons.list_alt,
                    title: all.isEmpty ? 'No saved prices' : 'Nothing matches',
                    message: all.isEmpty
                        ? 'Save the things you quote over and over — day rate, '
                            'skip hire, materials — and drop them into any '
                            'quote or invoice in two taps.'
                        : 'Try a different search or category.',
                    actionLabel: all.isEmpty ? 'Add a price' : null,
                    onAction: all.isEmpty ? () => _edit() : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Insets.gutter, Insets.sm, Insets.gutter,
                        Insets.scrollBottom),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Insets.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final PriceItem p = visible[i];
                      return Card(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: p.category.color.withValues(alpha: 0.14),
                              borderRadius: Radii.chip,
                            ),
                            child: Icon(p.category.icon,
                                size: 19, color: p.category.color),
                          ),
                          title: Text(
                            p.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            <String>[
                              p.priceLabel(symbol),
                              if (p.vatPercent > 0)
                                'VAT ${p.vatPercent.toStringAsFixed(0)}%',
                              if (p.useCount > 0) 'used ${p.useCount}×',
                            ].join('  ·  '),
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (String v) =>
                                v == 'edit' ? _edit(item: p) : _delete(p),
                            itemBuilder: (_) => const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem<String>(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () => _edit(item: p),
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

/// Create or edit one saved price.
class _PriceEditorSheet extends StatefulWidget {
  const _PriceEditorSheet({this.item});
  final PriceItem? item;

  @override
  State<_PriceEditorSheet> createState() => _PriceEditorSheetState();
}

class _PriceEditorSheetState extends State<_PriceEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _qty;
  late final TextEditingController _vat;
  late LineCategory _category;
  late PriceUnit _unit;

  @override
  void initState() {
    super.initState();
    final PriceItem? it = widget.item;
    _description = TextEditingController(text: it?.description ?? '');
    _price = TextEditingController(
        text: it == null ? '' : it.unitPrice.toStringAsFixed(2));
    _qty = TextEditingController(
        text: (it?.defaultQuantity ?? 1)
            .toString()
            .replaceAll(RegExp(r'\.0$'), ''));
    _vat = TextEditingController(text: '${it?.vatPercent ?? 20}');
    _category = it?.category ?? LineCategory.materials;
    _unit = it?.unit ?? PriceUnit.each;
  }

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    _qty.dispose();
    _vat.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final PriceItem base = widget.item ??
        const PriceItem(id: '', ownerId: '', description: '');
    Navigator.of(context).pop(base.copyWith(
      description: _description.text.trim(),
      unitPrice: parseNum(_price.text),
      defaultQuantity: parseNum(_qty.text),
      vatPercent: Calc.clampPercent(parseNum(_vat.text)),
      category: _category,
      unit: _unit,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: Insets.xl,
        right: Insets.xl,
        top: Insets.xs,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.item == null ? 'New price' : 'Edit price',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: Insets.lg),
              AppTextField(
                controller: _description,
                label: 'Description *',
                hint: 'e.g. Labour — day rate',
                textCapitalization: TextCapitalization.sentences,
                validator: (String? v) =>
                    Validators.required(v, field: 'Description'),
              ),
              const SizedBox(height: Insets.md),
              Text('Category',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: LineCategory.values.map((LineCategory c) {
                  return ChoiceChip(
                    label: Text(c.label),
                    avatar: Icon(c.icon, size: 15),
                    selected: _category == c,
                    selectedColor: c.color.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _price,
                      label: 'Price *',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: (String? v) =>
                          Validators.number(v, field: 'Price'),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: DropdownButtonFormField<PriceUnit>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: PriceUnit.values
                          .map((PriceUnit u) => DropdownMenuItem<PriceUnit>(
                                value: u,
                                child: Text(u.label),
                              ))
                          .toList(),
                      onChanged: (PriceUnit? u) =>
                          setState(() => _unit = u ?? PriceUnit.each),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _qty,
                      label: 'Default quantity',
                      hint: 'Pre-filled when added',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: AppTextField(
                      controller: _vat,
                      label: 'VAT %',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              FilledButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Save price' : 'Save changes'),
              ),
              const SizedBox(height: Insets.xl),
            ],
          ),
        ),
      ),
    );
  }
}
