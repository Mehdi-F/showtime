import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        children: [
          _buildSection('Apparence', [
            _buildThemeOption(context),
          ]),
          _buildSection('Général', [
            _buildLanguageOption(context),
            _buildNotificationsOption(context),
          ]),
          _buildSection('Données', [
            _buildCacheTile(context),
          ]),
          _buildSection('Compte', [
            _buildLogoutTile(context),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thème', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildThemeChip(context, AppThemeMode.light, 'Clair', settings.themeMode == AppThemeMode.light),
                  const SizedBox(width: 8),
                  _buildThemeChip(context, AppThemeMode.dark, 'Sombre', settings.themeMode == AppThemeMode.dark),
                  const SizedBox(width: 8),
                  _buildThemeChip(context, AppThemeMode.auto, 'Auto', settings.themeMode == AppThemeMode.auto),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(BuildContext context, AppThemeMode mode, String label, bool selected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<SettingsProvider>().setThemeMode(mode),
      selectedColor: AppColors.accent,
      labelStyle: TextStyle(
        color: selected ? Colors.black : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide.none,
    );
  }

  Widget _buildLanguageOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Langue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.language,
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsProvider>().setLanguage(value);
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => SwitchListTile(
          title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Notifications pour les nouveaux épisodes'),
          value: settings.enableNotifications,
          onChanged: (value) => context.read<SettingsProvider>().setEnableNotifications(value),
          activeColor: AppColors.accent,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildCacheTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: const Text('Vider le cache', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Supprime les données TMDB en cache'),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        contentPadding: EdgeInsets.zero,
        onTap: () => _showClearCacheDialog(context),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
        contentPadding: EdgeInsets.zero,
        onTap: () => _showLogoutDialog(context),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Vider le cache ?'),
        content: const Text('Cela supprimera les données TMDB en cache. Vous pourrez les récharger.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<SettingsProvider>().clearCache();
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Cache vidé'), duration: Duration(seconds: 2)));
            },
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Déconnexion ?'),
        content: const Text('Vous allez être déconnecté de votre compte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<AuthProvider>().signOut();
              Navigator.pop(context);
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
