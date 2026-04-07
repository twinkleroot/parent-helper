import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfig {
  // 버전 관련
  final String latestVersion;
  final String minVersion; // 강제 업데이트 기준 버전

  // 날짜 관련 (Timestamp로 저장된다고 가정)
  final String? forceUpdateStart;
  final String? forceUpdateEnd;
  final String? updateNoticeStart;
  final String? updateNoticeEnd;
  final String? noticeStart;
  final String? noticeEnd;

  // 내용 관련
  final String noticeTitle;
  final String noticeContent;
  final String storeUrl; // 스토어 주소 (Android/iOS 구분 필요 시 분리)

  // 하단 배너 광고 표시 여부
  final bool showBottomBanner;
  final String premiumProductId;

  AppConfig({
    required this.latestVersion,
    required this.minVersion,
    this.forceUpdateStart,
    this.forceUpdateEnd,
    this.updateNoticeStart,
    this.updateNoticeEnd,
    this.noticeStart,
    this.noticeEnd,
    this.noticeTitle = '',
    this.noticeContent = '',
    this.storeUrl = '',
    this.showBottomBanner = true, // 기본값 true
    this.premiumProductId = 'premium_upgrade', // 기본값
  });

  factory AppConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return AppConfig(
      latestVersion: data['latest_version'] ?? '1.0.0',
      minVersion: data['min_version'] ?? '1.0.0',
      forceUpdateStart: data['force_update_start_date'] as String?,
      forceUpdateEnd: data['force_update_end_date'] as String?,
      updateNoticeStart: data['update_notice_start_date'] as String?,
      updateNoticeEnd: data['update_notice_end_date'] as String?,
      noticeStart: data['notice_start_date'] as String?,
      noticeEnd: data['notice_end_date'] as String?,
      noticeTitle: data['notice_title'] ?? '공지사항',
      noticeContent: data['notice_content'] ?? '',
      storeUrl: data['store_url'] ?? 'https://play.google.com/store/apps/details?id=kr.heeblings.parent_helper',
      showBottomBanner: data['show_bottom_banner'] ?? false,
      // [추가] DB에 값이 없으면 기존 ID를 기본으로 사용
      premiumProductId: data['premiumProductId'] ?? 'premium_upgrade',
    );
  }
}