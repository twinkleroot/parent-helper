import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

// 광고 로드 및 표시를 관리하는 서비스
class AdService {
  AppOpenAd? _appOpenAd;
  bool _isAppOpenAdShowing = false;
  bool _isAppOpenAdLoaded = false;

  BannerAd? _bannerAdHome;
  BannerAd? _bannerAdList;
  BannerAd? _bannerAdMgmt;

  bool get isBannerAdHomeLoaded => _bannerAdHome != null;
  bool get isBannerAdListLoaded => _bannerAdList != null;
  bool get isBannerAdMgmtLoaded => _bannerAdMgmt != null;

  BannerAd get bannerAdHome => _bannerAdHome!;
  BannerAd get bannerAdList => _bannerAdList!;
  BannerAd get bannerAdMgmt => _bannerAdMgmt!;

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
    // 병렬로 로드
    await Future.wait([
      _loadAppOpenAd(),
      _loadBannerAdHome(),
      _loadBannerAdList(),
      _loadBannerAdMgmt(),
    ]);
  }

  // --- 앱 오프닝 광고 (App Open) ---
  Future<void> _loadAppOpenAd() async {
    if (kIsWeb) return;
    await AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          logger.i('AppOpenAd loaded.');
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoaded = false;
          logger.e('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable({required VoidCallback onAdDismissed}) {
    logger.i('_isAppOpenAdLoaded: ${!_isAppOpenAdLoaded}');
    logger.i('_appOpenAd is null: ${_appOpenAd == null ? 'true' : 'false'}');
    if (_isAppOpenAdShowing || !_isAppOpenAdLoaded || _appOpenAd == null) {
      logger.w('AppOpenAd not available or already showing.');
      onAdDismissed();
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
        // 다음 광고를 미리 로드
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isAppOpenAdShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        logger.e('AppOpenAd failed to show: $error');
        onAdDismissed();
      },
    );

    _appOpenAd!.show();
  }

  // --- 배너 광고 (Tabs) ---
  Future<void> _loadBannerAdHome() async {
    if (kIsWeb) return;
    _bannerAdHome = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => logger.i('Banner Home loaded.'),
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner Home failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadBannerAdList() async {
    if (kIsWeb) return;
    _bannerAdList = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => logger.i('Banner List loaded.'),
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner List failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _loadBannerAdMgmt() async {
    if (kIsWeb) return;
    _bannerAdMgmt = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => logger.i('Banner Mgmt loaded.'),
        onAdFailedToLoad: (ad, err) {
          logger.e('Banner Mgmt failed: $err');
          ad.dispose();
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
  }
}

