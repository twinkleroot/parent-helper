import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop()을 위해 추가
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ad_service.dart';
import '../services/firestore_service.dart';
import '../services/popup_service.dart';
import '../models/app_config.dart';
import '../utils/logger.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // 홈 화면으로 넘길 설정 데이터
  AppConfig? _appConfig;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // 광고 로드와 권한 확인 로직 분리
  Future<void> _initializeApp() async {
    // 1. SharedPreferences로 첫 실행 여부 확인
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = prefs.getBool('is_first_run') ?? true;

    // FirestoreService 초기화 (uid는 아직 없으므로 null)
    final firestoreService = FirestoreService(uid: null);
    // AppConfig 로드
    final configFuture = firestoreService.getAppConfig();
    final adService = Provider.of<AdService>(context, listen: false);
    // 최소 대기 시간 (1.5초)
    final minWait = Future.delayed(const Duration(milliseconds: 1500));

    Future<void> adWait;
    if (isFirstRun) {
      // [첫 실행인 경우]
      logger.i('앱 첫 실행입니다. 광고 로드를 건너뜁니다.');

      // 첫 실행 플래그를 false로 변경하여 저장
      await prefs.setBool('is_first_run', false);
      adWait = Future.value(); // 즉시 완료
      // 광고 없이 바로 권한 확인으로 이동
    } else {
      // 광고 로드 대기 (최대 3초)
      // 3초가 지나면 TimeoutException 대신 onTimeout이 실행되어 바로 리턴합니다.
      adWait = adService.preloadAds().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          logger.w('⏳ 광고 로드 시간 초과 (3초). 다음 화면으로 이동합니다.');
          return;
        },
      );
    }

    // 설정 로드, 광고 로드, 최소 대기 시간 병렬 처리
    final results = await Future.wait([configFuture, minWait, adWait]);
    _appConfig = results[0] as AppConfig; // 설정 저장

    // 2. 핵심 권한 확인 및 처리
    if (mounted) {
      // 1. 강제 업데이트 체크 (PopupService 사용)
      final popupService = PopupService();
      final bool isBlocked = await popupService.checkForceUpdate(context, _appConfig!);

      // 강제 업데이트 팝업이 뜨면 여기서 멈춤 (true 반환).
      // false여야 다음 단계(권한 확인)로 진행.
      if (!isBlocked) {
        await _checkPermissionAndProceed();
      }
    }
  }

  // 정확한 알람 권한 확인 및 요청 로직
  Future<void> _checkPermissionAndProceed() async {
    // 1. 권한 상태 확인
    var status = await Permission.scheduleExactAlarm.status;

    if (status.isGranted) {
      // 2. 권한이 이미 있으면 광고 표시 및 홈으로 이동
      _showAdAndNavigate();
    } else {
      // 3. 권한이 없으면 사용자에게 설정 요청 다이얼로그 표시
      _showPermissionDialog();
    }
  }

  // 권한 설정 안내 다이얼로그
  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.alarm_add, size: 48),
        title: const Text('필수 권한 안내'),
        content: const Text(
            '이 앱은 정확한 시간에 알림을 제공하기 위해 '
            '"알람 및 리마인더" 권한이 반드시 필요합니다. '
            '설정에서 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () {
              // 앱 종료
              SystemNavigator.pop();
            },
            child: const Text('앱 종료'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // 권한 설정 페이지로 이동
              // request()가 안드로이드 12+에서는 설정 페이지를 엽니다.
              var status = await Permission.scheduleExactAlarm.request();

              // 사용자가 설정 페이지에서 돌아왔을 때 다시 확인
              if (status.isGranted) {
                _showAdAndNavigate();
              } else {
                // 사용자가 여전히 거부하면 다시 다이얼로그 표시
                _checkPermissionAndProceed();
              }
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  // 광고 표시 및 네비게이션 로직
  void _showAdAndNavigate() {
    if (!mounted) return;
    final adService = Provider.of<AdService>(context, listen: false);

    // 광고가 로드되어 있으면 표시하고, 아니면(첫 실행 포함) 바로 이동
    adService.showAppOpenAdIfAvailable(
      onAdDismissed: _navigateToHome,
    );
  }

  void _navigateToHome() {
    if (mounted) {
      // [수정] AuthGate로 이동할 때 arguments로 AppConfig 전달 가능하지만,
      // 여기서는 Provider 구조상 HomeScreen에서 다시 로드하거나,
      // 전역 상태로 관리하는 게 좋습니다.
      // 간단하게 HomeScreen에서 다시 체크하도록 합니다. (PopupService가 HomeScreen에서 다시 동작)

      // 또는 AuthGate -> HomeScreen으로 이어지는 흐름에서
      // HomeScreen init 시점에 팝업 체크를 하도록 합니다.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 이미지가 로드되기 전 배경색 (이미지 배경색과 맞추는 것 추천)
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand, // 화면 전체 채우기
        children: [
          // 1. 전체 화면 배경 이미지
          Image.asset(
            'assets/images/loading.png',
            // fit: BoxFit.cover, // 이미지가 화면을 꽉 채우도록 설정 (비율 유지하며 잘릴 수 있음)
            // 만약 이미지가 잘리지 않고 모두 보여야 한다면 BoxFit.contain 사용 후 배경색 조정
            fit: BoxFit.contain,
          ),

          // 2. 로딩 인디케이터 (이미지 위에 표시)
          const Positioned(
            bottom: 100, // 하단에서 100px 위로
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                // 이미지 색상에 따라 인디케이터 색상이 잘 보이도록 조정 필요
                color: Colors.white, // 또는 Colors.orange
              ),
            ),
          ),
        ],
      ),
    );
  }
}

