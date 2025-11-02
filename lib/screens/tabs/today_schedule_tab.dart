import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schedule.dart';
import '../../services/firestore_service.dart';
import '../../widgets/schedule_list_item.dart'; // 위젯 (생략)

class TodayScheduleTab extends StatelessWidget {
  const TodayScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final today = DateTime.now().weekday; // 월:1 ~ 일:7

    return StreamProvider<List<Schedule>>.value(
      value: firestoreService.getSchedules(),
      initialData: const [],
      builder: (context, child) {
        // 오늘 요일에 해당하는 스케줄만 필터링
        final schedules = Provider.of<List<Schedule>>(context)
            .where((s) => s.daysOfWeek.contains(today) && s.isEnabled)
            .toList();

        // 시간순으로 정렬
        schedules.sort((a, b) {
          int aTime = a.time.hour * 60 + a.time.minute;
          int bTime = b.time.hour * 60 + b.time.minute;
          return aTime.compareTo(bTime);
        });

        if (schedules.isEmpty) {
          return const Center(child: Text('오늘 등록된 일정이 없습니다.'));
        }

        return ListView.builder(
          itemCount: schedules.length,
          itemBuilder: (context, index) {
            // ScheduleListItem 위젯을 만들어 표시 (구현 생략)
            return ScheduleListItem(schedule: schedules[index]);
          },
        );
      },
    );
  }
}
