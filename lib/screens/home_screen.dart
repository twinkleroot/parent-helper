import 'dart:async'; // Timer를 위해 추가
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parent_helper/services/data_repository.dart';
import 'package:provider/provider.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../screens/tabs/today_schedule_tab.dart';
import '../screens/tabs/all_schedules_tab.dart';
import '../screens/tabs/weekly_schedule_tab.dart';
import '../screens/tabs/management_tab.dart';
import '../models/user.dart';
import '../services/popup_service.dart';
import '../models/app_config.dart';

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
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<HomeTab> _widgetOptions;
  // 앱 설정 상태
  AppConfig? _appConfig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPopups();
    });
  }

  Future<void> _checkPopups() async {
    final dataRepository = Provider.of<DataRepository>(context, listen: false);
    final popupService = PopupService();

    final config = await dataRepository.getAppConfig();

    if (mounted) {
      setState(() {
        _appConfig = config; // 설정 저장 (광고 표시에 사용)
      });
      await popupService.checkNoticesAndGuide(context, config);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // [중요] AppUser 상태 변경을 감지하여 위젯 리스트를 재생성
    // 이렇게 해야 로그인/로그아웃 시 탭들이 다시 빌드되면서 DataRepository의 변경된 상태를 반영함
    Provider.of<AppUser?>(context); // 리빌드 트리거
    final adService = Provider.of<AdService>(context, listen: false);

    _widgetOptions = [
      HomeTab(
        title: '오늘 일정',
        widget: const TodayScheduleTab(),
        bannerAd: adService.bannerAdHome,
      ),
      HomeTab(
        title: '전체 일정',
        widget: const AllSchedulesTab(),
        bannerAd: adService.bannerAdList,
      ),
      HomeTab(
        title: '주간 요약',
        widget: const WeeklyScheduleTab(),
        bannerAd: adService.bannerAdWeekly,
      ),
      HomeTab(
        title: '설정',
        widget: const ManagementTab(),
        bannerAd: adService.bannerAdMgmt,
      ),
    ];
  }

  void onItemTapped(int index) {
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

  Widget _buildBannerAdWidget(BannerAd? bannerAd) {
    // [추가] 1. Config가 아직 로드되지 않았거나,
    // 2. DB 플래그(showBottomBanner)가 false이면 광고를 보여주지 않음
    if (_appConfig == null || !_appConfig!.showBottomBanner) {
      return const SizedBox.shrink(); // 아예 공간 차지 안 함
    }

    if (bannerAd == null) {
      return const SizedBox(height: 50.0);
    }

    return Container(
      alignment: Alignment.center,
      width: AdSize.banner.width.toDouble(),
      height: AdSize.banner.height.toDouble(),
      child: AdWidget(
        ad: bannerAd,
        key: ValueKey('${bannerAd.adUnitId}_$_currentIndex'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<DataRepository>(context, listen: false);
    final user = Provider.of<AppUser?>(context);  // 유저 상태 감지

    // _widgetOptions이 초기화되기 전이나 범위 밖일 경우 대비
    if (_currentIndex >= _widgetOptions.length) {
      _currentIndex = 0;
    }
    final currentTab = _widgetOptions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTab.title),
        actions: [
          // 로그인 상태일 때만 로그아웃 버튼 표시
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final bool confirm = await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('로그아웃')),
                    ],
                  ),
                ) ?? false;

                if (confirm) {
                  await authService.signOut();
                  // 로그아웃 후 DataRepository가 자동으로 로컬 모드로 전환됨
                }
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
              children: _widgetOptions.map((e) => e.widget).toList(),
            ),
          ),
          _buildBannerAdWidget(currentTab.bannerAd),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Total',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.date_range),
            label: 'Weekly',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: onItemTapped,
      ),
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
      width: AdSize.banner.width.toDouble(),
      height: bannerAd.size.height.toDouble(),
      // color: Colors.grey[100], // 광고 로딩 중 배경색
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