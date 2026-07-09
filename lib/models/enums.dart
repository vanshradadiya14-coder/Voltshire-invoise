import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lifecycle status of a job.
enum JobStatus {
  quote('Quote'),
  accepted('Accepted'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  const JobStatus(this.label);
  final String label;

  static JobStatus fromName(String? name) => JobStatus.values.firstWhere(
        (JobStatus s) => s.name == name,
        orElse: () => JobStatus.quote,
      );

  Color get color => switch (this) {
        JobStatus.quote => AppColors.neutral,
        JobStatus.accepted => AppColors.info,
        JobStatus.inProgress => AppColors.warning,
        JobStatus.completed => AppColors.success,
        JobStatus.cancelled => AppColors.danger,
      };
}

/// Status of a quotation.
enum QuoteStatus {
  draft('Draft'),
  sent('Sent'),
  accepted('Accepted'),
  rejected('Rejected'),
  expired('Expired'),
  converted('Converted');

  const QuoteStatus(this.label);
  final String label;

  static QuoteStatus fromName(String? name) => QuoteStatus.values.firstWhere(
        (QuoteStatus s) => s.name == name,
        orElse: () => QuoteStatus.draft,
      );

  Color get color => switch (this) {
        QuoteStatus.draft => AppColors.neutral,
        QuoteStatus.sent => AppColors.info,
        QuoteStatus.accepted => AppColors.success,
        QuoteStatus.rejected => AppColors.danger,
        QuoteStatus.expired => AppColors.warning,
        QuoteStatus.converted => AppColors.seed,
      };
}

/// Payment status of an invoice, derived from amount paid vs. grand total.
enum InvoiceStatus {
  draft('Draft'),
  unpaid('Unpaid'),
  partiallyPaid('Partially Paid'),
  paid('Paid'),
  overdue('Overdue');

  const InvoiceStatus(this.label);
  final String label;

  static InvoiceStatus fromName(String? name) => InvoiceStatus.values.firstWhere(
        (InvoiceStatus s) => s.name == name,
        orElse: () => InvoiceStatus.unpaid,
      );

  Color get color => switch (this) {
        InvoiceStatus.draft => AppColors.draft,
        InvoiceStatus.unpaid => AppColors.unpaid,
        InvoiceStatus.partiallyPaid => AppColors.partiallyPaid,
        InvoiceStatus.paid => AppColors.paid,
        InvoiceStatus.overdue => AppColors.overdue,
      };
}
