import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

// 스케줄 목록에 표시될 카드 아이템
class ScheduleListItem extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback? onTap;   // 수정 화면 이동용
  // final Map<String, String> childNameCache; // (필요 시)
  // final Map<String, String> institutionNameCache; // (필요 시)

  const ScheduleListItem({super.key, required this.schedule, this.onTap});

  String _formatDays(List<int> days) {
    const dayMap = {
      1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'
    };
    // 원본 리스트를 수정하지 않도록 새로운 리스트를 만들어 정렬
    final sortedDays = List<int>.from(days)..sort();
    return sortedDays.map((d) => dayMap[d] ?? '?').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('a h:mm', 'ko_KR'); // 오후 3:00
    final formattedTime = timeFormat.format(DateTime(2023, 1, 1, schedule.time.hour, schedule.time.minute));
    final leadTime = schedule.notificationLeadTimeInMinutes;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: () {
          _showDeleteConfirmation(context, schedule);
        },
        leading: CircleAvatar(
          backgroundColor: schedule.type == ScheduleType.pickup
              ? Colors.blue.shade100
              : Colors.green.shade100,
          child: Icon(
            // ScheduleType enum 사용 및 아이콘 변경
            schedule.type == ScheduleType.pickup
                ? Icons.directions_car
                : Icons.school,
            color:
            schedule.type == ScheduleType.pickup ? Colors.blue : Colors.green,
          ),
        ),
        title: Text('${schedule.childName} - ${schedule.institutionName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('매주 [${_formatDays(schedule.daysOfWeek)}] $formattedTime ($leadTime분 전 알림)'),
            // 메모가 있을 경우에만 표시
            if (schedule.memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '메모: ${schedule.memo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        isThreeLine: schedule.memo.isNotEmpty, // 메모가 있으면 3줄 모드 활성화

        trailing: Switch(
          value: schedule.isEnabled,
          // 활성화/비활성화 로직 연결
          onChanged: (value) async {
            final firestoreService = context.read<FirestoreService>();
            final notificationService = context.read<NotificationService>();

            // 1. Firestore 업데이트 (copyWith 대신 새 객체 생성)
            // (사용자님이 주신 모델에는 copyWith가 없으므로 생성자를 사용합니다)
            final updatedSchedule = Schedule(
              id: schedule.id,
              childId: schedule.childId,
              childName: schedule.childName,
              institutionId: schedule.institutionId,
              institutionName: schedule.institutionName,
              type: schedule.type,
              daysOfWeek: schedule.daysOfWeek,
              time: schedule.time,
              notificationLeadTimeInMinutes:
              schedule.notificationLeadTimeInMinutes,
              memo: schedule.memo,
              isEnabled: value, // <-- 변경된 값
            );
            await firestoreService.updateSchedule(updatedSchedule);

            // 2. 알림 업데이트
            if (value) {
              // 스위치를 켠 경우: 알림 다시 예약
              // (서비스 내부에서 loop, title, body 처리)
              await notificationService.scheduleWeeklyNotification(updatedSchedule);
            } else {
              // 스위치를 끈 경우: 예약된 알림 모두 취소
              // (사용자님이 제공한 NotificationService의 메서드명으로 변경)
              await notificationService.cancelNotificationsForSchedule(updatedSchedule);
            }
          },
        ),
      ),
    );
  }

  // [추가] 삭제 확인 다이얼로그 (이전 응답과 동일)
  void _showDeleteConfirmation(BuildContext context, Schedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?\n예약된 알림도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              try {
                // Provider에서 서비스 가져오기 (listen: false)
                final firestoreService = context.read<FirestoreService>();
                final notificationService = context.read<NotificationService>();

                // 1. Firestore에서 삭제
                // 사용자님이 제공한 모델의 id는 non-nullable이므로 '!' 제거
                await firestoreService.deleteSchedule(schedule.id);
                // 2. 예약된 알림 취소
                await notificationService.cancelNotificationsForSchedule(schedule);

                Navigator.of(ctx).pop(); // 다이얼로그 닫기
              } catch (e) {
                Navigator.of(ctx).pop(); // 다이얼로그 닫기
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 중 오류 발생: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
