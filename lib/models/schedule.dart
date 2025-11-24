import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // List 변환용

enum ScheduleType { pickup, dropoff }

class Schedule {
  final String id;
  final String childId;
  final String childName; // 비정규화 (표시용)
  final String institutionId;
  final String institutionName; // 비정규화 (표시용)
  final ScheduleType type;
  final List<int> daysOfWeek; // 월:1, 화:2, ... 일:7 (DateTime.monday)
  final TimeOfDay time;
  final int notificationLeadTimeInMinutes;
  final bool isEnabled;
  final String memo;

  Schedule({
    required this.id,
    required this.childId,
    required this.childName,
    required this.institutionId,
    required this.institutionName,
    required this.type,
    required this.daysOfWeek,
    required this.time,
    this.notificationLeadTimeInMinutes = 10,
    this.isEnabled = true,
    this.memo = '',
  });

  factory Schedule.fromFirestore(DocumentSnapshot doc) {
    dynamic data = doc.data() as Map<String, dynamic>;
    return Schedule._fromMap(data, doc.id);
  }

  // SQLite에서 로드
  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule._fromMap(map, map['id'].toString());
  }

  // 공통 팩토리 메서드
  factory Schedule._fromMap(Map<String, dynamic> data, String id) {
    String timeString = data['time'] ?? '12:00';
    List<String> parts = timeString.split(':');
    TimeOfDay time = TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    // daysOfWeek 처리 (Firestore는 List, SQLite는 String/JSON일 수 있음)
    List<int> days;
    if (data['daysOfWeek'] is String) {
      days = List<int>.from(jsonDecode(data['daysOfWeek']));
    } else {
      days = List<int>.from(data['daysOfWeek'] ?? []);
    }

    return Schedule(
      id: id,
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      institutionId: data['institutionId'] ?? '',
      institutionName: data['institutionName'] ?? '',
      type: (data['type'] ?? 'pickup') == 'pickup'
          ? ScheduleType.pickup
          : ScheduleType.dropoff,
      daysOfWeek: days,
      time: time,
      notificationLeadTimeInMinutes: data['notificationLeadTimeInMinutes'] ?? 10,
      isEnabled: (data['isEnabled'] is int) ? (data['isEnabled'] == 1) : (data['isEnabled'] ?? true), // SQLite는 bool을 0/1로 저장
      memo: data['memo'] ?? '',
    );
  }

  // Firestore 저장용
  Map<String, dynamic> toFirestore() {
    return {
      'childId': childId,
      'childName': childName,
      'institutionId': institutionId,
      'institutionName': institutionName,
      'type': type == ScheduleType.pickup ? 'pickup' : 'dropoff',
      'daysOfWeek': daysOfWeek,
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'notificationLeadTimeInMinutes': notificationLeadTimeInMinutes,
      'isEnabled': isEnabled,
      'memo': memo,
    };
  }

  // SQLite 저장용
  Map<String, dynamic> toMap() {
    return {
      'id': id, // SQLite는 ID를 직접 저장 (UUID 사용 예정)
      'childId': childId,
      'childName': childName,
      'institutionId': institutionId,
      'institutionName': institutionName,
      'type': type == ScheduleType.pickup ? 'pickup' : 'dropoff',
      'daysOfWeek': jsonEncode(daysOfWeek), // List를 JSON String으로 변환
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'notificationLeadTimeInMinutes': notificationLeadTimeInMinutes,
      'isEnabled': isEnabled ? 1 : 0, // bool -> int
      'memo': memo,
    };
  }

  // 복사본 생성 (copyWith)
  Schedule copyWith({bool? isEnabled, String? id}) {
    return Schedule(
      id: id ?? this.id,
      childId: childId, childName: childName,
      institutionId: institutionId, institutionName: institutionName,
      type: type, daysOfWeek: daysOfWeek, time: time,
      notificationLeadTimeInMinutes: notificationLeadTimeInMinutes,
      isEnabled: isEnabled ?? this.isEnabled, memo: memo,
    );
  }
}
