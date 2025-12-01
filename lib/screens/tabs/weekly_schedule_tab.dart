import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';
import '../../services/data_repository.dart';
import '../add_edit_schedule_screen.dart';

class WeeklyScheduleTab extends StatefulWidget {
  const WeeklyScheduleTab({super.key});

  @override
  State<WeeklyScheduleTab> createState() => _WeeklyScheduleTabState();
}

class _WeeklyScheduleTabState extends State<WeeklyScheduleTab> {
  late DateTime _mondayOfWeek;

  // 형광펜 색상 팔레트 (노랑, 하늘, 연보라, 연두, 주황, 분홍)
  final List<Color> _highlighterColors = [
    Colors.yellow.shade200,
    Colors.lightBlue.shade200,
    Colors.purple.shade200,
    Colors.lightGreen.shade200,
    Colors.orange.shade200,
    Colors.pink.shade200,
  ];

  @override
  void initState() {
    super.initState();
    // 현재 날짜를 기준으로 이번 주의 월요일을 계산
    final now = DateTime.now();
    _mondayOfWeek = now.subtract(Duration(days: now.weekday - 1));
  }

  // 날짜 갱신 로직
  void _updateWeekBase() {
    final now = DateTime.now();
    _mondayOfWeek = now.subtract(Duration(days: now.weekday - 1));
  }

  // 자녀 ID를 기반으로 고정된 형광펜 색상을 반환하는 함수
  Color _getHighlighterColor(String childId) {
    if (childId.isEmpty) return _highlighterColors[0];
    // ID의 해시코드를 사용하여 색상 리스트 인덱스를 결정 (항상 같은 색상 보장)
    final index = childId.hashCode.abs() % _highlighterColors.length;
    return _highlighterColors[index];
  }

  // 날짜별 일정 리스트 빌드
  Widget _buildDailyScheduleRow(
      BuildContext context, DateTime date, List<Schedule> allSchedules) {
    // 이 날짜(요일)에 해당하는 일정 필터링
    final daySchedules = allSchedules
        .where((s) => s.daysOfWeek.contains(date.weekday))
        .toList();

    // 시간순 정렬
    daySchedules.sort((a, b) {
      int timeA = a.time.hour * 60 + a.time.minute;
      int timeB = b.time.hour * 60 + b.time.minute;
      return timeA.compareTo(timeB);
    });

    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final dateColor = isToday
        ? Theme.of(context).colorScheme.primary
        : (date.weekday == DateTime.sunday
        ? Colors.red
        : (date.weekday == DateTime.saturday
        ? Colors.blue
        : Colors.grey.shade700));

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 왼쪽: 날짜/요일 영역
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isToday ? dateColor.withOpacity(0.1) : Colors.transparent,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('M/d').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: dateColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('E', 'ko_KR').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dateColor,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 오른쪽: 일정 리스트 영역
            Expanded(
              child: daySchedules.isEmpty
                  ? const Center(
                child: Text(
                  '-',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: daySchedules.map((schedule) {
                  return _buildSimpleScheduleItem(context, schedule);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 간소화된 일정 아이템 위젯
  Widget _buildSimpleScheduleItem(BuildContext context, Schedule schedule) {
    // 시간 포맷 (오전 9:00 형태)
    final dt = DateTime(2023, 1, 1, schedule.time.hour, schedule.time.minute);
    final timeStr = DateFormat('a h:mm', 'ko_KR').format(dt);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        // 일정 상세(수정) 화면으로 이동
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddEditScheduleScreen(
              scheduleToEdit: schedule,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade50,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 시간
            SizedBox(
              width: 75,
              child: Text(
                timeStr,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
            // 구분선 (작게)
            Container(
              width: 3,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: schedule.type == ScheduleType.pickup
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.green.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 내용
            Expanded(
              child: Row(
                children: [
                  // [수정] 자녀 이름 형광펜 효과
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      // 자녀 ID별 고유 형광펜 색상 (투명도 조절)
                      color: _getHighlighterColor(schedule.childId).withOpacity(isDark ? 0.3 : 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      schedule.childName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schedule.institutionName,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // 알림 활성화 아이콘
            if (schedule.isEnabled)
              Icon(
                Icons.notifications_active,
                size: 16,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              )
            else
              const Icon(
                Icons.notifications_off_outlined,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 상태 변경 시 이 탭을 리빌드하도록 구독합니다.
    // 이게 없으면 로그인 후에도 로컬 DB(빈 데이터)를 계속 보여줄 수 있습니다.
    Provider.of<AppUser?>(context);

    final dataRepository = Provider.of<DataRepository>(context);

    return StreamBuilder<List<Schedule>>(
      stream: dataRepository.getAllSchedules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allSchedules = snapshot.data ?? [];

        // 리빌드 시 날짜 기준도 갱신
        _updateWeekBase();

        // 월~일 날짜 리스트 생성
        final weekDays = List.generate(7, (index) => _mondayOfWeek.add(Duration(days: index)));

        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: weekDays.map((date) {
            return _buildDailyScheduleRow(context, date, allSchedules);
          }).toList(),
        );
      },
    );
  }
}