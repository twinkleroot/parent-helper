// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart'; // intl 초기화
import 'firebase_options.dart';
import 'models/user.dart'; // FirebaseAuth User를 간단히 사용
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'services/data_repository.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env 파일 로드. 앱 시작 시 딱 한 번만 호출하면 됩니다.
  await dotenv.load(fileName: ".env");

  MobileAds.instance.initialize();

  // Firebase 초기화 (firebase_options.dart 사용)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize(
    serverClientId: dotenv.env['GOOGLE_LOGIN_WEB_CLIENT_ID'],
  );
  // intl 로캘 데이터 초기화 (DateFormat 사용 전 필수)
  await initializeDateFormatting('ko_KR');

  // 타임존 데이터 초기화
  tz.initializeTimeZones();
  // 한국 시간대로 설정
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  } catch (e) {
    logger.e('Could not set local location: $e');
  }

  // 알림 서비스 초기화
  final notificationService = NotificationService();
  await notificationService.init();

  // 광고 서비스 생성
  runApp(MyApp(
    notificationService: notificationService,
    adService: AdService(),
  ));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;
  final AdService adService;

  const MyApp({
    super.key,
    required this.notificationService,
    required this.adService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AdService>(create: (_) => adService),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<NotificationService>(create: (_) => notificationService),

        // 유저 스트림 제공
        StreamProvider<AppUser?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),

        // DataRepository를 ProxyProvider로 변경
        // AppUser가 변경(로그인/로그아웃)될 때마다 updateAuth를 호출하여 데이터 소스를 즉시 전환
        ProxyProvider<AppUser?, DataRepository>(
          create: (_) => DataRepository(),
          update: (_, user, repo) {
            repo?.updateAuth(user);
            return repo!;
          },
        ),
        // FirestoreService 제공 (AuthService에 의존)
        ProxyProvider<AppUser?, FirestoreService>(
          update: (_, user, _) => FirestoreService(uid: user?.uid),
        ),
      ],
      child: MaterialApp(
        title: '등하원 알리미',
        // 시스템 테마(라이트/다크) 설정
        themeMode: ThemeMode.system,
        // 라이트 테마
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.light,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),

        // 다크 테마
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green.shade900,
            brightness: Brightness.dark,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
