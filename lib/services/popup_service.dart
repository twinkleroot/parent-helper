import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_config.dart';
import '../widgets/user_guide_dialog.dart';
import '../utils/logger.dart';

class PopupService {
  // 버전 문자열 비교 (ex: 1.0.0 vs 1.0.1)
  // current < target 이면 true
  bool _isVersionLower(String current, String target) {
    List<int> cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> tParts = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int c = i < cParts.length ? cParts[i] : 0;
      int t = i < tParts.length ? tParts[i] : 0;
      if (c < t) return true;
      if (c > t) return false;
    }
    return false;
  }

  // String 날짜를 파싱하여 기간 확인 (Asia/Seoul 기준)
  bool _isWithinDateRange(String? startStr, String? endStr) {
    // 1. null 또는 빈 문자열 체크 (방어 코드)
    if (startStr == null || startStr.trim().isEmpty ||
        endStr == null || endStr.trim().isEmpty) {
      return false;
    }

    try {
      // 2. 설정된 날짜 파싱 (ISO 8601 형식 권장)
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);

      // 3. 현재 서울 시간 가져오기
      final nowSeoul = tz.TZDateTime.now(tz.getLocation('Asia/Seoul'));

      // 4. 비교
      return nowSeoul.isAfter(start) && nowSeoul.isBefore(end);
    } catch (e) {
      // 포맷 에러 등 파싱 실패 시 로그 남기고 false 반환
      logger.e('날짜 파싱 오류: $e (start: $startStr, end: $endStr)');
      return false;
    }
  }

  // [스플래시] 강제 업데이트 체크
  Future<bool> checkForceUpdate(BuildContext context, AppConfig config) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // 1. 날짜 체크
    if (!_isWithinDateRange(config.forceUpdateStart, config.forceUpdateEnd)) {
      return false; // 기간 아님
    }

    // 2. 버전 체크 (현재 버전 < 강제 업데이트 버전)
    if (_isVersionLower(currentVersion, config.minVersion)) {
      if (!context.mounted) return false;

      // 강제 업데이트 팝업 표시 (끄기 없음)
      await showDialog(
        context: context,
        barrierDismissible: false, // 바깥 터치 막음
        builder: (ctx) => WillPopScope( // 뒤로가기 막음
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text('필수 업데이트 안내'),
            content: Text('안정적인 서비스 이용을 위해 최신 버전(${config.latestVersion})으로 업데이트가 필요합니다.\n\n현재 버전: $currentVersion'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  _launchStore(config.storeUrl);
                },
                child: const Text('업데이트 하러 가기'),
              ),
            ],
          ),
        ),
      );
      return true; // 팝업 띄움 (진행 중단)
    }
    return false; // 통과
  }

  // [메인] 업데이트 권장, 공지사항, 가이드 체크
  Future<void> checkNoticesAndGuide(BuildContext context, AppConfig config) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final prefs = await SharedPreferences.getInstance();

    // 1. 사용자 가이드 (앱 최초 실행 시)
    bool isFirstGuideShown = prefs.getBool('is_user_guide_shown') ?? false;
    if (!isFirstGuideShown) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => const UserGuideDialog(),
        );
        await prefs.setBool('is_user_guide_shown', true);
      }
    }

    // 2. 업데이트 권장 (기간 내 & 버전 낮음)
    if (_isWithinDateRange(config.updateNoticeStart, config.updateNoticeEnd) &&
        _isVersionLower(currentVersion, config.latestVersion)) {
      if (!context.mounted) return;

      // 오늘 하루 보지 않기 등을 구현하려면 SharedPreferences 추가 필요
      // 여기서는 단순 표시
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('새로운 버전 업데이트'),
          content: Text('최신 버전(${config.latestVersion})이 출시되었습니다.\n지금 업데이트 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('나중에', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                _launchStore(config.storeUrl);
                Navigator.pop(ctx);
              },
              child: const Text('지금 업데이트'),
            ),
          ],
        ),
      );
    }

    // 3. 일반 공지사항 (기간 내)
    if (_isWithinDateRange(config.noticeStart, config.noticeEnd)) {
      // 이미 본 공지인지 체크 (예: 공지 ID나 날짜로 저장)
      // 여기서는 매번 띄우는 예시 (실제론 '다시 보지 않기' 필요)
      String noticeKey = 'notice_${config.noticeStart}';
      bool isNoticeSeen = prefs.getBool(noticeKey) ?? false;

      if (!isNoticeSeen && context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(config.noticeTitle),
            content: SingleChildScrollView(child: Text(config.noticeContent)),
            actions: [
              TextButton(
                onPressed: () async {
                  // 다시 보지 않기 (로컬 저장)
                  await prefs.setBool(noticeKey, true);
                  Navigator.pop(ctx);
                },
                child: const Text('다시 보지 않기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> checkReviewPopup(BuildContext context, AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();

    // 이미 리뷰를 남겼거나 '다시 보지 않기'를 누른 경우 패스
    bool hasReviewed = prefs.getBool('has_reviewed') ?? false;
    if (hasReviewed) return;

    // 실행 횟수 증가 및 저장
    int launchCount = prefs.getInt('app_launch_count') ?? 0;
    launchCount++;
    await prefs.setInt('app_launch_count', launchCount);

    logger.i('앱 실행 횟수 카운트: $launchCount');

    // 10회 실행될 때마다 팝업 표시
    if (launchCount > 0 && launchCount % 10 == 0) {
      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text('앱이 마음에 드시나요?', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: const Text(
              '등하원 알리미를 꾸준히 사용해 주셔서 정말 감사합니다!\n\n'
                  '1분만 시간을 내어 따뜻한 리뷰와 별점을 남겨주시면, '
                  '개발자에게 정말 큰 힘이 됩니다. 🥺💛'
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('has_reviewed', true); // 다시 보지 않기
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('다시 보지 않기', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // 나중에 (다음 10회째에 다시 뜸)
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade100,
                foregroundColor: Colors.black87,
              ),
              onPressed: () async {
                await prefs.setBool('has_reviewed', true); // 스토어로 이동하면 리뷰 작성한 것으로 간주
                _launchStore(config.storeUrl);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('⭐️ 리뷰 작성하기'),
            ),
          ],
        ),
      );
    }
  }

  void _launchStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      logger.e('스토어 연결 실패: $url');
    }
  }
}