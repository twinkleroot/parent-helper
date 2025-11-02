import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../screens/tabs/today_schedule_tab.dart';
import '../screens/tabs/all_schedules_tab.dart';
import '../screens/tabs/management_tab.dart'; // 기관/자녀 관리 탭

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
    );
  }

  // 배너 광고를 담을 컨테이너 위젯
  Widget _buildBannerContainer(BannerAd bannerAd) {
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: bannerAd.size.height.toDouble(),
      color: Colors.grey[100], // 광고 로딩 중 배경색
      child: AdWidget(ad: bannerAd),
    );
  }
}
