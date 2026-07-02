import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Showtime', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
