import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show InAppPurchase, ProductDetails, ProductDetailsResponse, PurchaseDetails, PurchaseParam, PurchaseStatus;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';
import 'local_database_service.dart';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _isAvailable = false;
  bool _isPremium = false; // 프리미엄 여부

  // 구글 플레이 콘솔에 등록한 제품 ID
  static const String _productID = 'premium_upgrade';

  List<ProductDetails> _products = [];
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool get isPremium => _isPremium;

  PurchaseService() {
    _init();
  }

  Future<void> _init() async {
    // 1. 저장된 프리미엄 상태 로드 (캐시)
    final prefs = await SharedPreferences.getInstance();

    // [추가] 0. 로컬 DB를 한번 호출하여 onUpgrade 로직(기존 유저 체크)이 실행되게 함
    await LocalDatabaseService().database;

    // [추가] 1. 기존 유저 혜택 확인
    // LocalDatabaseService.onUpgrade에서 설정한 플래그 확인
    if (prefs.getBool('is_legacy_user_grant_pending') == true) {
      logger.i('기존 사용자(Legacy User) 감지됨. 프리미엄 혜택 자동 부여.');
      await prefs.setBool('is_premium_user', true); // 영구 프리미엄 부여
      await prefs.remove('is_legacy_user_grant_pending'); // 플래그 삭제 (중복 실행 방지)
    }

    _isPremium = prefs.getBool('is_premium_user') ?? false;
    notifyListeners();

    // 3. 스토어 연결 확인
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      // 구매 리스너 등록
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _onPurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) => logger.e('IAP Error: $error'),
      );

      // 4. 상품 정보 로드
      await _loadProducts();

      // 5. 누락된 구매 내역 복원 (앱 재설치 등)
      await _iap.restorePurchases();
    }
  }

  Future<void> _loadProducts() async {
    const Set<String> kIds = {_productID};
    final ProductDetailsResponse response = await _iap.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      logger.w('상품을 찾을 수 없음: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  // 구매 시도
  Future<void> buyPremium() async {
    if (!_isAvailable || _products.isEmpty) {
      logger.e('스토어를 사용할 수 없거나 상품 정보가 없습니다.');
      return;
    }
    final ProductDetails productDetails = _products.firstWhere((p) => p.id == _productID);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    // 소모품이 아니므로 nonConsumable로 구매 요청
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // 구매 업데이트 처리
  void _onPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 결제 대기 중 UI 처리 등
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          logger.e('구매 실패: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {

          // 구매 성공 또는 복원 성공
          _enablePremium();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _enablePremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_user', true);
    notifyListeners();
    logger.i('프리미엄 기능 활성화됨');
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}