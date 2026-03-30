import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      await _enablePremium(); // _enablePremium 내부에서 서버 동기화 처리
      await prefs.remove('is_legacy_user_grant_pending'); // 플래그 삭제 (중복 실행 방지)
    }

    _isPremium = prefs.getBool('is_premium_user') ?? false;

    // 3. 서버(Firestore)와 동기화 (재설치 복구 및 백업)
    await _syncWithServer();

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

  // 서버와 프리미엄 상태 동기화
  Future<void> _syncWithServer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // 비로그인 상태면 동기화 불가

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await userDocRef.get();

      // Case A: 서버에는 프리미엄이라고 되어있는데, 로컬은 아닐 때 (재설치 복구)
      if (doc.exists && doc.data()?['isPremium'] == true) {
        if (!_isPremium) {
          logger.i('서버에서 프리미엄 권한 복구됨.');
          await _enablePremium(skipServerSync: true); // 무한루프 방지
        }
      }
      // Case B: 로컬은 프리미엄인데, 서버에는 기록이 없을 때 (최초 백업)
      else if (_isPremium) {
        logger.i('프리미엄 권한 서버에 백업.');
        await userDocRef.set({'isPremium': true}, SetOptions(merge: true));
      }
    } catch (e) {
      logger.e('프리미엄 상태 동기화 실패: $e');
    }
  }

  // [추가] 로그인 직후 호출할 수 있는 public 메서드
  Future<void> refreshPremiumStatus() async {
    await _syncWithServer();
    notifyListeners();
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

  // 프리미엄 활성화 및 저장
  Future<void> _enablePremium({bool skipServerSync = false}) async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_user', true);

    // 서버에도 기록 (로그인 상태라면)
    if (!skipServerSync) {
      await _syncWithServer();
    }

    notifyListeners();
    logger.i('프리미엄 기능 활성화됨');
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}