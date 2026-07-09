import '../core/utils/firestore_utils.dart';

/// A customer/client of the building company. Collection `customers`.
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Lower-cased name for case-insensitive prefix search in Firestore.
  String get nameLower => name.toLowerCase();

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? billingAddress,
    String? siteAddress,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      billingAddress: billingAddress ?? this.billingAddress,
      siteAddress: siteAddress ?? this.siteAddress,
      notes: notes ?? this.notes,
      createdAt: createdAt,
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
        'createdAt': dateToTs(createdAt ?? DateTime.now()),
        'updatedAt': dateToTs(DateTime.now()),
      };
}
