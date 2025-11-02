import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    Map data = doc.data() as Map<String, dynamic>;

    // TimeOfDay 변환 (HH:mm 문자열 저장 기준)
    String timeString = data['time'] ?? '12:00';
    List<String> parts = timeString.split(':');
    TimeOfDay time = TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    return Schedule(
      id: doc.id,
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      institutionId: data['institutionId'] ?? '',
      institutionName: data['institutionName'] ?? '',
      type: (data['type'] ?? 'pickup') == 'pickup'
          ? ScheduleType.pickup
          : ScheduleType.dropoff,
      daysOfWeek: List<int>.from(data['daysOfWeek'] ?? []),
      time: time,
      notificationLeadTimeInMinutes:
      data['notificationLeadTimeInMinutes'] ?? 10,
      isEnabled: data['isEnabled'] ?? true,
      memo: data['memo'] ?? '',
    );
  }

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
}
