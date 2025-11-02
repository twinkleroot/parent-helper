import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        // Google 로그인 버튼
        child: ElevatedButton.icon(
          onPressed: () async {
            await authService.signInWithGoogle();
          },
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text(
            'Google 계정으로 시작하기',
            style: TextStyle(fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
