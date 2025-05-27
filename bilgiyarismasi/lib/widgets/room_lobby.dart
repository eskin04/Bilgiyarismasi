import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/room.dart';
import 'package:flutter/services.dart';

class RoomLobby extends StatelessWidget {
  const RoomLobby({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final room = gameProvider.currentRoom;
        if (room == null) return const SizedBox.shrink();

        final currentUserId = gameProvider.currentUserId;
        if (currentUserId == null) return const SizedBox.shrink();

        final isHost = gameProvider.isHost;
        final hostInfo = room.hostInfo;
        final guestInfo = room.guestInfo;
        final canStartGame = room.canStartGame;
        final isLoading = gameProvider.isLoading;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Room ID
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Oda ID',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.id,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: room.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Oda ID kopyalandı'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Players
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPlayerCard(context, hostInfo, isHost, 'Oda Sahibi'),
                  _buildPlayerCard(context, guestInfo, !isHost, 'Misafir'),
                ],
              ),
              const SizedBox(height: 32),
              // Game Start Button or Waiting Message
              if (isHost)
                if (canStartGame)
                  ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      await gameProvider.startGame();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Oyunu Başlat',
                            style: TextStyle(fontSize: 18),
                          ),
                  )
                else
                  const Text(
                    'Rakip bekleniyor...',
                    style: TextStyle(fontSize: 16),
                  )
              else
                const Text(
                  'Ev sahibi oyunu başlatmayı bekliyor...',
                  style: TextStyle(fontSize: 16),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(
    BuildContext context,
    PlayerInfo? playerInfo,
    bool isCurrentUser,
    String label,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  playerInfo?.avatarUrl != null
                      ? AssetImage(playerInfo!.avatarUrl) as ImageProvider
                      : const AssetImage('assets/avatars/default_avatar.png')
                          as ImageProvider,
              child:
                  playerInfo?.avatarUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
            ),
            const SizedBox(height: 16),
            Text(
              playerInfo?.username ?? 'Bekleniyor...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isCurrentUser ? 'Siz' : label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
