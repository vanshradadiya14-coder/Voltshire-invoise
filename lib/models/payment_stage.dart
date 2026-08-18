import '../core/utils/calculations.dart';
import '../core/utils/firestore_utils.dart';
import 'trade_enums.dart';

/// One scheduled payment on a job. Collection `payment_stages`.
///
/// Builders rarely bill a whole job at the end — they take a deposit to cover
/// materials, then stage the rest. Tracking that in the app is the difference
/// between knowing your cash position and guessing it.
class PaymentStage {
  const PaymentStage({
    required this.id,
    required this.ownerId,
    required this.jobId,
    required this.label,
    this.jobTitle = '',
    this.customerId = '',
    this.customerName = '',
    this.percent,
    this.fixedAmount,
    this.order = 0,
    this.status = StageStatus.pending,
    this.dueDate,
    this.invoiceId,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String jobId;
  final String jobTitle;
  final String customerId;
  final String customerName;

  /// "Deposit", "First fix", "On completion".
  final String label;

  /// Either a percentage of the job value…
  final double? percent;

  /// …or a fixed amount. Percentage is preferred because the job value moves
  /// when variations are added.
  final double? fixedAmount;

  /// Position in the schedule.
  final int order;

  final StageStatus status;
  final DateTime? dueDate;

  /// Set once this stage has been billed.
  final String? invoiceId;

  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPercentage => percent != null;
  bool get isBilled => invoiceId != null;

  /// What this stage is worth against a given job value.
  double amountFor(double jobValue) {
    if (fixedAmount != null) return Calc.round2(fixedAmount!);
    if (percent != null) return Calc.round2(jobValue * (percent! / 100));
    return 0;
  }

  /// "50%" or "£2,500.00"
  String shareLabel(String symbol) => isPercentage
      ? '${percent!.toStringAsFixed(percent! % 1 == 0 ? 0 : 1)}%'
      : '$symbol${(fixedAmount ?? 0).toStringAsFixed(2)}';

  PaymentStage copyWith({
    String? label,
    double? percent,
    double? fixedAmount,
    int? order,
    StageStatus? status,
    DateTime? dueDate,
    String? invoiceId,
    String? notes,
    bool clearInvoice = false,
    DateTime? updatedAt,
  }) {
    return PaymentStage(
      id: id,
      ownerId: ownerId,
      jobId: jobId,
      jobTitle: jobTitle,
      customerId: customerId,
      customerName: customerName,
      label: label ?? this.label,
      percent: percent ?? this.percent,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      order: order ?? this.order,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      invoiceId: clearInvoice ? null : (invoiceId ?? this.invoiceId),
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PaymentStage.fromMap(String id, Map<String, dynamic> map) {
    return PaymentStage(
      id: id,
      ownerId: asString(map['ownerId']),
      jobId: asString(map['jobId']),
      jobTitle: asString(map['jobTitle']),
      customerId: asString(map['customerId']),
      customerName: asString(map['customerName']),
      label: asString(map['label'], fallback: 'Stage'),
      percent: map['percent'] == null ? null : asDouble(map['percent']),
      fixedAmount:
          map['fixedAmount'] == null ? null : asDouble(map['fixedAmount']),
      order: asInt(map['order']),
      status: StageStatus.fromName(map['status'] as String?),
      dueDate: tsToDate(map['dueDate']),
      invoiceId: map['invoiceId'] as String?,
      notes: asString(map['notes']),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'customerId': customerId,
        'customerName': customerName,
        'label': label,
        'percent': percent,
        'fixedAmount': fixedAmount,
        'order': order,
        'status': status.name,
        'dueDate': dateToTs(dueDate),
        'invoiceId': invoiceId,
        'notes': notes,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}

/// A ready-made schedule shape.
///
/// These are the four ways UK building work is actually billed. Offering them
/// as one-tap presets means a builder sets up staged payments in three seconds
/// instead of typing four rows.
enum StagePreset {
  fiftyFifty(
    'Deposit & completion',
    '50% up front, 50% when finished',
    <({String label, double percent})>[
      (label: 'Deposit', percent: 50),
      (label: 'On completion', percent: 50),
    ],
  ),
  thirds(
    'Three stages',
    '40% deposit, 30% first fix, 30% completion',
    <({String label, double percent})>[
      (label: 'Deposit', percent: 40),
      (label: 'First fix', percent: 30),
      (label: 'On completion', percent: 30),
    ],
  ),
  quarters(
    'Four stages',
    'Evenly across a longer job',
    <({String label, double percent})>[
      (label: 'Deposit', percent: 25),
      (label: 'Stage 2', percent: 25),
      (label: 'Stage 3', percent: 25),
      (label: 'Final', percent: 25),
    ],
  ),
  depositOnly(
    'Deposit only',
    '25% up front, balance on completion',
    <({String label, double percent})>[
      (label: 'Deposit', percent: 25),
      (label: 'Balance', percent: 75),
    ],
  );

  const StagePreset(this.label, this.description, this.stages);

  final String label;
  final String description;
  final List<({String label, double percent})> stages;
}

/// Aggregates across a job's schedule.
extension PaymentStageTotals on List<PaymentStage> {
  List<PaymentStage> get ordered =>
      <PaymentStage>[...this]..sort((PaymentStage a, PaymentStage b) =>
          a.order.compareTo(b.order));

  double billedAgainst(double jobValue) => where((PaymentStage s) => s.isBilled)
      .fold<double>(0, (double t, PaymentStage s) => t + s.amountFor(jobValue));

  double remainingAgainst(double jobValue) =>
      where((PaymentStage s) => !s.isBilled)
          .fold<double>(0, (double t, PaymentStage s) => t + s.amountFor(jobValue));

  /// True when the percentages add up to roughly 100%, so the UI can warn
  /// about a schedule that would under- or over-bill the job.
  bool get percentagesBalance {
    final Iterable<PaymentStage> pct = where((PaymentStage s) => s.isPercentage);
    if (pct.isEmpty) return true;
    final double total =
        pct.fold<double>(0, (double t, PaymentStage s) => t + (s.percent ?? 0));
    return (total - 100).abs() < 0.5;
  }

  double get percentageTotal => where((PaymentStage s) => s.isPercentage)
      .fold<double>(0, (double t, PaymentStage s) => t + (s.percent ?? 0));

  PaymentStage? get nextUnbilled {
    for (final PaymentStage s in ordered) {
      if (!s.isBilled) return s;
    }
    return null;
  }
}
