import 'dart:async'; // Timer를 위해 추가
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../screens/tabs/today_schedule_tab.dart';
import '../screens/tabs/all_schedules_tab.dart';
import '../screens/tabs/management_tab.dart';
import '../screens/add_edit_schedule_screen.dart';

// 홈 화면의 각 탭을 정의하는 클래스
class HomeTab {
  final String title;
  final Widget widget;
  final BannerAd? bannerAd;

  HomeTab({required this.title, required this.widget, this.bannerAd});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<Widget> _tabs = <Widget>[
    TodayScheduleTab(),
    AllSchedulesTab(),
    ManagementTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    // 홈 화면이 닫힐 때 배너 광고 리소스 해제
    Provider.of<AdService>(context, listen: false).disposeBanners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final adService = Provider.of<AdService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('등하원 알리미'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: Column( // body를 Column으로 감싸기
        children: [
          // 1. 기존 화면 내용
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),

          // 2. 현재 탭에 맞는 배너 광고 표시 영역
          if (_currentIndex == 0 && adService.isBannerAdHomeLoaded)
            _buildBannerContainer(adService.bannerAdHome),

          if (_currentIndex == 1 && adService.isBannerAdListLoaded)
            _buildBannerContainer(adService.bannerAdList),

          if (_currentIndex == 2 && adService.isBannerAdMgmtLoaded)
            _buildBannerContainer(adService.bannerAdMgmt),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: '오늘 일정',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: '전체 일정',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
      // FAB를 Scaffold에 직접 추가
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () async {
                // 1. Firestore에서 자녀/기관 목록을 1회성으로 가져옵니다.
                final children = await firestoreService.getChildren().first;
                final institutions = await firestoreService.getInstitutions().first;

                if (!mounted) return; // 비동기 작업 후 context 유효성 검사

                // 2. 자녀 또는 기관이 하나라도 비어있으면
                if (children.isEmpty || institutions.isEmpty) {
                  // 3. 안내 메시지를 띄우고
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return _AutoDismissDialog(
                        title: '안내',
                        content: '일정을 등록하려면 먼저 자녀와 기관을 1개 이상 등록해야 합니다.',
                        // 다이얼로그가 닫힐 때 (버튼 클릭 or 3초)
                        onDismiss: () {
                          // 4. '설정' 탭(index 2)으로 이동시킵니다.
                          _onItemTapped(2);
                        },
                      );
                    },
                  );
                  // 4. '설정' 탭(index 2)으로 이동시킵니다.
                  _onItemTapped(2);
                } else {
                  // 5. 데이터가 모두 있으면 기존처럼 일정 등록 화면으로 이동합니다.
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AddEditScheduleScreen(),
                    ),
                  );
                }
              },
              child: const Icon(Icons.add),
            )
          : null, // 설정 탭(index 2)에서는 FAB 숨김
    );
  }

  // 배너 광고를 담을 컨테이너 위젯
  Widget _buildBannerContainer(BannerAd? bannerAd) {
    // 광고가 null이거나 로드 실패 시, 빈 공간을 반환
    if (bannerAd == null) {
      return const SizedBox(height: 50.0); // 표준 배너 높이
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: bannerAd.size.height.toDouble(),
      color: Colors.grey[100], // 광고 로딩 중 배경색
      child: AdWidget(
          ad: bannerAd,
        key: ValueKey('${bannerAd.adUnitId}_$_currentIndex'),
      ),
    );
  }
}

// 3초 후 자동 해제되는 다이얼로그 위젯
class _AutoDismissDialog extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onDismiss; // 다이얼로그가 닫힐 때 호출될 콜백

  const _AutoDismissDialog({
    required this.title,
    required this.content,
    required this.onDismiss,
  });

  @override
  State<_AutoDismissDialog> createState() => _AutoDismissDialogState();
}

class _AutoDismissDialogState extends State<_AutoDismissDialog> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // 3초 타이머 시작
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop(); // 3초 후 다이얼로그 닫기
        widget.onDismiss(); // '설정' 탭으로 이동
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // 사용자가 '확인'을 누르면 타이머 취소
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.content),
      actions: [
        TextButton(
          onPressed: () {
            _timer.cancel(); // 3초 타이머 취소
            Navigator.of(context).pop(); // '확인' 버튼으로 다이얼로그 닫기
            widget.onDismiss(); // '설정' 탭으로 이동
          },
          child: const Text('확인'),
        ),
      ],
    );
  }
}