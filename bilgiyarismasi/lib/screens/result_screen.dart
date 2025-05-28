import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';

class ResultScreen extends StatelessWidget {
  final Room room;
  final AuthService _authService = AuthService();

  ResultScreen({super.key, required this.room});

  Widget _buildPlayerResult(PlayerInfo? playerInfo, int score, bool isCurrentUser) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage(playerInfo?.avatarUrl ?? 'assets/default_avatar.png'),
          child: playerInfo?.avatarUrl == null
              ? const Icon(Icons.person, size: 50)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          playerInfo?.username ?? 'Bilinmeyen Oyuncu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isCurrentUser ? Colors.blue : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Puan: $score',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isCurrentUser ? Colors.blue : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildRematchButton(BuildContext context, GameProvider gameProvider, Room currentRoom) {
    final currentUserId = _authService.currentUser?.uid;
    final isRequestedByMe = currentRoom.rematchRequestedBy == currentUserId;

    if (currentRoom.rematchRequested) {
      if (isRequestedByMe) {
        return Column(
          children: [
            const Text(
              'Rakibin yanıtını bekliyorsunuz...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await gameProvider.leaveRoom();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('İptal Et'),
            ),
          ],
        );
      } else {
        return Column(
          children: [
            const Text(
              'Rakip yeniden oynamak istiyor!',
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await gameProvider.acceptRematch();
                    await gameProvider.startGame();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/quiz-battle');
                    }
                  },
                  child: const Text('Kabul Et'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await gameProvider.leaveRoom();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Reddet'),
                ),
              ],
            ),
          ],
        );
      }
    }

    return ElevatedButton(
      onPressed: () async {
        await gameProvider.requestRematch();
      },
      child: const Text('Yeniden Oyna'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final currentUserId = _authService.currentUser?.uid;
    final isHost = room.hostId == currentUserId;

    return WillPopScope(
      onWillPop: () async {
        await gameProvider.leaveRoom();
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Oyun Sonucu'),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<Room?>(
          stream: gameProvider.roomStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final currentRoom = snapshot.data!;

            // Eğer oyun başladıysa QuizBattleScreen'e yönlendir
            if (currentRoom.gameStarted && currentRoom.status == RoomStatus.playing) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed('/quiz-battle');
              });
            }

            final hostScore = currentRoom.scores[currentRoom.hostId] ?? 0;
            final guestScore = currentRoom.scores[currentRoom.guestId] ?? 0;
            final winner = hostScore > guestScore ? currentRoom.hostId : currentRoom.guestId;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Oyun Bitti!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    // Oyuncu Avatarları ve Skorları
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPlayerResult(
                          currentRoom.players[currentRoom.hostId],
                          hostScore,
                          isHost,
                        ),
                        _buildPlayerResult(
                          currentRoom.players[currentRoom.guestId],
                          guestScore,
                          !isHost,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Kazanan: ${winner == currentUserId ? 'Siz' : 'Rakip'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            await gameProvider.leaveRoom();
                            if (context.mounted) {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          child: const Text('Ana Menü'),
                        ),
                        _buildRematchButton(context, gameProvider, currentRoom),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 