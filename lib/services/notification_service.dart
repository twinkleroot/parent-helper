import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule.dart';
import '../utils/logger.dart';

// 채널 객체를 클래스 변수로 분리하여 정의
final AndroidNotificationChannel highImportanceChannel =
  AndroidNotificationChannel(
    'pickup_channel_v8', // id (가장 중요)
    '등하원 알림 (v8)', // name
    description: '등하원 시간 알림 채널', // description
    importance: Importance.max,
    playSound: true,
    // 커스텀 사운드 설정 (android/app/src/main/res/raw/alarm1.mp3 필요)
    // 파일 확장자는 제외하고 이름만 입력합니다.
    sound: const RawResourceAndroidNotificationSound('alarm1'),
    enableVibration: true,
    // 강력한 커스텀 진동 패턴 설정
    // [대기, 진동, 대기, 진동, ...] 단위는 ms
    // 0ms 대기 -> 2000ms(2초) 강한 진동 -> 500ms 대기 -> 2000ms(2초) 강한 진동
    vibrationPattern: Int64List.fromList([0, 2000, 500, 2000, 500, 2000, 500, 2000, 500, 2000, 500]),
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

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

    // 1. 안드로이드 플러그인 인스턴스 가져오기
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // 2. OS에 고중요도 알림 채널을 명시적으로 생성
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(highImportanceChannel);
    }

    // 3. 플러그인 초기화
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 4. 권한 요청
    // Android 13+ (API 33) 알림 권한 요청 (팝업)
    await androidPlugin?.requestNotificationsPermission();
    // Android 12+ (API 31) '정확한 알람' 특별 권한 요청 (설정 화면으로 이동)
    await androidPlugin?.requestExactAlarmsPermission();

    // iOS 알림 권한 요청
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // 알림 동기화: 기존 알림을 모두 지우고, 현재 유효한 일정만 다시 등록
  Future<void> resyncNotifications(List<Schedule> activeSchedules) async {
    logger.i('🔄 알림 동기화 시작: 기존 알림 초기화 후 ${activeSchedules.length}개 재등록');

    // 1. 기존에 예약된 모든 알림(고아 알림 포함) 취소
    await cancelAllNotifications();

    // 2. 현재 유효한 일정만 다시 예약
    for (var schedule in activeSchedules) {
      if (schedule.isEnabled) {
        await scheduleWeeklyNotification(schedule);
      }
    }
    logger.i('✅ 알림 동기화 완료');
  }

  Future<void> cancelAllNotifications() async {
    logger.w('🚫 예약된 모든 알림을 취소합니다.');
    await flutterLocalNotificationsPlugin.cancelAll();
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

      tz.TZDateTime nextScheduleTime = _nextInstanceOfDayTime(
        day,
        hour,
        minute,
        now,
        leadTimeMinutes,
      );

      // 리드 타임 적용
      tz.TZDateTime notificationTime = nextScheduleTime.subtract(Duration(minutes: leadTimeMinutes));

      // 알림 내용
      String title = '${schedule.childName} ${schedule.type == ScheduleType.pickup ? "픽업" : "하원"} 알림';
      String body =
          '$leadTimeMinutes분 뒤 (${nextScheduleTime.hour.toString().padLeft(2, '0')}:${(nextScheduleTime.minute).toString().padLeft(2, '0')}) ${schedule.institutionName} ${schedule.type == ScheduleType.pickup ? "픽업" : "하원"} 시간입니다.';

      logger.i(
        '🔔 알림 예약 로그 --- \n'
            '  - 스케줄: ${schedule.childName} (${schedule.id})\n'
            '  - 기준 요일: $day (1:월, 7:일)\n'
            '  - 현재 시간: $now\n'
            '  - 하원/등원 시간 (계산됨): $nextScheduleTime\n'
            '  - 알림 울릴 시간 (계산됨): $notificationTime\n'
            '  - 알림 ID: $notificationId',
      );

      // 주간 반복 알림 예약
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        notificationTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            highImportanceChannel.id, // ID 일치
            highImportanceChannel.name, // 이름 일치
            channelDescription: highImportanceChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            sound: highImportanceChannel.sound,
            playSound: highImportanceChannel.playSound,
            enableVibration: highImportanceChannel.enableVibration,
            vibrationPattern: highImportanceChannel.vibrationPattern,
            category: AndroidNotificationCategory.alarm,
            icon: '@mipmap/ic_launcher',
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
    logger.w('🚫 알림 취소: ${schedule.childName} (${schedule.id})');
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

    // 2. 최종 알림이 울릴 시간 (리드타임 적용)
    final tz.TZDateTime finalNotificationTime = scheduleTime.subtract(Duration(minutes: leadTimeMinutes));

    if (scheduleTime.weekday == dayOfWeek && !finalNotificationTime.isBefore(now)) {
      return scheduleTime;
    }

    // 4. (아닌 경우) 오늘 알림은 이미 지났거나, 오늘이 해당 요일이 아님
    //    내일부터 시작하여, 다음 주기의 해당 요일을 찾음

    // 4-1. 내일 날짜로 리셋
    scheduleTime = scheduleTime.add(const Duration(days: 1));

    // 4-2. 해당 요일이 될 때까지 하루씩 더함
    while (scheduleTime.weekday != dayOfWeek) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    // 5. 다음 주기의 해당 요일/시간을 반환
    return scheduleTime;
  }
}
