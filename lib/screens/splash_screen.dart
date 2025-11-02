import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ad_service.dart';
import 'auth_gate.dart';
import '../utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _adsLoaded = false;

  @override
  void initState() {
    super.initState();
    _preloadDataAndAds();
  }

  Future<void> _preloadDataAndAds() async {
    try {
      // 광고 서비스 가져오기 (listen: false)
      final adService = context.read<AdService>();

      // 스플래시 화면이 최소 1.5초간 보이도록 보장
      await Future.wait([
        adService.preloadAds(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);

      // 광고 로드가 완료되었음을 표시
      if (mounted) {
        setState(() {
          _adsLoaded = true;
        });
      }

      // 앱 오프닝 광고 표시 시도
      adService.showAppOpenAdIfAvailable(
        // named parameter로 onAdDismissed 전달
        onAdDismissed: () {
          _navigateToHome();
        },
      );
    } catch (e) {
      logger.e('Error preloading ads: $e');
      // 광고 로드에 실패하더라도 홈으로 이동
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (mounted) {
      // AuthGate로 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // adsLoaded 상태와 관계없이 스플래시 UI는 항상 동일
    // 로딩 로직은 initState와 _preloadDataAndAds에서 처리
    return const Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              '등하원 알리미',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

