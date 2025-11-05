import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop()을 위해 추가
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart'; // [추가]
import '../services/ad_service.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // [수정] 광고 로드와 권한 확인 로직 분리
  Future<void> _initializeApp() async {
    // 1. 광고 로드와 최소 시간 1.5초를 병렬로 대기
    // (권한 확인이 오래 걸릴 수 있으므로 광고 로드는 미리 시작)
    await Future.wait([
      Provider.of<AdService>(context, listen: false).preloadAds(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    // 2. 핵심 권한 확인 및 처리
    if (mounted) {
      await _checkPermissionAndProceed();
    }
  }

  // [추가] 정확한 알람 권한 확인 및 요청 로직
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

  // [추가] 권한 설정 안내 다이얼로그
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

  // [추가] 광고 표시 및 네비게이션 로직
  void _showAdAndNavigate() {
    if (!mounted) return;
    final adService = Provider.of<AdService>(context, listen: false);
    adService.showAppOpenAdIfAvailable(
      onAdDismissed: _navigateToHome,
    );
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 80, color: Colors.limeAccent),
            SizedBox(height: 20),
            Text('등하원 알리미',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.limeAccent)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

