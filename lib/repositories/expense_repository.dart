import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/firestore_paths.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

/// CRUD for the `expenses` collection, with optional receipt-photo upload.
class ExpenseRepository {
  ExpenseRepository(this._db, this._uid, this._storage);

  final FirebaseFirestore _db;
  final String _uid;
  final StorageService _storage;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(FirestorePaths.expenses);

  Query<Map<String, dynamic>> get _owned => _col.where('ownerId', isEqualTo: _uid);

  Stream<List<Expense>> watchAll() =>
      _owned.orderBy('date', descending: true).snapshots().map(_mapDocs);

  Stream<List<Expense>> watchForJob(String jobId) => _owned
      .where('jobId', isEqualTo: jobId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(_mapDocs);

  Future<String> create(Expense expense, {File? receipt}) async {
    final String id = _uuid.v4();
    UploadResult? upload;
    if (receipt != null) {
      upload = await _storage.uploadFile(
        folder: StoragePaths.receipts(_uid),
        file: receipt,
        contentType: 'image/jpeg',
      );
    }
    final Expense toSave = Expense(
      id: id,
      ownerId: _uid,
      category: expense.category,
      amount: expense.amount,
      supplier: expense.supplier,
      description: expense.description,
      jobId: expense.jobId,
      jobTitle: expense.jobTitle,
      receiptUrl: upload?.url ?? expense.receiptUrl,
      receiptPath: upload?.path ?? expense.receiptPath,
      date: expense.date ?? DateTime.now(),
      createdAt: DateTime.now(),
    );
    await _col.doc(id).set(toSave.toMap());
    return id;
  }

  Future<void> update(Expense expense, {File? receipt}) async {
    Expense toSave = expense;
    if (receipt != null) {
      // Remove the previous receipt before replacing it.
      if (expense.receiptPath.isNotEmpty) {
        await _storage.delete(expense.receiptPath);
      }
      final UploadResult upload = await _storage.uploadFile(
        folder: StoragePaths.receipts(_uid),
        file: receipt,
        contentType: 'image/jpeg',
      );
      toSave = expense.copyWith(receiptUrl: upload.url, receiptPath: upload.path);
    }
    // Always stamp the owner so the update satisfies the security rules even if
    // the caller passed a model without the UID.
    final Map<String, dynamic> map = toSave.toMap()..['ownerId'] = _uid;
    await _col.doc(expense.id).set(map, SetOptions(merge: true));
  }

  Future<void> delete(Expense expense) async {
    if (expense.receiptPath.isNotEmpty) {
      await _storage.delete(expense.receiptPath);
    }
    await _col.doc(expense.id).delete();
  }

  List<Expense> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => Expense.fromMap(d.id, d.data()))
      .toList();
}
