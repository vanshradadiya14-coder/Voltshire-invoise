import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/invoice.dart';
import '../../models/job.dart';
import '../../models/payment.dart';
import '../../providers/data_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui_helpers.dart';

/// Business reports: revenue (monthly/yearly), outstanding, completed jobs,
/// expense summary and a simple profit figure.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final String symbol = ref.watch(currencySymbolProvider);
    final List<Payment> payments = ref.watch(paymentsProvider).valueOrNull ?? <Payment>[];
    final List<Expense> expenses = ref.watch(expensesProvider).valueOrNull ?? <Expense>[];
    final List<Invoice> invoices = ref.watch(invoicesProvider).valueOrNull ?? <Invoice>[];
    final List<Job> jobs = ref.watch(jobsProvider).valueOrNull ?? <Job>[];

    // Yearly aggregates.
    final List<Payment> yearPayments =
        payments.where((Payment p) => p.date?.year == _year).toList();
    final List<Expense> yearExpenses =
        expenses.where((Expense e) => e.date?.year == _year).toList();

    final double yearlyRevenue =
        yearPayments.fold<double>(0, (double s, Payment p) => s + p.amount);
    final double yearlyExpenses =
        yearExpenses.fold<double>(0, (double s, Expense e) => s + e.amount);
    final double profit = yearlyRevenue - yearlyExpenses;

    final double outstanding = invoices
        .where((Invoice i) => !i.isDraft)
        .fold<double>(0, (double s, Invoice i) => s + i.balanceDue);

    final int completedJobs = jobs
        .where((Job j) =>
            j.status == JobStatus.completed && (j.completionDate?.year ?? _year) == _year)
        .length;

    // Monthly revenue breakdown.
    final List<double> monthly = List<double>.filled(12, 0);
    for (final Payment p in yearPayments) {
      if (p.date != null) monthly[p.date!.month - 1] += p.amount;
    }
    final double maxMonth =
        monthly.fold<double>(0, (double m, double v) => v > m ? v : m);

    // Expense-by-category breakdown.
    final Map<String, double> byCategory = <String, double>{};
    for (final Expense e in yearExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final List<MapEntry<String, double>> categories = byCategory.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) =>
          b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DropdownButton<int>(
              value: _year,
              underline: const SizedBox.shrink(),
              items: List<int>.generate(6, (int i) => DateTime.now().year - i)
                  .map((int y) =>
                      DropdownMenuItem<int>(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (int? y) => setState(() => _year = y ?? _year),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: 'Yearly Revenue',
                  value: Formatters.money(yearlyRevenue, symbol: symbol),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Expenses',
                  value: Formatters.money(yearlyExpenses, symbol: symbol),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: 'Profit',
                  value: Formatters.money(profit, symbol: symbol),
                  color: profit >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Outstanding',
                  value: Formatters.money(outstanding, symbol: symbol),
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricCard(
            label: 'Completed jobs in $_year',
            value: '$completedJobs',
            color: AppColors.info,
          ),
          const SizedBox(height: 8),
          const SectionHeader('Monthly revenue'),
          AppCard(
            child: Column(
              children: <Widget>[
                for (int m = 0; m < 12; m++)
                  _BarRow(
                    label: _monthLabel(m),
                    value: monthly[m],
                    max: maxMonth,
                    symbol: symbol,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionHeader('Expense summary'),
          if (categories.isEmpty)
            const AppCard(child: Text('No expenses recorded for this year.'))
          else
            AppCard(
              child: Column(
                children: categories
                    .map((MapEntry<String, double> e) => _BarRow(
                          label: e.key,
                          value: e.value,
                          max: categories.first.value,
                          symbol: symbol,
                          barColor: AppColors.warning,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _monthLabel(int index) =>
      Formatters.monthYear(DateTime(_year, index + 1)).split(' ').first;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.symbol,
    this.barColor,
  });

  final String label;
  final double value;
  final double max;
  final String symbol;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final double fraction = max <= 0 ? 0 : (value / max).clamp(0, 1);
    final Color color = barColor ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: <Widget>[
                  Container(
                    height: 18,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction == 0 ? 0.001 : fraction,
                    child: Container(height: 18, color: color.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              Formatters.money(value, symbol: symbol),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
