import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';

/// 개발자 후원 및 프리미엄 업그레이드를 안내하는 공통 다이얼로그 호출 함수
void showPremiumDialog(BuildContext context, {String message = ''}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.local_cafe, color: Colors.brown),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '개발자 커피 후원 & 프리미엄',
              style: TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          '안녕하세요!\n이 앱을 개발하고 운영 중인 1인 개발자입니다.\n\n'
              '${message.isNotEmpty ? '$message\n\n' : ''}'
              '앱이 조금이나마 도움이 되셨다면, 커피 한 잔 가격으로 개발자를 후원해 주세요!\n'
              '🎁  감사의 마음을 담아 아래 혜택을 열어드립니다.\n\n'
              '✨ 프리미엄 혜택:\n'
              '• 자녀, 기관, 일정 무제한 등록\n\t(다둥이 부모님 환영!)\n'
              '• 클라우드 데이터 안심 백업\n\t(기기변경해도 안전)\n'
              '• 카카오톡으로 오늘 일정 텍스트 공유\n\t(매일 알려줘도 헷갈려하는 남편에게!)\n'
              '• 앱 내 광고 완벽 제거\n'
              '• 앞으로 더 추가될 기능까지!\n\n'
              '보내주신 소중한 후원금은 서버 유지와 더 좋은 기능을 개발하는 데 사용하겠습니다.\n감사합니다!',
          style: const TextStyle(height: 1.5, fontSize: 14),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('나중에', style: TextStyle(color: Colors.grey)),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown.shade600,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(ctx);
            // 결제(후원) 프로세스 시작
            Provider.of<PurchaseService>(context, listen: false).buyPremium();
          },
          child: const Text('개발자 후원하고 혜택받기'),
        ),
      ],
    ),
  );
}