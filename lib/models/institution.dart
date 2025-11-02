import 'package:cloud_firestore/cloud_firestore.dart';

class Institution {
  final String id;
  final String name;
  final String contactNumber;
  final String memo;

  Institution({
    required this.id,
    required this.name,
    this.contactNumber = '',
    this.memo = '',
  });

  factory Institution.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Institution(
      id: doc.id,
      name: data['name'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      memo: data['memo'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'contactNumber': contactNumber,
      'memo': memo,
    };
  }

  // DropdownButton의 비교를 위한 == 연산자 재정의
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Institution &&
        other.id == id;
  }

  // ==를 재정의할 때 hashCode도 함께 재정의
  @override
  int get hashCode => id.hashCode;
}
