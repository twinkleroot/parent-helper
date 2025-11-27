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

  bool get isBannerAdHomeLoaded => _bannerAdHome != null;
  bool get isBannerAdListLoaded => _bannerAdList != null;
  bool get isBannerAdMgmtLoaded => _bannerAdMgmt != null;

  BannerAd? get bannerAdHome => _bannerAdHome;
  BannerAd? get bannerAdList => _bannerAdList;
  BannerAd? get bannerAdMgmt => _bannerAdMgmt;

  // 광고 로드 완료를 보장하기 위한 Completer 추가
  Completer<void> _appOpenAdCompleter = Completer<void>();
  Completer<void> _bannerHomeCompleter = Completer<void>();
  Completer<void> _bannerListCompleter = Completer<void>();
  Completer<void> _bannerMgmtCompleter = Completer<void>();

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

  // Warm Start 시 50% 확률로 광고 표시 시도
  void _tryShowAdOnWarmStart() {
    // 웹이거나 이미 광고가 떠있으면 스킵
    if (kIsWeb || _isAppOpenAdShowing) return;

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
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_APP_OPEN']!;
  }

  String get _bannerUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_BANNER']!;
  }

  // 모든 광고를 미리 로드합니다. (스플래시 화면에서 호출)
  Future<void> preloadAds() async {
    // Completer 초기화
    _appOpenAdCompleter = Completer<void>();
    _bannerHomeCompleter = Completer<void>();
    _bannerListCompleter = Completer<void>();
    _bannerMgmtCompleter = Completer<void>();

    // await 없이 로드 "시작"
    _loadAppOpenAd();
    _loadBannerAdHome();
    _loadBannerAdList();
    _loadBannerAdMgmt();

    // 병렬로 로드
    await Future.wait([
      _appOpenAdCompleter.future,
      _bannerHomeCompleter.future,
      _bannerListCompleter.future,
      _bannerMgmtCompleter.future,
    ]);
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
      logger.w('앱이 백그라운드 상태이므로 전면 광고를 표시하지 않습니다.');
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

  // 홈 화면 종료 시 배너 광고 리소스 해제
  void disposeBanners() {
    _bannerAdHome?.dispose();
    _bannerAdList?.dispose();
    _bannerAdMgmt?.dispose();
    _bannerAdHome = null;
    _bannerAdList = null;
    _bannerAdMgmt = null;
    // 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);
  }
}

