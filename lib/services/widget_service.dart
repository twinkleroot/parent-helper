import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';

class WidgetService {
  static const String _androidWidgetName = 'ScheduleWidget'; // 안드로이드 위젯 Provider 클래스명

  // 데이터를 위젯으로 전송
  Future<void> updateWidget(List<Schedule> allSchedules) async {
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    // 1. 오늘의 일정 중, 현재 시간 이후의 일정만 필터링
    final todaySchedules = allSchedules.where((s) {
      if (!s.isEnabled) return false;
      if (!s.daysOfWeek.contains(todayWeekday)) return false;

      final scheduleTime = DateTime(now.year, now.month, now.day, s.time.hour, s.time.minute);
      return scheduleTime.isAfter(now);
    }).toList();

    // 2. 시간순 정렬
    todaySchedules.sort((a, b) {
      int timeA = a.time.hour * 60 + a.time.minute;
      int timeB = b.time.hour * 60 + b.time.minute;
      return timeA.compareTo(timeB);
    });

    // 3. 위젯에 표시할 데이터 준비
    String title = '오늘의 남은 일정';
    String message = '일정이 없습니다.';
    String subMessage = '';

    if (todaySchedules.isNotEmpty) {
      final nextSchedule = todaySchedules.first;
      final timeStr = DateFormat('a h:mm', 'ko_KR').format(
          DateTime(now.year, now.month, now.day, nextSchedule.time.hour, nextSchedule.time.minute));

      title = timeStr; // 예: 오후 4:00
      message = '${nextSchedule.childName} - ${nextSchedule.institutionName}';
      subMessage = nextSchedule.type.name == 'pickup' ? '등원/픽업' : '하원';

      if (todaySchedules.length > 1) {
        subMessage += ' (+${todaySchedules.length - 1}개 더 있음)';
      }
    } else {
      // 오늘 남은 일정이 없으면 내일 일정이라도 보여줄지 결정 (여기선 "일정 없음" 처리)
      title = "남은 일정 없음";
      message = "오늘도 고생하셨어요!";
    }

    // 4. 데이터 저장 (키-값 쌍)
    await HomeWidget.saveWidgetData<String>('title', title);
    await HomeWidget.saveWidgetData<String>('message', message);
    await HomeWidget.saveWidgetData<String>('subMessage', subMessage);

    // 5. 위젯 업데이트 트리거
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidWidgetName,
      iOSName: _androidWidgetName, // iOS용 위젯 이름
    );
  }
}