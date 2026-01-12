import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/models/sorting_log.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a new sorting log
  Future<void> addSortingLog(SortingLog log) {
    return _db.collection('sorting_logs').add(log.toFirestore());
  }

  // Get a stream of sorting logs
  Stream<List<SortingLog>> getSortingLogs() {
    return _db
        .collection('sorting_logs')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SortingLog.fromFirestore(doc))
            .toList());
  }

  // Get part name from parts_master collection
  Future<String?> getPartName(String partNo) async {
    try {
      final doc = await _db.collection('parts_master').doc(partNo).get();
      if (doc.exists) {
        return doc.data()?['part_name'];
      }
      return null;
    } catch (e) {
      debugPrint('Error getting part name: $e');
      return null;
    }
  }

  // Delete all sorting logs
  Future<void> deleteAllLogs() async {
    final collection = await _db.collection('sorting_logs').get();
    final batch = _db.batch();
    for (final doc in collection.docs) {
      batch.delete(doc.reference);
    }
    return batch.commit();
  }
}
