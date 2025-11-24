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
    // 시간 포맷을 분리하기 위해 DateTime 객체 생성
    final dt = DateTime(2023, 1, 1, schedule.time.hour, schedule.time.minute);
    // 오전/오후
    final amPm = DateFormat('a', 'ko_KR').format(dt);
    // 10:40
    final timeOnly = DateFormat('h:mm', 'ko_KR').format(dt);
    final leadTime = schedule.notificationLeadTimeInMinutes;

    final String memoText = schedule.memo.isNotEmpty
        ? _truncateMemo(schedule.memo) // 100자 제한 적용
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        // Card 자체에 패딩을 주어 내용이 잘리지 않도록 보호
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          onTap: onTap,
          onLongPress: () {
            _showDeleteConfirmation(context, schedule);
          },
          // 시간을 2줄로 명확하게 고정하여 표시
          leading: Container(
            width: 60, // 너비 고정
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: schedule.type == ScheduleType.pickup
                  ? Colors.blue.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: schedule.type == ScheduleType.pickup
                    ? Colors.blue.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amPm, // "오전" 또는 "오후"
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  timeOnly, // "10:40"
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: schedule.type == ScheduleType.pickup
                        ? Colors.blue.shade800
                        : Colors.green.shade800,
                    height: 1.1, // 줄 간격 조절
                  ),
                ),
              ],
            ),
          ),
          // 내용이 길어져도 잘리지 않도록 설정
          title: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              '${schedule.childName} - ${schedule.institutionName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          subtitle: RichText(
            text: TextSpan(
              // 기본 스타일 (subtitle의 기본 스타일을 따름)
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.3, // 줄 간격 확보
              ),
              children: [
                // 1. 일정 정보
                TextSpan(
                  text: '매주 [${_formatDays(schedule.daysOfWeek)}] ($leadTime분 전 알림)',
                ),

                // 2. 메모 정보 (메모가 있을 경우에만)
                if (memoText.isNotEmpty)
                  TextSpan(
                    text: '\n$memoText', // \n으로 줄바꿈
                    style: TextStyle(
                      // 약간 흐린 색상 + 이탤릭체
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),

          trailing: Transform.scale(
            scale: 0.9,
            child: Switch(
              value: schedule.isEnabled,
              onChanged: (value) async {
                final firestoreService = context.read<FirestoreService>();
                final notificationService = context.read<NotificationService>();

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
                  isEnabled: value,
                );

                try {
                  await firestoreService.updateSchedule(updatedSchedule);
                  if (value) {
                    await notificationService
                        .scheduleWeeklyNotification(updatedSchedule);
                  } else {
                    await notificationService
                        .cancelNotificationsForSchedule(schedule);
                  }
                } catch (e) {
                  logger.e('스케줄 토글 오류: $e');
                }
              },
            ),
          ),
          // isThreeLine을 true로 주어 텍스트 공간 확보 (메모가 없어도 넉넉하게)
          isThreeLine: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          // 최소 세로 패딩 확보
          minVerticalPadding: 12,
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

                if (context.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                logger.e('삭제 중 오류 발생: $e');
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 중 오류 발생: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
