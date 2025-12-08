import 'dart:async'; // Completer를 위해 import 추가
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // WidgetsBinding을 위해 필요
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

// 광고 로드 및 표시를 관리하는 서비스
class AdService with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  bool _isAppOpenAdShowing = false;
  bool _isAppOpenAdLoaded = false;

  BannerAd? _bannerAdHome;
  BannerAd? _bannerAdList;
  BannerAd? _bannerAdMgmt;
  BannerAd? _bannerAdWeekly;

  // 전면 광고 관련 변수
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  // 광고 빈도 조절을 위한 카운터
  int _actionCount = 0;
  // 3번 저장할 때마다 1번 광고 표시 (사용자 요청 반영)
  static const int _adFrequency = 3;

  // 전면 광고가 마지막으로 닫힌 시간 기록
  DateTime? _lastInterstitialDismissedTime;

  // 다음 Warm Start 광고 스킵 여부 플래그
  bool _shouldSkipNextWarmStart = false;

  bool get isBannerAdHomeLoaded => _bannerAdHome != null;
  bool get isBannerAdListLoaded => _bannerAdList != null;
  bool get isBannerAdWeeklyLoaded => _bannerAdWeekly != null;

  BannerAd? get bannerAdHome => _bannerAdHome;
  BannerAd? get bannerAdList => _bannerAdList;
  BannerAd? get bannerAdMgmt => _bannerAdMgmt;
  BannerAd? get bannerAdWeekly => _bannerAdWeekly;

  // 광고 로드 완료를 보장하기 위한 Completer 추가
  Completer<void> _appOpenAdCompleter = Completer<void>();
  Completer<void> _bannerHomeCompleter = Completer<void>();
  Completer<void> _bannerListCompleter = Completer<void>();
  Completer<void> _bannerMgmtCompleter = Completer<void>();
  Completer<void> _bannerWeeklyCompleter = Completer<void>();

  // 생성자에서 앱 생명주기 옵저버 등록
  AdService() {
    WidgetsBinding.instance.addObserver(this);
  }

  // 앱 상태 변경 감지 (Warm Start)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드에서 포그라운드로 돌아올 때 (Resumed)
    if (state == AppLifecycleState.resumed) {
      _tryShowAdOnWarmStart();
    }
  }

  // 구글 로그인 등 외부 창을 열 때 호출하여 광고 차단
  void skipNextAppOpenAd() {
    _shouldSkipNextWarmStart = true;
    logger.i('다음 Warm Start 광고 스킵 예약됨');
  }

  // Warm Start 시 50% 확률로 광고 표시 시도
  void _tryShowAdOnWarmStart() {
    // 웹이거나 이미 광고가 떠있으면 스킵
    if (kIsWeb || _isAppOpenAdShowing) return;

    // 스킵 플래그 확인
    if (_shouldSkipNextWarmStart) {
      logger.i('🔥 Warm Start: 작업(로그인 등)으로 인해 광고 스킵');
      _shouldSkipNextWarmStart = false; // 플래그 리셋
      return;
    }

    // 전면 광고가 닫힌 지 5초가 지나지 않았다면, 오프닝 광고를 띄우지 않음
    if (_lastInterstitialDismissedTime != null) {
      final difference = DateTime.now().difference(_lastInterstitialDismissedTime!);
      if (difference.inSeconds < 5) {
        logger.i('🔥 Warm Start: 전면 광고 종료 직후(${difference.inSeconds}초)이므로 오프닝 광고 스킵');
        return;
      }
    }

    // 50% 확률 계산 (true or false)
    final bool shouldShow = Random().nextBool();

    if (shouldShow) {
      logger.i('🔥 Warm Start: 50% 당첨! 광고 표시를 시도합니다.');
      showAppOpenAdIfAvailable(onAdDismissed: () {
        logger.i('🔥 Warm Start: 광고 닫힘');
      });
    } else {
      logger.i('🔥 Warm Start: 광고 패스 (50% 확률 미당첨)');
      // 광고를 보여주지 않더라도, 로드된 광고가 없다면 다음을 위해 로드 시도
      if (!_isAppOpenAdLoaded) {
        _loadAppOpenAd();
      }
    }
  }

  String get _appOpenAdUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_APP_OPEN'] ?? 'ca-app-pub-9349659716533734/4410253994';
  }

  String get _interstitialAdUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_INTERSTITIAL'] ?? 'ca-app-pub-9349659716533734/6298050732';
  }

  String get _bannerUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_BANNER'] ?? 'ca-app-pub-9349659716533734/4984969065';
  }

  // 모든 광고를 미리 로드합니다. (스플래시 화면에서 호출)
  Future<void> preloadAds() async {
    // Completer 초기화
    _appOpenAdCompleter = Completer<void>();
    _bannerHomeCompleter = Completer<void>();
    _bannerListCompleter = Completer<void>();
    _bannerMgmtCompleter = Completer<void>();
    _bannerWeeklyCompleter = Completer<void>();

    // await 없이 로드 "시작"
    _loadAppOpenAd();
    _loadBannerAdHome();
    _loadBannerAdList();
    _loadBannerAdMgmt();
    _loadBannerAdWeekly();
    // 전면 광고도 미리 로드
    _loadInterstitialAd();

    // 병렬로 로드
    await Future.wait([
      _appOpenAdCompleter.future,
      _bannerHomeCompleter.future,
      _bannerListCompleter.future,
      _bannerMgmtCompleter.future,
      _bannerWeeklyCompleter.future,
    ]);
  }

  // --- 전면 광고 (Interstitial) 로직 ---
  void _loadInterstitialAd() {
    if (kIsWeb) return;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (Ad ad) {
          logger.i('전면 광고(Interstitial) 로드됨');
          _interstitialAd = ad as InterstitialAd;
          _isInterstitialAdLoaded = true;

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              logger.i('전면 광고 닫힘');
              // 광고가 닫힌 시간 기록
              _lastInterstitialDismissedTime = DateTime.now();

              ad.dispose();
              _isInterstitialAdLoaded = false;
              _interstitialAd = null;
              // 닫히면 다음을 위해 미리 로드
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              logger.e('전면 광고 표시 실패: $error');
              ad.dispose();
              _isInterstitialAdLoaded = false;
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          logger.e('전면 광고 로드 실패: $error');
          _isInterstitialAdLoaded = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  // 작업 완료 시 호출하는 메서드 (3회당 1회 노출)
  Future<bool> checkAndShowInterstitialAd() async {
    if (kIsWeb) return false;

    _actionCount++;
    logger.i('Action Count: $_actionCount / $_adFrequency');

    // 설정한 빈도(3회)에 도달했고, 광고가 로드되어 있다면
    if (_actionCount >= _adFrequency && _isInterstitialAdLoaded && _interstitialAd != null) {
      logger.i('전면 광고 표시 조건 충족!');
      _actionCount = 0; // 카운터 초기화
      await _interstitialAd!.show();
      return true; // 광고 표시함
    }

    // 광고가 로드되지 않았다면 다시 로드 시도
    if (!_isInterstitialAdLoaded) {
      _loadInterstitialAd();
    }

    return false; // 광고 표시 안 함
  }

  // --- 앱 오프닝 광고 (App Open) ---
  Future<void> _loadAppOpenAd() async {
    if (kIsWeb) {
      _appOpenAdCompleter.complete(); // 웹이면 즉시 완료
      return;
    }
    // 이미 로드되어 있거나 로딩 중이면 스킵
    if (_isAppOpenAdLoaded) {
      if (!_appOpenAdCompleter.isCompleted) _appOpenAdCompleter.complete();
      return;
    }

    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          logger.i('AppOpenAd loaded.');
          if (!_appOpenAdCompleter.isCompleted) _appOpenAdCompleter.complete();
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoaded = false;
          logger.e('AppOpenAd failed to load: $error');
          if (!_appOpenAdCompleter.isCompleted) _appOpenAdCompleter.complete();
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable({required VoidCallback onAdDismissed}) {
    if (_isAppOpenAdShowing || !_isAppOpenAdLoaded || _appOpenAd == null) {
      logger.w('AppOpenAd not available or already showing.');
      onAdDismissed();
      // 광고가 없을 경우 다음을 위해 로드 시도
      if (!_isAppOpenAdLoaded) _loadAppOpenAd();
      return;
    }

    // 앱이 포그라운드(Resumed) 상태인지 확인
    // 백그라운드 상태에서 show()를 호출하면 "The ad can not be shown when app is not in foreground" 에러 발생
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      logger.w('앱이 백그라운드 상태이므로 앱 오픈 광고를 표시하지 않습니다.');
      onAdDismissed(); // 광고를 건너뛰고 다음 화면으로 이동
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isAppOpenAdShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isAppOpenAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        onAdDismissed();
        // 광고가 닫히면 다음 광고를 미리 로드
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isAppOpenAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        logger.e('AppOpenAd failed to show: $error');
        onAdDismissed();
        _loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }

  // --- 배너 광고 (Tabs) ---
  Future<void> _loadBannerAdHome() async {
    if (kIsWeb) {
      _bannerHomeCompleter.complete();
      return;
    }
    _bannerAdHome = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          logger.i('Banner Home loaded.');
          if (!_bannerHomeCompleter.isCompleted) _bannerHomeCompleter.complete();
        },
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner Home failed: $err');
          ad.dispose();
          _bannerAdHome = null;
          if (!_bannerHomeCompleter.isCompleted) _bannerHomeCompleter.complete();
        },
      ),
    )..load();
  }

  Future<void> _loadBannerAdList() async {
    if (kIsWeb) {
      _bannerListCompleter.complete();
      return;
    }
    _bannerAdList = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          logger.i('Banner List loaded.');
          if (!_bannerMgmtCompleter.isCompleted) _bannerMgmtCompleter.complete();
        },
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner List failed: $err');
          ad.dispose();
          _bannerAdList = null;
          if (!_bannerMgmtCompleter.isCompleted) _bannerMgmtCompleter.complete();
        },
      ),
    )..load();
  }

  Future<void> _loadBannerAdMgmt() async {
    if (kIsWeb) {
      _bannerMgmtCompleter.complete(); // 로드 성공 시 complete
      return;
    }
    _bannerAdMgmt = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          logger.i('Banner Mgmt loaded.');
          if (!_bannerMgmtCompleter.isCompleted) _bannerMgmtCompleter.complete();
        },
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner Mgmt failed: $err');
          ad.dispose();
          _bannerAdMgmt = null;
          if (!_bannerMgmtCompleter.isCompleted) _bannerMgmtCompleter.complete();
        },
      ),
    )..load();
  }

  Future<void> _loadBannerAdWeekly() async {
    if (kIsWeb) {
      _bannerWeeklyCompleter.complete(); // 로드 성공 시 complete
      return;
    }
    _bannerAdWeekly = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          logger.i('Banner Weekly loaded.');
          if (!_bannerWeeklyCompleter.isCompleted) _bannerWeeklyCompleter.complete();
        },
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner Weekly failed: $err');
          ad.dispose();
          _bannerAdWeekly = null;
          if (!_bannerWeeklyCompleter.isCompleted) _bannerWeeklyCompleter.complete();
        },
      ),
    )..load();
  }

  // 홈 화면 종료 시 배너 광고 리소스 해제
  void disposeBanners() {
    _bannerAdHome?.dispose();
    _bannerAdList?.dispose();
    _bannerAdMgmt?.dispose();
    _bannerAdWeekly?.dispose();
    _bannerAdHome = null;
    _bannerAdList = null;
    _bannerAdMgmt = null;
    _bannerAdWeekly = null;
    // 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);
  }
}

