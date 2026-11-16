import 'package:flutter/foundation.dart';
import '../models/paper_trail_doc.dart';
import 'database_helper.dart';

class PaperTrailService extends ChangeNotifier {
  static final PaperTrailService instance = PaperTrailService._internal();

  PaperTrailService._internal();

  final DatabaseHelper _db = DatabaseHelper.instance;
  final Map<String, PaperTrailDoc> _docsByLocalId = {};
  List<PaperTrailDoc> _allDocs = [];

  List<PaperTrailDoc> get allDocs => List.unmodifiable(_allDocs);
  int get totalCount => _allDocs.length;

  List<PaperTrailDoc> get activeWarranties =>
      _allDocs.where((d) => d.hasWarranty && !d.isWarrantyExpired).toList();

  List<PaperTrailDoc> get expiringSoonWarranties =>
      _allDocs.where((d) => d.isExpiringSoon).toList();

  List<PaperTrailDoc> get expiredWarranties =>
      _allDocs.where((d) => d.hasWarranty && d.isWarrantyExpired).toList();

  double get totalTrackedSpending =>
      _allDocs.fold(0.0, (sum, d) => sum + (d.amount ?? 0.0));

  Future<void> init() async {
    try {
      final docs = await _db.getAllPaperTrailDocs();
      _allDocs = docs;
      _docsByLocalId.clear();
      for (final doc in docs) {
        _docsByLocalId[doc.localId] = doc;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[PaperTrailService] Error during init: $e');
    }
  }

  bool isPaperTrail(String localId) => _docsByLocalId.containsKey(localId);

  PaperTrailDoc? getDocForMedia(String localId) => _docsByLocalId[localId];

  Future<void> saveDoc(PaperTrailDoc doc) async {
    _docsByLocalId[doc.localId] = doc;
    _allDocs.removeWhere((d) => d.id == doc.id || d.localId == doc.localId);
    _allDocs.insert(0, doc);
    notifyListeners();

    try {
      await _db.insertOrUpdatePaperTrailDoc(doc);
    } catch (e) {
      debugPrint('[PaperTrailService] Error saving doc: $e');
    }
  }

  Future<void> deleteDoc(String id) async {
    final index = _allDocs.indexWhere((d) => d.id == id);
    if (index != -1) {
      final doc = _allDocs[index];
      _docsByLocalId.remove(doc.localId);
      _allDocs.removeAt(index);
      notifyListeners();
    }

    try {
      await _db.deletePaperTrailDoc(id);
    } catch (e) {
      debugPrint('[PaperTrailService] Error deleting doc: $e');
    }
  }

  Future<void> deleteDocByLocalId(String localId) async {
    _docsByLocalId.remove(localId);
    _allDocs.removeWhere((d) => d.localId == localId);
    notifyListeners();

    try {
      await _db.deletePaperTrailDocByLocalId(localId);
    } catch (e) {
      debugPrint('[PaperTrailService] Error deleting doc by localId: $e');
    }
  }
}

