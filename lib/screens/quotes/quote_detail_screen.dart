import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/company_profile.dart';
import '../../models/invoice.dart';
import '../../models/quote.dart';
import '../../pdf/document_pdf.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/pdf_share_sheet.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Full quotation view with convert-to-invoice, duplicate and PDF actions.
class QuoteDetailScreen extends ConsumerWidget {
  const QuoteDetailScreen({required this.quoteId, super.key});
  final String quoteId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete quote?',
      message: 'This permanently deletes the quotation.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(quoteRepositoryProvider).delete(quoteId);
    if (context.mounted) {
      showSnack(context, 'Quote deleted.');
      context.pop();
    }
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref, Quote q) async {
    final String id = await ref.read(quoteRepositoryProvider).duplicate(q);
    if (context.mounted) {
      showSnack(context, 'Quote duplicated.');
      context.pushReplacement(Routes.quoteDetail(id));
    }
  }

  Future<void> _convert(BuildContext context, WidgetRef ref, Quote q) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Convert to invoice?',
      message: 'Creates a new invoice from this quote and marks it converted.',
      confirmLabel: 'Convert',
    );
    if (!ok) return;
    try {
      final String invoiceId = await ref.read(invoiceRepositoryProvider).create(
            Invoice(
              id: '',
              ownerId: '',
              number: 0,
              numberFormatted: '',
              customerId: q.customerId,
              customerName: q.customerName,
              customerAddress: q.customerAddress,
              jobId: q.jobId,
              jobTitle: q.jobTitle,
              workDescription: q.workDescription,
              items: q.items,
              issueDate: DateTime.now(),
              dueDate: DateTime.now().add(const Duration(days: 14)),
              notes: q.notes,
            ),
          );
      await ref.read(quoteRepositoryProvider).markConverted(q.id, invoiceId);
      if (context.mounted) {
        showSnack(context, 'Invoice created from quote.');
        context.pushReplacement(Routes.invoiceDetail(invoiceId));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, 'Conversion failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Quote?> quoteAsync = ref.watch(quoteProvider(quoteId));
    final CompanyProfile? company = ref.watch(companyProfileProvider).valueOrNull;
    final String symbol = company?.currencySymbol ?? '£';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.quoteEdit(quoteId)),
          ),
          PopupMenuButton<String>(
            onSelected: (String v) {
              final Quote? q = quoteAsync.valueOrNull;
              if (q == null) return;
              switch (v) {
                case 'duplicate':
                  _duplicate(context, ref, q);
                case 'delete':
                  _delete(context, ref);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: AsyncValueView<Quote?>(
        value: quoteAsync,
        data: (Quote? q) {
          if (q == null) return const Center(child: Text('Quote not found.'));
          final totals = q.totals;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(q.numberFormatted,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        StatusChip(
                            label: q.isExpired ? 'Expired' : q.status.label,
                            color: q.isExpired ? q.status.color : q.status.color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DetailRow(
                        label: 'Customer',
                        value: q.customerName,
                        icon: Icons.person_outline),
                    if (q.jobTitle.isNotEmpty)
                      DetailRow(
                          label: 'Job',
                          value: q.jobTitle,
                          icon: Icons.construction_outlined),
                    DetailRow(
                        label: 'Issued',
                        value: q.issueDate == null ? '' : Formatters.date(q.issueDate!),
                        icon: Icons.event_outlined),
                    DetailRow(
                        label: 'Valid until',
                        value:
                            q.validUntil == null ? '' : Formatters.date(q.validUntil!),
                        icon: Icons.event_busy_outlined),
                    if (q.workDescription.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('Work description',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(q.workDescription),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Items', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final item in q.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(item.description),
                                  Text(
                                    '${item.quantity % 1 == 0 ? item.quantity.toStringAsFixed(0) : item.quantity} × ${Formatters.money(item.unitPrice, symbol: symbol)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(Formatters.money(item.netAfterDiscount, symbol: symbol)),
                          ],
                        ),
                      ),
                    const Divider(),
                    _totalRow(context, 'Subtotal',
                        Formatters.money(totals.subtotal, symbol: symbol)),
                    _totalRow(context, 'VAT',
                        Formatters.money(totals.vatTotal, symbol: symbol)),
                    _totalRow(
                        context,
                        'Total',
                        Formatters.money(totals.grandTotal, symbol: symbol),
                        bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (q.status != QuoteStatus.converted)
                FilledButton.tonalIcon(
                  onPressed: () => _convert(context, ref, q),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Convert to invoice'),
                ),
              if (q.convertedInvoiceId != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(Routes.invoiceDetail(q.convertedInvoiceId!)),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View converted invoice'),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: quoteAsync.valueOrNull == null || company == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => showPdfActions(
                    context,
                    ref,
                    buildBytes: () => DocumentPdf.quote(
                      quote: quoteAsync.value!,
                      company: company,
                    ),
                    fileName: '${quoteAsync.value!.numberFormatted}.pdf',
                    shareSubject:
                        'Quotation ${quoteAsync.value!.numberFormatted} from ${company.companyName}',
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share PDF'),
                ),
              ),
            ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                  : null),
          Text(value,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                  : null),
        ],
      ),
    );
  }
}
