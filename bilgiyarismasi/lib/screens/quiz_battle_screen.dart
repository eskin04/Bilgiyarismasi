import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/room.dart';
import '../services/auth_service.dart';
import 'result_screen.dart';
import '../widgets/room_lobby.dart';

class QuizBattleScreen extends StatefulWidget {
  const QuizBattleScreen({super.key});

  @override
  State<QuizBattleScreen> createState() => _QuizBattleScreenState();
}

class _QuizBattleScreenState extends State<QuizBattleScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final AuthService _authService = AuthService();
  Timer? _timer;
  bool _showAnswers = false;

  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.currentRoom != null) {
      gameProvider.startListening(gameProvider.currentRoom!.id);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roomIdController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final gameProvider = context.read<GameProvider>();
      final timeRemaining = gameProvider.timeRemaining - 1;

      if (timeRemaining <= 0) {
        timer.cancel();
        _handleTimeUp();
      } else {
        gameProvider.updateTimer(timeRemaining);
      }
    });
  }

  Future<void> _handleTimeUp() async {
    final gameProvider = context.read<GameProvider>();
    setState(() => _showAnswers = true);

    // Wait for 3 seconds to show answers
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() => _showAnswers = false);
      await gameProvider.moveToNextQuestion();
      _startTimer();
    }
  }

  Future<void> _handleAnswer(String option) async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.submitAnswer(option);
    setState(() => _showAnswers = true);

    // Wait for 3 seconds to show answers
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() => _showAnswers = false);
      await gameProvider.moveToNextQuestion();
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        if (gameProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (gameProvider.error != null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Hata'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    gameProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      gameProvider.clearRoom();
                    },
                    child: const Text('Geri Dön'),
                  ),
                ],
              ),
            ),
          );
        }

        if (gameProvider.currentRoom == null) {
          return _buildRoomSelection(context, gameProvider);
        }

        return _buildGameScreen(context, gameProvider);
      },
    );
  }

  Widget _buildRoomSelection(BuildContext context, GameProvider gameProvider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çevrimiçi Oyun'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await gameProvider.createRoom('Genel Kültür');
              },
              child: const Text('Yeni Oda Oluştur'),
            ),
            const SizedBox(height: 32),
            const Text(
              'veya',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                labelText: 'Oda ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_roomIdController.text.isNotEmpty) {
                  await gameProvider.joinRoom(_roomIdController.text);
                }
              },
              child: const Text('Odaya Katıl'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen(BuildContext context, GameProvider gameProvider) {
    final room = gameProvider.currentRoom!;
    
    if (!room.gameStarted) {
      return const RoomLobby();
    }

    final currentUserId = _authService.currentUser?.uid;
    final isHost = currentUserId == room.hostId;
    final opponentId = isHost ? room.guestId : room.hostId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çevrimiçi Oyun'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              gameProvider.clearRoom();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerScore(
                  'Siz',
                  room.scores[currentUserId] ?? 0,
                  isHost ? room.hostScore : room.guestScore,
                ),
                _buildPlayerScore(
                  'Rakip',
                  room.scores[opponentId] ?? 0,
                  isHost ? room.guestScore : room.hostScore,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Room Status
            Text(
              'Oda Durumu: ${_getRoomStatusText(room.status)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            // Room ID
            Text(
              'Oda ID: ${room.id}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerScore(String label, int score, int totalScore) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Puan: $score',
          style: const TextStyle(fontSize: 24),
        ),
      ],
    );
  }

  String _getRoomStatusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.waiting:
        return 'Rakip Bekleniyor';
      case RoomStatus.playing:
        return 'Oyun Devam Ediyor';
      case RoomStatus.finished:
        return 'Oyun Bitti';
      case RoomStatus.cancelled:
        return 'Oyun İptal Edildi';
    }
  }
} 