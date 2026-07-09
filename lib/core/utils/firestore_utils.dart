import 'package:cloud_firestore/cloud_firestore.dart';

/// Small (de)serialisation helpers shared by every model's `fromMap` / `toMap`.
///
/// Firestore returns dates as [Timestamp]; when reading from the local offline
/// cache a value may momentarily be `null` or already a [DateTime], so these
/// helpers are defensive.

/// Converts a Firestore value to a nullable [DateTime].
DateTime? tsToDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

/// Converts a Firestore value to a non-null [DateTime], defaulting to now.
DateTime tsToDateOr(dynamic value, {DateTime? fallback}) =>
    tsToDate(value) ?? (fallback ?? DateTime.now());

/// Converts a nullable [DateTime] to a Firestore-friendly [Timestamp].
Timestamp? dateToTs(DateTime? date) =>
    date == null ? null : Timestamp.fromDate(date);

/// Tolerant double reader (Firestore may store ints where we expect doubles).
double asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String asString(dynamic value, {String fallback = ''}) =>
    value == null ? fallback : value.toString();

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  return fallback;
}
