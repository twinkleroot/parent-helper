import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule.dart';
import '../utils/logger.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Android 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Android 13+ (API 33) 알림 권한 요청 (팝업)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Android 12+ (API 31) '정확한 알람' 특별 권한 요청 (설정 화면으로 이동)
    // 이 권한이 없으면 exactAllowWhileIdle 모드가 실패합니다.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    // iOS 알림 권한 요청 (init에서 이미 true로 설정했지만, 명시적으로 재확인 가능)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // 스케줄 객체를 기반으로 주간 반복 알림 예약
  Future<void> scheduleWeeklyNotification(Schedule schedule) async {
    if (!schedule.isEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final int leadTimeMinutes = schedule.notificationLeadTimeInMinutes;

    // TimeOfDay를 tz.TZDateTime으로 변환
    final int hour = schedule.time.hour;
    final int minute = schedule.time.minute;

    for (int day in schedule.daysOfWeek) {
      // 알림 ID 생성 (스케줄 ID와 요일을 조합하여 고유하게 만듦)
      int notificationId = _generateNotificationId(schedule.id, day);

      // 다음 알림 시간 계산
      tz.TZDateTime scheduledDate = _nextInstanceOfDayTime(
        day,
        hour,
        minute,
        now,
      );

      // 리드 타임 적용
      scheduledDate = scheduledDate.subtract(Duration(minutes: leadTimeMinutes));

      // 알림 내용
      String title = '${schedule.childName} ${schedule.type == ScheduleType.pickup ? "픽업" : "하원"} 알림';
      String body =
          '$leadTimeMinutes분 뒤 (${scheduledDate.hour.toString().padLeft(2, '0')}:${(scheduledDate.minute).toString().padLeft(2, '0')}) ${schedule.institutionName} 차량이 도착합니다.';

      // 주간 반복 알림 예약
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pickup_channel_id',
            '등하원 알림',
            channelDescription: '등하원 차량 도착 알림 채널',
            importance: Importance.max,
            priority: Priority.high,
            sound: null,
            // sound: RawResourceAndroidNotificationSound('notification_sound'), // res/raw/notification_sound.wav
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),

        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // 매주 (요일 + 시간) 반복
      );
    }
  }

  // 특정 스케줄에 연결된 모든 알림 취소
  Future<void> cancelNotificationsForSchedule(Schedule schedule) async {
    for (int day in schedule.daysOfWeek) {
      int notificationId = _generateNotificationId(schedule.id, day);
      try {
        await flutterLocalNotificationsPlugin.cancel(notificationId);
      } catch (e) {
        logger.e('Error cancelling notification $notificationId: $e');
      }
    }
  }

  // 스케줄 ID와 요일로부터 고유한 알림 ID 생성
  int _generateNotificationId(String scheduleId, int dayOfWeek) {
    // scheduleId의 해시코드와 요일을 조합 (간단한 예시)
    // 32비트 정수 범위 내로 유지해야 함
    return (scheduleId.hashCode % 1000000 + dayOfWeek) % 2147483647;
  }

  // 다음 알림 시간 계산 헬퍼
  tz.TZDateTime _nextInstanceOfDayTime(
      int dayOfWeek, int hour, int minute, tz.TZDateTime now) {
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 이미 시간이 지났으면 다음 날로
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 해당 요일이 될 때까지 1일씩 추가
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
