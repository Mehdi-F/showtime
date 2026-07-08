import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_route.dart';
import '../widgets/scrollable_center.dart';
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
      appBar: AppBar(title: const Text('Amis')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: "Email de l'ami à ajouter"),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _adding ? null : () => _addFriend(uid),
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Lier'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: linkService.watchFriendUids(uid),
              builder: (context, snapshot) {
                final friendUids = snapshot.data ?? const [];
                if (friendUids.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: const ScrollableCenter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Ajoutez un ami par email pour consulter sa bibliothèque.',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: friendUids.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final friendUid = friendUids[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: linkService.getProfile(friendUid),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final name =
                            profile?['displayName'] as String? ?? profile?['email'] as String? ?? friendUid;
                        final photoUrl = profile?['photoUrl'] as String?;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.surfaceVariant,
                            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                            child:
                                photoUrl == null ? const Icon(Icons.person, color: AppColors.textSecondary) : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).push(appRoute(
                                  builder: (_) => FriendProfileScreen(
                                    friendUid: friendUid,
                                    displayName: name,
                                    photoUrl: photoUrl,
                                  ),
                                )),
                                child: const Text('CONSULTER', style: TextStyle(fontSize: 11)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: 'Retirer',
                                onPressed: () => _removeFriend(uid, friendUid),
                              ),
                            ],
                          ),
                        );
                      },
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
