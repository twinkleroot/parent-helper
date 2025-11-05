import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';

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

  // 추가: 메모 30자 제한 헬퍼 함수
  String _truncateMemo(String memo) {
    const maxLength = 30;
    if (memo.length <= maxLength) {
      return memo;
    }
    // 100자까지만 자르고 '...'를 붙입니다.
    return '${memo.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('a h:mm', 'ko_KR'); // 오후 3:00
    final formattedTime = timeFormat.format(DateTime(2023, 1, 1, schedule.time.hour, schedule.time.minute));
    final leadTime = schedule.notificationLeadTimeInMinutes;

    final String memoText = schedule.memo.isNotEmpty
        ? _truncateMemo(schedule.memo) // 100자 제한 적용
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: () {
          _showDeleteConfirmation(context, schedule);
        },
        // leading에 아이콘 대신 시간을 표시
        leading: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          width: 75, // 고정 폭을 주어 정렬
          alignment: Alignment.center,
          child: Text(
            formattedTime,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              // 등/하원 유형에 따라 색상 구분
              color: schedule.type == ScheduleType.pickup
                  ? Colors.blue.shade700
                  : Colors.green.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // title, subtitle은 기존 로직 유지 (아이콘 정보 제거)
        title: Text('${schedule.childName} - ${schedule.institutionName}'),
        subtitle: RichText(
          text: TextSpan(
            // 기본 스타일 (subtitle의 기본 스타일을 따름)
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant
            ),
            children: [
              // 1. 일정 정보
              TextSpan(
                text: '매주 [${_formatDays(schedule.daysOfWeek)}]\n($leadTime분 전 알림)',
              ),

              // 2. 메모 정보 (메모가 있을 경우에만)
              if (memoText.isNotEmpty)
                TextSpan(
                  text: '\n\n$memoText', // \n으로 줄바꿈
                  style: TextStyle(
                    // 약간 흐린 색상 + 이탤릭체
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        trailing: Switch(
          value: schedule.isEnabled,
          onChanged: (value) async {
            final firestoreService = context.read<FirestoreService>();
            final notificationService =
            context.read<NotificationService>();

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
              isEnabled: value, // 변경된 값
            );

            try {
              // 1. Firestore 업데이트
              await firestoreService.updateSchedule(updatedSchedule);

              // 2. 알림 업데이트
              if (value) {
                // 스위치를 켠 경우: 알림 다시 예약
                await notificationService
                    .scheduleWeeklyNotification(updatedSchedule);
              } else {
                // 스위치를 끈 경우: 예약된 알림 모두 취소
                await notificationService
                    .cancelNotificationsForSchedule(schedule);
              }
            } catch (e) {
              logger.e('스케줄 활성화/비활성화 실패: $e');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류 발생: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // 삭제 확인 다이얼로그 (이전 응답과 동일)
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
