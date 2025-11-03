import 'dart:typed_data';
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
        leadTimeMinutes
      );

      // 리드 타임 적용
      scheduledDate = scheduledDate.subtract(Duration(minutes: leadTimeMinutes));

      // 알림 내용
      String title = '${schedule.childName} ${schedule.type == ScheduleType.pickup ? "픽업" : "하원"} 알림';
      String body =
          '$leadTimeMinutes분 뒤 (${scheduledDate.hour.toString().padLeft(2, '0')}:${(scheduledDate.minute).toString().padLeft(2, '0')}) ${schedule.institutionName} ${schedule.type == ScheduleType.pickup ? "픽업" : "하원"} 시간입니다.';

      // 주간 반복 알림 예약
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'pickup_channel_id',
            '등하원 알림',
            channelDescription: '등하원 차량 도착 알림 채널',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true, // 진동 활성화
            vibrationPattern: Int64List.fromList([0, 500, 500, 500]), // 기본 진동 패턴
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
      int dayOfWeek,
      int hour,
      int minute,
      tz.TZDateTime now,
      int leadTimeMinutes,
    ) {
    // 1. 오늘 날짜 + 요청 시간으로 기준 날짜 생성
    tz.TZDateTime scheduleTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // 2. 요청 요일이 될 때까지 하루씩 더함
    while (scheduleTime.weekday != dayOfWeek) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    // 3. (중요) 계산된 시간이 이미 "현재"보다 과거인 경우, 다음 주로 넘김
    //    (예: 월요일 10시에 월요일 10시 5분 알림(리드타임 10분)을 설정하면
    //     실제 알림 시간은 9시 55분이므로 과거가 됨 -> 다음 주로 넘겨야 함)
    //    리드 타임을 적용한 최종 시간을 기준으로 비교
    final tz.TZDateTime finalNotificationTime = scheduleTime.subtract(Duration(minutes: leadTimeMinutes));
    if (finalNotificationTime.isBefore(now)) {
      scheduleTime = scheduleTime.add(const Duration(days: 7));
    }

    // 'zonedSchedule' 함수가 리드타임을 적용할 수 있도록
    // 순수한 "다음 스케줄 시간 (리드타임 적용 전)"을 반환
    return scheduleTime; // zonedSchedule 내부에서 리드타임을 빼도록 롤백
  }
}
