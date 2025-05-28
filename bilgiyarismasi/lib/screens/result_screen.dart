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

  Widget _buildPlayerResult(
    PlayerInfo? playerInfo,
    int score,
    bool isCurrentUser,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor:
              isCurrentUser ? Colors.blue.withOpacity(0.2) : Colors.grey[200],
          child:
              playerInfo?.avatarUrl != null
                  ? ClipOval(
                    child: Image.asset(
                      playerInfo!.avatarUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey,
                        );
                      },
                    ),
                  )
                  : const Icon(Icons.person, size: 50, color: Colors.grey),
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

  Widget _buildRematchButton(BuildContext context, Room currentRoom) {
    final gameProvider = context.read<GameProvider>();
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
                gameProvider.clearRoom();
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
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/quiz-battle');
                    }
                  },
                  child: const Text('Kabul Et'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    gameProvider.clearRoom();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
    final isHost = widget.room.hostId == currentUserId;

    return WillPopScope(
      onWillPop: () async {
        await _handleMainMenu();
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

            // Eğer diğer oyuncu odadan çıktıysa ana menüye yönlendir
            if (isHost && currentRoom.guestId == null ||
                !isHost && currentRoom.hostId == null) {
              Future.microtask(() {
                _handleMainMenu();
              });
              return const Center(child: CircularProgressIndicator());
            }

            // Eğer oyun başladıysa QuizBattleScreen'e yönlendir
            if (currentRoom.gameStarted &&
                currentRoom.status == RoomStatus.playing) {
              Future.microtask(() {
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/quiz-battle');
                }
              });
            }

            final hostScore = currentRoom.scores[currentRoom.hostId] ?? 0;
            final guestScore = currentRoom.scores[currentRoom.guestId] ?? 0;
            final winner =
                hostScore > guestScore
                    ? currentRoom.hostId
                    : currentRoom.guestId;

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
                          onPressed: _handleMainMenu,
                          child: const Text('Ana Menü'),
                        ),
                        _buildRematchButton(context, currentRoom),
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
