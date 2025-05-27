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
  Timer? _feedbackTimer;
  int _lastQuestionIndex = -1;

  @override
  void initState() {
    super.initState();
    final gameProvider = context.read<GameProvider>();
    if (gameProvider.currentRoom != null) {
      gameProvider.startListening(gameProvider.currentRoom!.id);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _roomIdController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    final gameProvider = context.read<GameProvider>();
    final room = gameProvider.currentRoom;
    if (room == null) return;

    // Reset the timer to the default time limit
    gameProvider.updateTimer(room.defaultTimeLimit);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    if (gameProvider.currentRoom == null) return;

    // Update question status to feedback
    await gameProvider.updateQuestionStatus(QuestionStatus.feedback);

    setState(() {
      _showAnswers = true;
      _isAnswerLocked = true;
    });

    // Calculate and update scores
    final room = gameProvider.currentRoom!;
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId != null) {
      final currentAnswer = room.currentAnswers[currentUserId];
      final currentQuestion = room.questions[room.currentQuestionIndex];
      final isCorrect = currentAnswer == currentQuestion.correctAnswer;

      // Calculate score based on time remaining and correctness
      final baseScore = 10;
      final timeBonus = (gameProvider.timeRemaining / room.defaultTimeLimit) * 5;
      final score = isCorrect ? (baseScore + timeBonus).round() : 0;

      // Update score in Firestore
      await gameProvider.updateScore(score);
    }

    // Wait for 2 seconds to show feedback
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Only host can move to next question
      if (gameProvider.isHost) {
        await gameProvider.moveToNextQuestion();
      }
    }
  }

  Future<void> _handleAnswer(String option) async {
    if (_isAnswerLocked) return;

    final gameProvider = context.read<GameProvider>();
    if (gameProvider.currentRoom == null) return;

    // Ensure we have a valid question index
    if (gameProvider.currentRoom!.currentQuestionIndex < 0 ||
        gameProvider.currentRoom!.currentQuestionIndex >=
            gameProvider.currentRoom!.questions.length) {
      return;
    }

    setState(() {
      _selectedOption = option;
      _isAnswerLocked = true;
    });

    await gameProvider.submitAnswer(option);

    // Listen for question status changes
    gameProvider.roomStream?.listen((room) {
      if (room == null) return;

      if (room.questionStatus == QuestionStatus.feedback && !_showAnswers) {
        setState(() => _showAnswers = true);

        // Calculate and update scores
        final currentUserId = _authService.currentUser?.uid;
        if (currentUserId != null) {
          final currentAnswer = room.currentAnswers[currentUserId];
          final currentQuestion = room.questions[room.currentQuestionIndex];
          final isCorrect = currentAnswer == currentQuestion.correctAnswer;

          // Calculate score based on time remaining and correctness
          final baseScore = 10;
          final timeBonus = (gameProvider.timeRemaining / room.defaultTimeLimit) * 5;
          final score = isCorrect ? (baseScore + timeBonus).round() : 0;

          // Update score in Firestore
          gameProvider.updateScore(score);
        }

        // Wait for 2 seconds to show feedback
        _feedbackTimer?.cancel();
        _feedbackTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showAnswers = false;
              _isAnswerLocked = false;
              _selectedOption = null;
            });
            // Only host can move to next question
            if (gameProvider.isHost) {
              gameProvider.moveToNextQuestion();
            }
          }
        });
      }
    });
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
    final gameProvider = context.read<GameProvider>();
    final maxTime = gameProvider.currentRoom?.defaultTimeLimit ?? 30;

    return Column(
      children: [
        Text(
          'Kalan Süre: ${timeRemaining}s',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: timeRemaining / maxTime,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            timeRemaining > maxTime / 3 ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(Question question) {
    final gameProvider = context.read<GameProvider>();
    final room = gameProvider.currentRoom;
    if (room == null) return const SizedBox.shrink();

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
          final opponentSelected = room.currentAnswers.values.contains(option);

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
                        : opponentSelected
                        ? Colors.orange.withOpacity(0.3)
                        : null,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${String.fromCharCode(65 + index)}. $option',
                    style: TextStyle(
                      color:
                          _showAnswers && (isCorrect || isWrong)
                              ? Colors.white
                              : null,
                    ),
                  ),
                  if (opponentSelected && !isSelected)
                    const Icon(Icons.person, color: Colors.orange),
                ],
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

    // Start timer when game starts or moves to next question
    if (room.status == RoomStatus.playing &&
        room.questionStatus == QuestionStatus.waiting &&
        room.currentQuestionIndex != _lastQuestionIndex) {
      _lastQuestionIndex = room.currentQuestionIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTimer();
      });
    }

    // Check if we've reached the end of the quiz
    if (room.currentQuestionIndex >= room.questions.length) {
      // Navigate to result screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ResultScreen(room: room)),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUserId = _authService.currentUser?.uid;
    final isHost = currentUserId == room.hostId;
    final currentPlayerInfo = room.players[currentUserId];
    final opponentId = isHost ? room.guestId : room.hostId;
    final opponentInfo = room.players[opponentId];

    // Ensure we have a valid question index
    if (room.currentQuestionIndex < 0 ||
        room.currentQuestionIndex >= room.questions.length) {
      return const Scaffold(
        body: Center(child: Text('Soru yüklenirken bir hata oluştu')),
      );
    }

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
