import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

// 인증 상태에 따라 홈 또는 로그인 화면을 보여주는 게이트
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);

    if (user == null) {
      return const LoginScreen();
    } else {
      return const HomeScreen();
    }
  }
}
