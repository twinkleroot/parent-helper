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

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'].toString(),
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {'name': name};

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
  };

  // DropdownButton의 비교를 위한 == 연산자 재정의
  @override
  bool operator ==(Object other) => identical(this, other) || other is Child && other.id == id;

  // ==를 재정의할 때 hashCode도 함께 재정의
  @override
  int get hashCode => id.hashCode;
}
