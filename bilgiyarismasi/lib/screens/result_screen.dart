import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/room.dart';
import '../providers/game_provider.dart';
import '../services/auth_service.dart';

class ResultScreen extends StatefulWidget {
  final Room room;

  const ResultScreen({super.key, required this.room});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final AuthService _authService = AuthService();
  StreamSubscription<Room?>? _roomSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final gameProvider = context.read<GameProvider>();
    _roomSubscription = gameProvider.roomStream?.listen((room) {
      if (room == null) {
        // Oda silinmişse ana menüye dön
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleMainMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final gameProvider = context.read<GameProvider>();
      final currentUserId = _authService.currentUser?.uid;

      if (currentUserId != null && gameProvider.currentRoom != null) {
        // Odadan çık (host ise tüm oyuncuları çıkarır ve odayı siler)
        gameProvider.clearRoom();
      }

      // State'i temizle

      // Ana menüye dön
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPlayerResult(PlayerInfo? playerInfo, int score, bool isCurrentUser, bool isWinner, bool isDraw) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: isDraw 
                    ? Colors.orange.withOpacity(0.2)
                    : isWinner 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.blue.withOpacity(0.2),
                child: playerInfo?.avatarUrl != null
                    ? ClipOval(
                        child: Image.asset(
                          playerInfo!.avatarUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, size: 45, color: Colors.grey);
                          },
                        ),
                      )
                    : const Icon(Icons.person, size: 45, color: Colors.grey),
              ),
              if (isCurrentUser)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDraw 
                          ? Colors.orange 
                          : isWinner 
                              ? Colors.green 
                              : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      isDraw 
                          ? Icons.handshake 
                          : isWinner 
                              ? Icons.emoji_events 
                              : Icons.star,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            playerInfo?.username ?? 'Bilinmeyen Oyuncu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDraw 
                  ? Colors.orange[800]
                  : isWinner 
                      ? Colors.green[800] 
                      : Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDraw 
                  ? Colors.orange.withOpacity(0.1)
                  : isWinner 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Puan: $score',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDraw 
                    ? Colors.orange[800]
                    : isWinner 
                        ? Colors.green[800] 
                        : Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRematchButton(BuildContext context, Room currentRoom) {
    final gameProvider = context.read<GameProvider>();
    final currentUserId = _authService.currentUser?.uid;
    final isRequestedByMe = currentRoom.rematchRequestedBy == currentUserId;

    if (currentRoom.rematchRequested) {
      if (isRequestedByMe) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Rakibin yanıtını bekliyorsunuz...',
                style: TextStyle(fontSize: 14, color: Colors.blue),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await gameProvider.leaveRoom();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('İptal Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Rakip yeniden oynamak istiyor!',
                style: TextStyle(fontSize: 14, color: Colors.green),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await gameProvider.acceptRematch();
                    await gameProvider.startGame();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/quiz-battle');
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Kabul Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await gameProvider.leaveRoom();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reddet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return ElevatedButton.icon(
      onPressed: () async {
        await gameProvider.requestRematch();
      },
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Yeniden Oyna'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.read<GameProvider>();
    final currentUserId = _authService.currentUser?.uid;
    final isHost = widget.room.hostId == currentUserId;

    return WillPopScope(
      onWillPop: () async {
        await _handleMainMenu();
        return false;
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<Room?>(
              stream: gameProvider.roomStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentRoom = snapshot.data!;

                // Eğer diğer oyuncu odadan çıktıysa ana menüye yönlendir
                if (isHost && currentRoom.guestId == null || !isHost && currentRoom.hostId == null) {
                  Future.microtask(() {
                    _handleMainMenu();
                  });
                  return const Center(child: CircularProgressIndicator());
                }

                // Eğer oyun başladıysa QuizBattleScreen'e yönlendir
                if (currentRoom.gameStarted && currentRoom.status == RoomStatus.playing) {
                  Future.microtask(() {
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/quiz-battle');
                    }
                  });
                }

                final hostScore = currentRoom.scores[currentRoom.hostId] ?? 0;
                final guestScore = currentRoom.scores[currentRoom.guestId] ?? 0;
                final isDraw = hostScore == guestScore;
                final winner = isDraw ? null : (hostScore > guestScore ? currentRoom.hostId : currentRoom.guestId);
                final isWinner = !isDraw && winner == currentUserId;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Oyun Bitti!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Oyuncu Avatarları ve Skorları
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPlayerResult(
                              currentRoom.players[currentRoom.hostId],
                              hostScore,
                              isHost,
                              !isDraw && currentRoom.hostId == winner,
                              isDraw,
                            ),
                            _buildPlayerResult(
                              currentRoom.players[currentRoom.guestId],
                              guestScore,
                              !isHost,
                              !isDraw && currentRoom.guestId == winner,
                              isDraw,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDraw 
                                ? Colors.orange.withOpacity(0.2)
                                : isWinner 
                                    ? Colors.green.withOpacity(0.2) 
                                    : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDraw 
                                ? 'Berabere! İyi oyundu! 🤝' 
                                : isWinner 
                                    ? 'Tebrikler! Kazandınız! 🎉' 
                                    : 'Maalesef kaybettiniz. Tekrar deneyin! 💪',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Butonları alt alta yerleştir
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _handleMainMenu,
                                icon: const Icon(Icons.home, size: 18),
                                label: const Text('Ana Menü'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _buildRematchButton(context, currentRoom),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
