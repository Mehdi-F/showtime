import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/link_service.dart';
import '../theme/app_theme.dart';
import '../l10n/localization_context.dart';
import '../widgets/app_page_route.dart';
import '../widgets/scrollable_center.dart';
import '../widgets/skeletons.dart';
import 'profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addFriend(String uid) async {
    final email = _controller.text.trim();
    if (email.isEmpty) return;
    final currentEmail = context.read<AuthProvider>().user?.email;
    if (currentEmail != null && email.toLowerCase() == currentEmail.toLowerCase()) return;

    setState(() => _adding = true);
    final linkService = context.read<LinkService>();
    try {
      final friendUid = await linkService.findUidByEmail(email);
      if (!mounted) return;
      if (friendUid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun utilisateur trouvé avec cet email — il doit d'abord ouvrir l'app.")),
        );
        return;
      }
      await linkService.addFriend(uid: uid, friendUid: friendUid);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Échec de l'ajout. Réessayez.")));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeFriend(String uid, String friendUid) {
    return context.read<LinkService>().removeFriend(uid: uid, friendUid: friendUid);
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().user!.uid;
    final linkService = context.read<LinkService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('friends.title')),
        elevation: 0,
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajoutez des amis',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: context.tr('friends.addFriend'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _adding ? null : () => _addFriend(uid),
                      child: _adding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.tr('friends.addButton')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: linkService.watchFriendUids(uid),
              builder: (context, snapshot) {
                final friendUids = snapshot.data ?? const [];
                if (friendUids.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ScrollableCenter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(context.tr('friends.placeholder'),
                                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: friendUids.length,
                    itemBuilder: (context, index) {
                      final friendUid = friendUids[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: linkService.getProfile(friendUid),
                          builder: (context, profileSnapshot) {
                            if (profileSnapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Row(
                                  children: [
                                    SkeletonBox(
                                      width: 56,
                                      height: 56,
                                      borderRadius: BorderRadius.all(Radius.circular(28)),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(child: SkeletonBox(width: 140, height: 14)),
                                  ],
                                ),
                              );
                            }
                            final profile = profileSnapshot.data;
                            final name = profile?['displayName'] as String? ?? profile?['email'] as String? ?? friendUid;
                            final photoUrl = profile?['photoUrl'] as String?;
                            final seriesCount = profile?['seriesWatchedCount'] as int? ?? 0;
                            final filmsCount = profile?['filmsWatchedCount'] as int? ?? 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceVariant, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: AppColors.surfaceVariant,
                                          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                                          child: photoUrl == null ? const Icon(Icons.person, color: AppColors.textSecondary, size: 28) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text('$seriesCount séries',
                                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                                  const SizedBox(width: 12),
                                                  Text('$filmsCount films',
                                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          tooltip: context.tr('friends.removeButton'),
                                          onPressed: () => _removeFriend(uid, friendUid),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonal(
                                        onPressed: () => Navigator.of(context).push(appRoute(
                                          builder: (_) => FriendProfileScreen(
                                            friendUid: friendUid,
                                            displayName: name,
                                            photoUrl: photoUrl,
                                          ),
                                        )),
                                        child: Text(context.tr('friends.viewProfile'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
