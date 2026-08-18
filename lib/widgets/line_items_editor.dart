import 'package:flutter/material.dart';

import '../core/utils/calculations.dart';
import '../core/utils/formatters.dart';
import '../core/utils/validators.dart';
import '../models/line_item.dart';
import '../models/trade_enums.dart';
import '../theme/app_spacing.dart';
import 'app_text_field.dart';
import 'price_list_picker.dart';

/// An editable list of [LineItem]s with a running totals footer. Used by both
/// the quote and invoice forms.
class LineItemsEditor extends StatelessWidget {
  const LineItemsEditor({
    required this.items,
    required this.onChanged,
    required this.currencySymbol,
    required this.defaultVat,
    this.showCategories = false,
    super.key,
  });

  final List<LineItem> items;
  final ValueChanged<List<LineItem>> onChanged;
  final String currencySymbol;
  final double defaultVat;

  /// Surfaces the labour/materials category on each row.
  ///
  /// Only worth showing when CIS applies — for a homeowner invoice the
  /// category is set but irrelevant, and displaying it is clutter.
  final bool showCategories;

  Future<void> _editItem(BuildContext context, {int? index}) async {
    final LineItem? result = await showModalBottomSheet<LineItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) => _ItemEditorSheet(
        item: index != null ? items[index] : null,
        defaultVat: defaultVat,
      ),
    );
    if (result == null) return;
    final List<LineItem> next = <LineItem>[...items];
    if (index != null) {
      next[index] = result;
    } else {
      next.add(result);
    }
    onChanged(next);
  }

  /// Adds one or more saved prices in a single pass.
  ///
  /// Multi-select matters: a bathroom refit is eight saved lines, and picking
  /// them one at a time through a sheet that closes each time is exactly the
  /// tedium the price list exists to remove.
  Future<void> _addFromPriceList(BuildContext context) async {
    final List<LineItem>? picked = await showPriceListPicker(context);
    if (picked == null || picked.isEmpty) return;
    onChanged(<LineItem>[...items, ...picked]);
  }

  void _remove(int index) {
    final List<LineItem> next = <LineItem>[...items]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DocumentTotals totals = items.totals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.playlist_add,
                    size: 30,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'No items yet',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pull from your price list, or type one in.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  _ItemTile(
                    item: items[i],
                    symbol: currencySymbol,
                    showCategory: showCategories,
                    onEdit: () => _editItem(context, index: i),
                    onDelete: () => _remove(i),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: Insets.md),
        Row(
          children: <Widget>[
            // Primary, because reusing a saved price is faster than typing and
            // is what a builder should reach for first.
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addFromPriceList(context),
                icon: const Icon(Icons.list_alt, size: 19),
                label: const Text('Price list'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _editItem(context),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Custom'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _TotalsFooter(totals: totals, symbol: currencySymbol),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.symbol,
    required this.onEdit,
    required this.onDelete,
    this.showCategory = false,
  });

  final LineItem item;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> meta = <String>[
      '${Formatters.number(item.quantity, decimals: item.quantity.truncateToDouble() == item.quantity ? 0 : 2)}${item.unit == PriceUnit.each ? '' : ' ${item.unit.short}'} × ${Formatters.money(item.unitPrice, symbol: symbol)}',
      if (item.discountPercent > 0) '-${Formatters.percent(item.discountPercent)}',
      if (item.vatPercent > 0) 'VAT ${Formatters.percent(item.vatPercent)}',
    ];
    return ListTile(
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              item.description.isEmpty ? '(no description)' : item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Only shown under CIS, where labour vs materials decides the
          // deduction and therefore what actually gets paid.
          if (showCategory) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: item.category.color.withValues(alpha: 0.16),
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
          ],
        ],
      ),
      subtitle: Text(meta.join('  ·  '), style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(Formatters.money(item.total, symbol: symbol),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          PopupMenuButton<String>(
            onSelected: (String v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({required this.totals, required this.symbol});
  final DocumentTotals totals;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Widget row(String label, double value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label,
                  style: bold
                      ? theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)
                      : theme.textTheme.bodyMedium),
              Text(Formatters.money(value, symbol: symbol),
                  style: bold
                      ? theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)
                      : theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            row('Subtotal', totals.subtotal),
            if (totals.discountTotal > 0) row('Discount', -totals.discountTotal),
            row('VAT', totals.vatTotal),
            const Divider(),
            row('Total', totals.grandTotal, bold: true),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet editor for a single line item.
class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({this.item, required this.defaultVat});
  final LineItem? item;
  final double defaultVat;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _unitPrice;
  late final TextEditingController _discount;
  late final TextEditingController _vat;
  late LineCategory _category;
  late PriceUnit _unit;

  @override
  void initState() {
    super.initState();
    final LineItem? it = widget.item;
    _category = it?.category ?? LineCategory.labour;
    _unit = it?.unit ?? PriceUnit.each;
    _description = TextEditingController(text: it?.description ?? '');
    _quantity = TextEditingController(
        text: (it?.quantity ?? 1).toString().replaceAll(RegExp(r'\.0$'), ''));
    _unitPrice = TextEditingController(
        text: it == null ? '' : it.unitPrice.toStringAsFixed(2));
    _discount = TextEditingController(
        text: (it?.discountPercent ?? 0) == 0 ? '' : '${it!.discountPercent}');
    _vat = TextEditingController(
        text: '${it?.vatPercent ?? widget.defaultVat}');
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discount.dispose();
    _vat.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(LineItem(
      description: _description.text.trim(),
      quantity: parseNum(_quantity.text),
      unitPrice: parseNum(_unitPrice.text),
      discountPercent: Calc.clampPercent(parseNum(_discount.text)),
      vatPercent: Calc.clampPercent(parseNum(_vat.text)),
      category: _category,
      unit: _unit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 4,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.item == null ? 'Add item' : 'Edit item',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              AppTextField(
                controller: _description,
                label: 'Description *',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                validator: (String? v) =>
                    Validators.required(v, field: 'Description'),
              ),
              const SizedBox(height: 12),
              // Category drives the CIS labour/materials split. It is always
              // captured — even on a homeowner invoice where it is not used —
              // because a job can be re-billed to a contractor later, and
              // back-filling categories across a whole invoice is miserable.
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Category',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: LineCategory.values.map((LineCategory c) {
                  final bool selected = c == _category;
                  return ChoiceChip(
                    label: Text(c.label),
                    avatar: Icon(
                      c.icon,
                      size: 15,
                      color: selected ? c.color : null,
                    ),
                    selected: selected,
                    selectedColor: c.color.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _quantity,
                      label: 'Quantity',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: (String? v) =>
                          Validators.number(v, field: 'Quantity', allowZero: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _unitPrice,
                      label: 'Unit price',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: (String? v) =>
                          Validators.number(v, field: 'Unit price'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _discount,
                      label: 'Discount %',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: Validators.percent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _vat,
                      label: 'VAT %',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: decimalFormatters,
                      validator: Validators.percent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Add item' : 'Save item'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
