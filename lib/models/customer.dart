import '../core/utils/firestore_utils.dart';
import 'trade_enums.dart';

/// A customer/client of the building company. Collection `customers`.
///
/// The trade fields ([type], [cisStatus], [reverseCharge]) are configured once
/// here and then applied automatically to every quote and invoice for this
/// customer. That is deliberate: a builder should set up "Barratt — contractor,
/// CIS 20%, reverse charge" a single time, not remember it on every invoice.
///
/// For a homeowner all of it stays at its default and never appears in the UI.
class Customer {
  const Customer({
    required this.id,
    required this.ownerId,
    required this.name,
    this.phone = '',
    this.email = '',
    this.billingAddress = '',
    this.siteAddress = '',
    this.notes = '',
    this.type = CustomerType.domestic,
    this.cisStatus = CisStatus.notApplicable,
    this.reverseCharge = false,
    this.vatNumber = '',
    this.companyNumber = '',
    this.contactName = '',
    this.paymentTermsDays,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String phone;
  final String email;
  final String billingAddress;
  final String siteAddress;
  final String notes;

  // ---- Trade / tax settings -------------------------------------------

  /// Homeowner or contractor. Gates all the tax UI.
  final CustomerType type;

  /// CIS deduction rate applied to labour on invoices to this customer.
  final CisStatus cisStatus;

  /// Whether the VAT domestic reverse charge for building and construction
  /// services applies. When true this customer accounts for the VAT to HMRC
  /// and we charge none.
  final bool reverseCharge;

  final String vatNumber;
  final String companyNumber;

  /// Named contact at a contractor — "Dave, site manager".
  final String contactName;

  /// Per-customer payment terms, overriding the company default. Contractors
  /// commonly impose 30 or 60 days.
  final int? paymentTermsDays;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Lower-cased name for case-insensitive prefix search in Firestore.
  String get nameLower => name.toLowerCase();

  /// True when this customer has any tax treatment that changes the invoice.
  bool get hasTradeSettings =>
      type.isBusiness && (cisStatus.deducts || reverseCharge);

  /// Short summary for chips, e.g. "Contractor · CIS 20% · Reverse charge".
  String get tradeSummary {
    if (!type.isBusiness) return type.label;
    final List<String> parts = <String>[type.label];
    if (cisStatus != CisStatus.notApplicable) parts.add(cisStatus.shortLabel);
    if (reverseCharge) parts.add('Reverse charge');
    return parts.join(' · ');
  }

  /// The address to bill to, falling back to the site address.
  String get invoiceAddress =>
      billingAddress.trim().isNotEmpty ? billingAddress : siteAddress;

  Customer copyWith({
    String? id,
    String? ownerId,
    DateTime? createdAt,
    String? name,
    String? phone,
    String? email,
    String? billingAddress,
    String? siteAddress,
    String? notes,
    CustomerType? type,
    CisStatus? cisStatus,
    bool? reverseCharge,
    String? vatNumber,
    String? companyNumber,
    String? contactName,
    int? paymentTermsDays,
    bool clearPaymentTerms = false,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      billingAddress: billingAddress ?? this.billingAddress,
      siteAddress: siteAddress ?? this.siteAddress,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      cisStatus: cisStatus ?? this.cisStatus,
      reverseCharge: reverseCharge ?? this.reverseCharge,
      vatNumber: vatNumber ?? this.vatNumber,
      companyNumber: companyNumber ?? this.companyNumber,
      contactName: contactName ?? this.contactName,
      paymentTermsDays:
          clearPaymentTerms ? null : (paymentTermsDays ?? this.paymentTermsDays),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      ownerId: asString(map['ownerId']),
      name: asString(map['name']),
      phone: asString(map['phone']),
      email: asString(map['email']),
      billingAddress: asString(map['billingAddress']),
      siteAddress: asString(map['siteAddress']),
      notes: asString(map['notes']),
      // Legacy documents have none of these. The defaults reproduce the exact
      // behaviour those customers had before the trade fields existed.
      type: CustomerType.fromName(map['type'] as String?),
      cisStatus: CisStatus.fromName(map['cisStatus'] as String?),
      reverseCharge: asBool(map['reverseCharge']),
      vatNumber: asString(map['vatNumber']),
      companyNumber: asString(map['companyNumber']),
      contactName: asString(map['contactName']),
      paymentTermsDays:
          map['paymentTermsDays'] == null ? null : asInt(map['paymentTermsDays']),
      createdAt: tsToDate(map['createdAt']),
      updatedAt: tsToDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'ownerId': ownerId,
        'name': name,
        'nameLower': nameLower,
        'phone': phone,
        'email': email,
        'billingAddress': billingAddress,
        'siteAddress': siteAddress,
        'notes': notes,
        'type': type.name,
        'cisStatus': cisStatus.name,
        'reverseCharge': reverseCharge,
        'vatNumber': vatNumber,
        'companyNumber': companyNumber,
        'contactName': contactName,
        'paymentTermsDays': paymentTermsDays,
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}
