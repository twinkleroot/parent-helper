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

  @override
  void initState() {
    super.initState();
    _preloadDataAndAds();
  }

  Future<void> _preloadDataAndAds() async {
    try {
      // 광고 서비스 가져오기 (listen: false)
      final adService = context.read<AdService>();

      // 1. 광고 로드 "시작"
      final adLoadFuture = adService.preloadAds();
      // 2. 최소 스플래시 시간(1.5초) "시작"
      final minSplashFuture = Future.delayed(const Duration(milliseconds: 1500));

      // 3. [광고 로드 완료]와 [최소 1.5초 경과]를 "모두" 기다림
      await Future.wait([
        adLoadFuture,
        minSplashFuture,
      ]);

      // _adsLoaded 상태 체크 제거 (이미 완료됨)
      if (mounted) {
        // 이 시점에는 1.5초가 지났고, 광고 로드도 완료(성공 또는 실패)됨.
        // AdService가 로드 성공 여부(_isAppOpenAdLoaded)를 알고 있음.
        adService.showAppOpenAdIfAvailable(
          onAdDismissed: () {
            _navigateToHome();
          },
        );
      }
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

