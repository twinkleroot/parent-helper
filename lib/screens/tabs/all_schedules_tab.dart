import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schedule.dart';
import '../../services/firestore_service.dart';
import '../../screens/add_edit_schedule_screen.dart';
import '../../widgets/schedule_list_item.dart'; // 위젯 (생략)

class AllSchedulesTab extends StatelessWidget {
  const AllSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      body: StreamBuilder<List<Schedule>>(
        stream: firestoreService.getSchedules(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '등록된 일정이 없습니다.\n하단의 + 버튼으로 일정을 추가하세요.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final schedules = snapshot.data!;

          return ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return ScheduleListItem(
                schedule: schedule,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditScheduleScreen(scheduleToEdit: schedule),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // 새 스케줄 등록 화면으로 이동
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddEditScheduleScreen(),
            ),
          );
        },
      ),
    );
  }
}
