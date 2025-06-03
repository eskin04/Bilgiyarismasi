import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Geri butonu
          Positioned(
            top: 32,
            left: 16,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Geri',
              ),
            ),
          ),
          // Ana içerik
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService().getTopUsers(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Bir hata oluştu: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!;
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'Henüz lider bulunmuyor',
                    style: TextStyle(color: Colors.black54),
                  ),
                );
              }
              final first = users.first;
              final rest = users.length > 1 ? users.sublist(1) : [];
              return Column(
                children: [
                  // Başlık
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 48, bottom: 24, left: 8, right: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black87),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Geri',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.leaderboard, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Lider Tablosu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Birinci Kullanıcı
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: Colors.amber.withOpacity(0.13),
                            backgroundImage:
                                first['avatarUrl'] != null &&
                                        first['avatarUrl'].toString().isNotEmpty
                                    ? AssetImage(first['avatarUrl'])
                                    : null,
                            child:
                                (first['avatarUrl'] == null ||
                                        first['avatarUrl'].toString().isEmpty)
                                    ? Icon(
                                        Icons.person,
                                        color: Colors.grey[500],
                                        size: 38,
                                      )
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                first['username'] ?? 'Kullanıcı',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            first['email'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 22),
                              const SizedBox(width: 4),
                              Text(
                                (first['score'] ?? 0).toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Diğer kullanıcılar
                  if (rest.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        itemCount: rest.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = rest[index];
                          final rank = index + 2;
                          final isCurrent = user['uid'] == currentUserId;
                          return _SimpleUserCard(
                            user: user,
                            rank: rank,
                            isCurrent: isCurrent,
                          );
                        },
                      ),
                    ),
                  if (rest.isEmpty) const Spacer(),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SimpleUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int rank;
  final bool isCurrent;
  const _SimpleUserCard({
    required this.user,
    required this.rank,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color:
            isCurrent
                ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          width: isCurrent ? 2 : 1,
          color:
              isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[100],
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrent ? Colors.white : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[200],
            backgroundImage:
                user['avatarUrl'] != null &&
                        user['avatarUrl'].toString().isNotEmpty
                    ? AssetImage(user['avatarUrl'])
                    : null,
            child:
                (user['avatarUrl'] == null ||
                        user['avatarUrl'].toString().isEmpty)
                    ? Icon(Icons.person, color: Colors.grey[500], size: 16)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'] ?? 'Kullanıcı',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color:
                        isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black87,
                  ),
                ),
                Text(
                  user['email'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                (user['score'] ?? 0).toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color:
                      isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
