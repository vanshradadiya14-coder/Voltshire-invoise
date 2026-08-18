import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

/// The kinds of record a create form can produce.
enum EntityKind {
  customer('Customer', Icons.person_outline),
  job('Job', Icons.construction_outlined),
  quote('Quotation', Icons.description_outlined),
  invoice('Invoice', Icons.receipt_long_outlined),
  expense('Expense', Icons.account_balance_wallet_outlined),
  payment('Payment', Icons.payments_outlined),
  variation('Variation', Icons.add_task_outlined);

  const EntityKind(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Route to the detail screen for [id], or null where none exists.
  String? detailRoute(String id) => switch (this) {
        EntityKind.customer => Routes.customerDetail(id),
        EntityKind.job => Routes.jobDetail(id),
        EntityKind.quote => Routes.quoteDetail(id),
        EntityKind.invoice => Routes.invoiceDetail(id),
        EntityKind.expense => null,
        EntityKind.payment => null,
        EntityKind.variation => null,
      };
}

/// What a create form hands back after saving.
///
/// The old code called `repo.create()` — which returns the new document ID —
/// and then threw it away before calling `context.pop()`. That single line is
/// why the app felt like a database browser: every piece of work ended by
/// returning the builder to a list, with no way to continue.
///
/// Carrying the ID (and the customer/job it belongs to) lets the app offer the
/// thing that actually happens next.
@immutable
class SaveOutcome {
  const SaveOutcome({
    required this.kind,
    required this.id,
    required this.label,
    this.customerId,
    this.customerName,
    this.jobId,
    this.jobTitle,
    this.wasEdit = false,
  });

  final EntityKind kind;
  final String id;

  /// Human name of what was saved — "J. Smith", "INV-000042".
  final String label;

  final String? customerId;
  final String? customerName;
  final String? jobId;
  final String? jobTitle;

  /// True for an update rather than a create. Edits do not offer next steps —
  /// somebody correcting a typo does not want a workflow prompt.
  final bool wasEdit;

  String get confirmation =>
      wasEdit ? '${kind.label} updated' : '${kind.label} saved';

  /// The next steps worth offering, in priority order.
  ///
  /// Chosen from what follows in real life, not from what is technically
  /// possible. The first entry is rendered as the primary action.
  List<NextStep> get nextSteps {
    if (wasEdit) return const <NextStep>[];

    switch (kind) {
      case EntityKind.customer:
        return <NextStep>[
          // Primary. A builder adding a client mid-job wants to bill them —
          // and this is the path that was explicitly missing.
          NextStep(
            label: 'Create invoice',
            detail: 'Bill $label for work done',
            icon: Icons.receipt_long,
            route: '${Routes.invoiceNew}?customerId=$id',
            isPrimary: true,
          ),
          NextStep(
            label: 'Create quote',
            detail: 'Price up a job for them',
            icon: Icons.description_outlined,
            route: '${Routes.quoteNew}?customerId=$id',
          ),
          NextStep(
            label: 'Add a job',
            detail: 'Track the work itself',
            icon: Icons.construction_outlined,
            route: '${Routes.jobNew}?customerId=$id',
          ),
        ];

      case EntityKind.job:
        return <NextStep>[
          NextStep(
            label: 'Quote this job',
            detail: 'Price it up and send it',
            icon: Icons.description_outlined,
            route: _withContext(Routes.quoteNew),
            isPrimary: true,
          ),
          NextStep(
            label: 'Invoice this job',
            detail: 'Bill it now',
            icon: Icons.receipt_long,
            route: _withContext(Routes.invoiceNew),
          ),
          NextStep(
            label: 'Add photos',
            detail: 'Before, progress and completed work',
            icon: Icons.photo_camera_outlined,
            route: Routes.jobPhotos(id),
          ),
          NextStep(
            label: 'Set up staged payments',
            detail: 'Deposit and instalments',
            icon: Icons.splitscreen_outlined,
            route: Routes.jobStages(id),
          ),
        ];

      case EntityKind.quote:
        return <NextStep>[
          NextStep(
            label: 'Send to customer',
            detail: 'Share the PDF',
            icon: Icons.send_outlined,
            route: Routes.quoteDetail(id),
            isPrimary: true,
          ),
          if (jobId == null)
            NextStep(
              label: 'Create the job',
              detail: 'Start tracking the work',
              icon: Icons.construction_outlined,
              route: _withContext(Routes.jobNew),
            ),
        ];

      case EntityKind.invoice:
        return <NextStep>[
          NextStep(
            label: 'Send to customer',
            detail: 'Share the PDF',
            icon: Icons.send_outlined,
            route: Routes.invoiceDetail(id),
            isPrimary: true,
          ),
          NextStep(
            label: 'Record a payment',
            detail: 'If they have already paid',
            icon: Icons.payments_outlined,
            route: Routes.invoiceDetail(id),
          ),
        ];

      case EntityKind.expense:
        return <NextStep>[
          NextStep(
            label: 'Log another',
            detail: 'Keep going while you have the receipts out',
            icon: Icons.add,
            route: jobId == null
                ? Routes.expenseNew
                : '${Routes.expenseNew}?jobId=$jobId',
            isPrimary: true,
          ),
        ];

      case EntityKind.payment:
      case EntityKind.variation:
        return const <NextStep>[];
    }
  }

  /// Appends whatever context this outcome carries to a "new" route, so the
  /// next form opens pre-filled instead of blank.
  String _withContext(String base) {
    final List<String> params = <String>[];
    if (kind == EntityKind.job) {
      params.add('jobId=$id');
      if (customerId != null) params.add('customerId=$customerId');
    } else {
      if (customerId != null) params.add('customerId=$customerId');
      if (jobId != null) params.add('jobId=$jobId');
    }
    return params.isEmpty ? base : '$base?${params.join('&')}';
  }
}

/// One offered continuation.
@immutable
class NextStep {
  const NextStep({
    required this.label,
    required this.detail,
    required this.icon,
    required this.route,
    this.isPrimary = false,
  });

  final String label;
  final String detail;
  final IconData icon;
  final String route;
  final bool isPrimary;
}
