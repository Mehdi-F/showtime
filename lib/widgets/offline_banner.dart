import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Slim bar shown at the top of the app while offline, so a watched-toggle
/// or a stat that doesn't update yet reads as "queued until reconnected"
/// rather than "broken".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.cloud_off, size: 14, color: Colors.black),
            SizedBox(width: 6),
            Text(
              'Hors ligne — les changements seront synchronisés au retour de la connexion',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
