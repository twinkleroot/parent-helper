import 'package:cloud_firestore/cloud_firestore.dart';

class Child {
  final String id;
  final String name;

  Child({required this.id, required this.name});

  factory Child.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Child(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
    };
  }

  // DropdownButton의 비교를 위한 == 연산자 재정의
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Child &&
        other.id == id;
  }

  // ==를 재정의할 때 hashCode도 함께 재정의
  @override
  int get hashCode => id.hashCode;
}
