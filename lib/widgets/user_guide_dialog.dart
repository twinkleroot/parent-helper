import 'package:flutter/material.dart';

class UserGuideDialog extends StatefulWidget {
  const UserGuideDialog({super.key});

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 가이드 데이터 (이미지 경로, 제목, 설명)
  final List<Map<String, String>> _guidePages = [
    {
      'title': '등하원 알림 통합 관리',
      'description': '여러 학원, 유치원, 학교의 셔틀 버스 시간을 한 곳에서 관리하세요.',
      'image': 'assets/images/guide_1.jpeg',
    },
    {
      'title': '미리 알림 설정',
      'description': '5분 전, 10분 전 등 원하는 시간에 알림을 받아 여유롭게 준비하세요.',
      'image': 'assets/images/guide_2.jpeg',
    },
    {
      'title': '편리한 필터링',
      'description': '자녀별, 기관별, 등/하원별로 일정을 쉽게 찾아볼 수 있습니다.',
      'image': 'assets/images/guide_3.jpeg',
    },
    {
      'title': '메모 및 연락처',
      'description': '차량 번호나 기사님 연락처를 저장하고 바로 전화할 수 있습니다.',
      'image': 'assets/images/guide_4.jpeg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        height: 500, // 다이얼로그 높이 고정
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 상단 타이틀 & 닫기 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '앱 사용 가이드',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 메인 콘텐츠 (스와이프 영역)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _guidePages.length,
                itemBuilder: (context, index) {
                  final page = _guidePages[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 이미지 영역 (여기서는 플레이스홀더)
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias, // 둥근 모서리 적용
                        alignment: Alignment.center,
                        child: Image.asset(
                          page['image']!, // assets 이미지 로드
                          fit: BoxFit.contain, // 비율 유지하며 전체 표시 (필요시 cover로 변경)
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        page['title']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        page['description']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // 하단 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_guidePages.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.orange
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 10),

            // '다음' 또는 '시작하기' 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage < _guidePages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    Navigator.of(context).pop(); // 닫기
                  }
                },
                child: Text(_currentPage < _guidePages.length - 1 ? '다음' : '시작하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}