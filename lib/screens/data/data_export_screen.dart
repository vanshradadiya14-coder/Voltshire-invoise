import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/telemetry.dart';
import '../../models/subscription.dart';
import '../../providers/data_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/export_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/ui_helpers.dart';
import '../../widgets/upgrade_prompt.dart';

/// Export records as CSV.
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  final Set<ExportKind> _selected = <ExportKind>{...ExportKind.values};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool allowed = ref.watch(hasFeatureProvider(PaidFeature.dataExport));

    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: ListView(
        padding: Insets.pageTop,
        children: <Widget>[
          if (!allowed) ...<Widget>[
            const UpgradeCard(
              title: 'Export is a Pro feature',
              message: 'Download your records as CSV for your accountant.',
              icon: Icons.download_outlined,
            ),
            const SizedBox(height: Insets.lg),
          ],
          Text(
            'Each selection becomes a separate CSV file. Dates are written in '
            'ISO format (YYYY-MM-DD) so any spreadsheet reads them correctly, '
            'and amounts are plain numbers so they can be summed.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.lg),
          Card(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < ExportKind.values.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  CheckboxListTile(
                    value: _selected.contains(ExportKind.values[i]),
                    onChanged: allowed
                        ? (bool? v) => setState(() {
                              if (v ?? false) {
                                _selected.add(ExportKind.values[i]);
                              } else {
                                _selected.remove(ExportKind.values[i]);
                              }
                            })
                        : null,
                    title: Text(ExportKind.values[i].label),
                    subtitle: Text(_countLabel(ExportKind.values[i])),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          FilledButton.icon(
            onPressed: (!allowed || _selected.isEmpty || _busy)
                ? null
                : _export,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share),
            label: Text(_busy ? 'Preparing…' : 'Export and share'),
          ),
        ],
      ),
    );
  }

  String _countLabel(ExportKind kind) {
    final int n = switch (kind) {
      ExportKind.customers =>
        ref.watch(customersProvider).valueOrNull?.length ?? 0,
      ExportKind.jobs => ref.watch(jobsProvider).valueOrNull?.length ?? 0,
      ExportKind.quotes => ref.watch(quotesProvider).valueOrNull?.length ?? 0,
      ExportKind.invoices =>
        ref.watch(invoicesProvider).valueOrNull?.length ?? 0,
      ExportKind.payments =>
        ref.watch(paymentsProvider).valueOrNull?.length ?? 0,
      ExportKind.expenses =>
        ref.watch(expensesProvider).valueOrNull?.length ?? 0,
    };
    return '$n ${n == 1 ? 'record' : 'records'}';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final ExportService svc = ref.read(exportServiceProvider);
    final List<File> files = <File>[];

    try {
      for (final ExportKind kind in _selected) {
        final List<List<Object?>> rows = switch (kind) {
          ExportKind.customers => svc.customerRows(
              ref.read(customersProvider).valueOrNull ?? const []),
          ExportKind.jobs =>
            svc.jobRows(ref.read(jobsProvider).valueOrNull ?? const []),
          ExportKind.quotes =>
            svc.quoteRows(ref.read(quotesProvider).valueOrNull ?? const []),
          ExportKind.invoices => svc.invoiceRows(
              ref.read(invoicesProvider).valueOrNull ?? const []),
          ExportKind.payments => svc.paymentRows(
              ref.read(paymentsProvider).valueOrNull ?? const []),
          ExportKind.expenses => svc.expenseRows(
              ref.read(expensesProvider).valueOrNull ?? const []),
        };
        // Header row only means no data — do not share an empty file.
        if (rows.length <= 1) continue;
        files.add(await svc.writeCsv(kind: kind, rows: rows));
      }

      if (files.isEmpty) {
        if (mounted) showSnack(context, 'There is nothing to export yet.');
        return;
      }

      await svc.share(files);
      Telemetry.logEvent(AppEvent.dataExported,
          <String, Object>{'files': files.length});
    } catch (e) {
      if (mounted) {
        showSnack(context, 'The export failed. Please try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
