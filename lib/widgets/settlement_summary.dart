import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/utils/settlement.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The money breakdown on an invoice or quote.
///
/// For a homeowner this is the familiar three lines: subtotal, VAT, total. For
/// a contractor under CIS or the reverse charge it shows the labour/materials
/// split and the deduction, because the figure the customer transfers is not
/// the same as the value of the work — and a builder needs to see both.
class SettlementSummary extends StatelessWidget {
  const SettlementSummary({
    required this.settlement,
    required this.symbol,
    this.amountPaid,
    this.dense = false,
    super.key,
  });

  final Settlement settlement;
  final String symbol;

  /// When supplied, adds paid/outstanding rows.
  final double? amountPaid;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final AppStatusColors c = AppColors.of(context);
    final Settlement s = settlement;

    return Card(
      child: Padding(
        padding: dense ? Insets.cardTight : Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Labour/materials split only matters when CIS is in play — it is
            // what the deduction is calculated from.
            if (s.hasCis) ...<Widget>[
              _Row(
                label: 'Labour',
                value: Formatters.money(s.labourNet, symbol: symbol),
                muted: true,
              ),
              _Row(
                label: 'Materials & plant',
                value: Formatters.money(s.materialsNet, symbol: symbol),
                muted: true,
              ),
              const Divider(height: Insets.lg),
            ],

            _Row(
              label: 'Subtotal',
              value: Formatters.money(s.subtotal, symbol: symbol),
            ),

            if (s.discountTotal > 0.005)
              _Row(
                label: 'Discount',
                value: '−${Formatters.money(s.discountTotal, symbol: symbol)}',
                muted: true,
              ),

            if (s.reverseChargeApplies)
              _Row(
                label: 'VAT (reverse charge)',
                value: Formatters.money(0, symbol: symbol),
                tone: c.info,
              )
            else
              _Row(
                label: 'VAT',
                value: Formatters.money(s.vatCharged, symbol: symbol),
              ),

            if (s.hasCis) ...<Widget>[
              const SizedBox(height: Insets.xs),
              _Row(
                label: 'CIS deduction (${s.cisRate.toStringAsFixed(0)}%)',
                value: '−${Formatters.money(s.cisDeduction, symbol: symbol)}',
                tone: c.warning,
                bold: true,
              ),
            ],

            const Divider(height: Insets.lg),
            _Row(
              label: s.hasCis ? 'Amount due' : 'Total',
              value: Formatters.money(s.amountDue, symbol: symbol),
              bold: true,
              large: true,
            ),

            if (amountPaid != null) ...<Widget>[
              const SizedBox(height: Insets.xs),
              _Row(
                label: 'Paid',
                value: Formatters.money(amountPaid!, symbol: symbol),
                tone: c.success,
              ),
              _Row(
                label: 'Outstanding',
                value: Formatters.money(
                  (s.amountDue - amountPaid!).clamp(0, double.infinity),
                  symbol: symbol,
                ),
                bold: true,
                tone: (s.amountDue - amountPaid!) > 0.005 ? c.danger : c.success,
              ),
            ],

            // The declarations. On the PDF these are legally required; showing
            // them in-app too means the builder knows what the customer will
            // see before they send it.
            if (s.reverseChargeApplies) ...<Widget>[
              const SizedBox(height: Insets.md),
              _Notice(
                tone: c.info,
                icon: Icons.swap_horiz,
                title: 'Reverse charge applies',
                body: '${Settlement.reverseChargeNotice}\n'
                    'VAT to account for: '
                    '${Formatters.money(s.vatReverseCharged, symbol: symbol)}',
              ),
            ],
            if (s.hasCis) ...<Widget>[
              const SizedBox(height: Insets.sm),
              _Notice(
                tone: c.warning,
                icon: Icons.account_balance_outlined,
                title: 'CIS deducted from labour',
                body: '${Settlement.cisNotice} '
                    'Work value is '
                    '${Formatters.money(s.grossTotal, symbol: symbol)}; '
                    '${Formatters.money(s.amountDue, symbol: symbol)} '
                    'will be paid to you.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
    this.muted = false,
    this.tone,
  });

  final String label;
  final String value;
  final bool bold;
  final bool large;
  final bool muted;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? base = large
        ? theme.textTheme.titleMedium
        : (muted ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium);

    final Color? colour = tone ??
        (muted ? theme.colorScheme.onSurfaceVariant : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: base?.copyWith(
                color: colour,
                fontWeight: bold ? FontWeight.w700 : null,
              ),
            ),
          ),
          Text(
            value,
            style: base?.copyWith(
              color: colour,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: Insets.cardTight,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: Radii.field,
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 17, color: tone),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: tone),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
