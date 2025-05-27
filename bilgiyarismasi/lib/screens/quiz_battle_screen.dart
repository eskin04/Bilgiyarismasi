import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/room.dart';
import '../models/question.dart';
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
  String? _selectedOption;
  bool _isAnswerLocked = false;

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
    setState(() {
      _showAnswers = true;
      _isAnswerLocked = true;
    });

    // Wait for 3 seconds to show answers
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _showAnswers = false;
        _isAnswerLocked = false;
        _selectedOption = null;
      });
      await gameProvider.moveToNextQuestion();
      _startTimer();
    }
  }

  Future<void> _handleAnswer(String option) async {
    if (_isAnswerLocked) return;

    final gameProvider = context.read<GameProvider>();
    setState(() {
      _selectedOption = option;
      _isAnswerLocked = true;
    });

    await gameProvider.submitAnswer(option);
    setState(() => _showAnswers = true);

    // Wait for 3 seconds to show answers
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _showAnswers = false;
        _isAnswerLocked = false;
        _selectedOption = null;
      });
      await gameProvider.moveToNextQuestion();
      _startTimer();
    }
  }

  Widget _buildPlayerAvatar(
    PlayerInfo? playerInfo,
    int score,
    bool isCurrentUser,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: AssetImage(playerInfo!.avatarUrl) as ImageProvider,
          child:
              playerInfo?.avatarUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
        ),
        const SizedBox(height: 8),
        Text(
          playerInfo?.username ?? 'Bekleniyor',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Puan: $score',
          style: TextStyle(
            fontSize: 18,
            color: isCurrentUser ? Colors.blue : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(int timeRemaining) {
    return Column(
      children: [
        Text(
          'Kalan Süre: ${timeRemaining}s',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: timeRemaining / 30,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            timeRemaining > 10 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(Question question) {
    return Column(
      children: [
        Text(
          question.text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ...question.options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = _selectedOption == option;
          final isCorrect = _showAnswers && option == question.correctAnswer;
          final isWrong =
              _showAnswers && isSelected && option != question.correctAnswer;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: _isAnswerLocked ? null : () => _handleAnswer(option),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _showAnswers
                        ? isCorrect
                            ? Colors.green
                            : isWrong
                            ? Colors.red
                            : null
                        : isSelected
                        ? Colors.blue
                        : null,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                '${String.fromCharCode(65 + index)}. $option',
                style: TextStyle(
                  color:
                      _showAnswers && (isCorrect || isWrong)
                          ? Colors.white
                          : null,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        if (gameProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (gameProvider.error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Hata')),
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
      appBar: AppBar(title: const Text('Çevrimiçi Oyun')),
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
            const Text('veya', style: TextStyle(fontSize: 16)),
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
    final currentPlayerInfo = room.players[currentUserId];
    final opponentId = isHost ? room.guestId : room.hostId;
    final opponentInfo = room.players[opponentId];

    final currentQuestion = room.questions[room.currentQuestionIndex];

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
            // Player Avatars and Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerAvatar(
                  currentPlayerInfo,
                  room.scores[currentUserId] ?? 0,
                  true,
                ),
                _buildPlayerAvatar(
                  opponentInfo,
                  room.scores[opponentId] ?? 0,
                  false,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Timer
            _buildTimer(gameProvider.timeRemaining),
            const SizedBox(height: 32),
            // Question and Options
            Expanded(
              child: SingleChildScrollView(
                child: _buildQuestion(currentQuestion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
