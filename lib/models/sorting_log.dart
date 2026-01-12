import 'package:cloud_firestore/cloud_firestore.dart';

class NgDetail {
  final String type;
  final String operatorName;
  final String? imageUrl;

  NgDetail({
    required this.type,
    required this.operatorName,
    this.imageUrl,
  });

  factory NgDetail.fromMap(Map<String, dynamic> map) {
    return NgDetail(
      type: map['type'] ?? '',
      operatorName: map['operator_name'] ?? '',
      imageUrl: map['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'operator_name': operatorName,
      'image_url': imageUrl,
    };
  }
}

class SortingLog {
  final String? id;
  final String partNo;
  final String partName;
  final int quantitySorted;
  final int quantityNg;
  final String supplier;
  final String factoryLocation;
  final List<String> operators;
  final List<NgDetail> ngDetails;
  final String remarks;
  final Timestamp timestamp;

  SortingLog({
    this.id,
    required this.partNo,
    required this.partName,
    required this.quantitySorted,
    required this.quantityNg,
    required this.supplier,
    required this.factoryLocation,
    required this.operators,
    required this.ngDetails,
    required this.remarks,
    required this.timestamp,
  });

  factory SortingLog.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SortingLog(
      id: doc.id,
      partNo: data['part_no'] ?? '',
      partName: data['part_name'] ?? '',
      quantitySorted: data['quantity_sorted'] ?? 0,
      quantityNg: data['quantity_ng'] ?? 0,
      supplier: data['supplier'] ?? '',
      factoryLocation: data['factory_location'] ?? '',
      operators: (data['operators'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      ngDetails: (data['ng_details'] as List<dynamic>?)
              ?.map((e) => NgDetail.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      remarks: data['remarks'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'part_no': partNo,
      'part_name': partName,
      'quantity_sorted': quantitySorted,
      'quantity_ng': quantityNg,
      'supplier': supplier,
      'factory_location': factoryLocation,
      'operators': operators,
      'ng_details': ngDetails.map((e) => e.toMap()).toList(),
      'remarks': remarks,
      'timestamp': timestamp,
    };
  }
}
