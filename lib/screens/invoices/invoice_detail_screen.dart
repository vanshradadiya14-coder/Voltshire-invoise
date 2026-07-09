import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../models/company_profile.dart';
import '../../models/invoice.dart';
import '../../models/payment.dart';
import '../../pdf/document_pdf.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/pdf_share_sheet.dart';
import '../../widgets/record_payment_sheet.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/ui_helpers.dart';

/// Full invoice view with line items, totals, payments and PDF actions.
class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({required this.invoiceId, super.key});
  final String invoiceId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool ok = await showConfirmDialog(
      context,
      title: 'Delete invoice?',
      message: 'This permanently deletes the invoice and cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(invoiceRepositoryProvider).delete(invoiceId);
    if (context.mounted) {
      showSnack(context, 'Invoice deleted.');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Invoice?> invoiceAsync = ref.watch(invoiceProvider(invoiceId));
    final CompanyProfile? company = ref.watch(companyProfileProvider).valueOrNull;
    final String symbol = company?.currencySymbol ?? '£';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.invoiceEdit(invoiceId)),
          ),
          PopupMenuButton<String>(
            onSelected: (String v) {
              if (v == 'delete') _delete(context, ref);
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: AsyncValueView<Invoice?>(
        value: invoiceAsync,
        data: (Invoice? inv) {
          if (inv == null) return const Center(child: Text('Invoice not found.'));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: <Widget>[
              _SummaryCard(invoice: inv, symbol: symbol),
              const SizedBox(height: 8),
              _ItemsCard(invoice: inv, symbol: symbol),
              const SizedBox(height: 8),
              _PaymentsCard(invoice: inv, symbol: symbol),
            ],
          );
        },
      ),
      bottomNavigationBar: invoiceAsync.valueOrNull == null
          ? null
          : _ActionBar(
              invoice: invoiceAsync.value!,
              company: company,
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.invoice, required this.symbol});
  final Invoice invoice;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(invoice.numberFormatted,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              StatusChip(label: invoice.status.label, color: invoice.status.color),
            ],
          ),
          const SizedBox(height: 8),
          DetailRow(
              label: 'Customer', value: invoice.customerName, icon: Icons.person_outline),
          if (invoice.jobTitle.isNotEmpty)
            DetailRow(
                label: 'Job', value: invoice.jobTitle, icon: Icons.construction_outlined),
          DetailRow(
              label: 'Issued',
              value: invoice.issueDate == null ? '' : Formatters.date(invoice.issueDate!),
              icon: Icons.event_outlined),
          DetailRow(
              label: 'Due',
              value: invoice.dueDate == null ? '' : Formatters.date(invoice.dueDate!),
              icon: Icons.event_busy_outlined),
          if (invoice.workDescription.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text('Work description',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(invoice.workDescription),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.invoice, required this.symbol});
  final Invoice invoice;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final totals = invoice.totals;
    Widget totalLine(String l, double v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(l,
                  style: bold
                      ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                      : null),
              Text(Formatters.money(v, symbol: symbol),
                  style: bold
                      ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)
                      : null),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in invoice.items)
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
                          '${item.quantity % 1 == 0 ? item.quantity.toStringAsFixed(0) : item.quantity} × ${Formatters.money(item.unitPrice, symbol: symbol)}'
                          '${item.discountPercent > 0 ? '  ·  -${Formatters.percent(item.discountPercent)}' : ''}'
                          '${item.vatPercent > 0 ? '  ·  VAT ${Formatters.percent(item.vatPercent)}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(Formatters.money(item.netAfterDiscount, symbol: symbol)),
                ],
              ),
            ),
          const Divider(),
          totalLine('Subtotal', totals.subtotal),
          if (totals.discountTotal > 0) totalLine('Discount', -totals.discountTotal),
          totalLine('VAT', totals.vatTotal),
          totalLine('Grand Total', totals.grandTotal, bold: true),
          if (invoice.amountPaid > 0) ...<Widget>[
            const SizedBox(height: 4),
            totalLine('Paid', -invoice.amountPaid),
            totalLine('Balance Due', invoice.balanceDue, bold: true),
          ],
        ],
      ),
    );
  }
}

class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({required this.invoice, required this.symbol});
  final Invoice invoice;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Payment>> payments =
        ref.watch(paymentsForInvoiceProvider(invoice.id));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Payments', style: Theme.of(context).textTheme.titleMedium),
              if (!invoice.isPaid && !invoice.isDraft)
                TextButton.icon(
                  onPressed: () => showRecordPaymentSheet(context, ref, invoice),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Record'),
                ),
            ],
          ),
          payments.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator())),
            error: (Object e, _) => Text('Error: $e'),
            data: (List<Payment> list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No payments recorded.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                : Column(
                    children: list
                        .map((Payment p) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(Formatters.money(p.amount, symbol: symbol)),
                              subtitle: Text(
                                  '${p.method}${p.reference.isEmpty ? '' : ' · ${p.reference}'}'
                                  '${p.date == null ? '' : ' · ${Formatters.date(p.date!)}'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () async {
                                  final bool ok = await showConfirmDialog(
                                    context,
                                    title: 'Delete payment?',
                                    message:
                                        'The invoice balance will be adjusted.',
                                    confirmLabel: 'Delete',
                                    destructive: true,
                                  );
                                  if (ok) {
                                    await ref
                                        .read(paymentRepositoryProvider)
                                        .deletePayment(p);
                                  }
                                },
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.invoice, required this.company});
  final Invoice invoice;
  final CompanyProfile? company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(invoice.customerId)).valueOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            if (!invoice.isPaid && !invoice.isDraft)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showRecordPaymentSheet(context, ref, invoice),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Payment'),
                ),
              ),
            if (!invoice.isPaid && !invoice.isDraft) const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: company == null
                    ? null
                    : () => showPdfActions(
                          context,
                          ref,
                          buildBytes: () => DocumentPdf.invoice(
                            invoice: invoice,
                            company: company!,
                          ),
                          fileName: '${invoice.numberFormatted}.pdf',
                          shareSubject:
                              'Invoice ${invoice.numberFormatted} from ${company!.companyName}',
                          customerEmail: customer?.email,
                          customerPhone: customer?.phone,
                        ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Share PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
