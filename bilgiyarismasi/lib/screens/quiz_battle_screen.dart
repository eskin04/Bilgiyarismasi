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

    setState(() {
      _isAnswerLocked = true;
    });

    try {
      // Update question status to feedback
      await gameProvider.updateQuestionStatus(QuestionStatus.feedback);

      // Wait for 2 seconds to show feedback
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Only host can move to next question
        if (gameProvider.isHost) {
          await gameProvider.moveToNextQuestion();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _handleAnswer(String option) async {
    if (_isAnswerLocked) return;

    final gameProvider = context.read<GameProvider>();
    if (gameProvider.currentRoom == null) return;

    setState(() {
      _selectedOption = option;
      _isAnswerLocked = true;
    });

    try {
      await gameProvider.submitAnswer(option);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cevap gönderilemedi: $e')),
        );
        setState(() {
          _isAnswerLocked = false;
          _selectedOption = null;
        });
      }
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

    final currentUserId = _authService.currentUser?.uid;
    final opponentId = room.players.keys.firstWhere((id) => id != currentUserId);
    final currentPlayerInfo = room.players[currentUserId];
    final opponentPlayerInfo = room.players[opponentId];

    // Feedback aşamasında revealedAnswers kullanılır, diğer durumda currentAnswers
    final isFeedback = room.questionStatus == QuestionStatus.feedback;
    final myAnswer = isFeedback
        ? room.revealedAnswers[currentUserId]
        : room.currentAnswers[currentUserId];
    final opponentAnswer = isFeedback
        ? room.revealedAnswers[opponentId]
        : room.currentAnswers[opponentId];

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

          final isMySelection = myAnswer == option;
          final isOpponentSelection = opponentAnswer == option;
          final isCorrect = option == question.correctAnswer;
          final isWrong = isMySelection && !isCorrect;

          // Buton rengi ve stili
          Color? buttonColor;
          BorderSide? borderSide;

          if (isFeedback) {
            if (isCorrect) {
              // Doğru cevap - Yeşil arka plan ve kalın yeşil kenarlık
              buttonColor = Colors.green.shade200;
              borderSide = BorderSide(color: Colors.green.shade700, width: 2.0);
            } else if (isWrong) {
              // Yanlış seçim - Kırmızı arka plan ve kalın kırmızı kenarlık
              buttonColor = Colors.red.shade200;
              borderSide = BorderSide(color: Colors.red.shade700, width: 2.0);
            } else if (isOpponentSelection) {
              // Rakibin seçimi - Mavi kenarlık
              borderSide = const BorderSide(color: Colors.blue, width: 2.0);
            }
          } else {
            // Normal seçim durumu
            buttonColor = isMySelection ? Colors.blue.shade200 : null;
          }

          // Butonun aktif olup olmadığını belirle
          final bool isButtonEnabled = !isFeedback
              ? (myAnswer == null ? true : isMySelection)
              : false;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Stack(
              children: [
                ElevatedButton(
                  onPressed: isButtonEnabled ? () => _handleAnswer(option) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    side: borderSide,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${String.fromCharCode(65 + index)}. $option',
                        style: TextStyle(
                          color: isFeedback && (isCorrect || isWrong)
                              ? Colors.black87
                              : null,
                          fontWeight: isFeedback && isCorrect
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (isFeedback && isCorrect)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),
                if (isFeedback && (isMySelection || isOpponentSelection))
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        if (isMySelection)
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: AssetImage(
                                currentPlayerInfo?.avatarUrl ?? 'assets/default_avatar.png'),
                            child: currentPlayerInfo?.avatarUrl == null
                                ? const Icon(Icons.person, size: 16)
                                : null,
                          ),
                        if (isOpponentSelection)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage(
                                  opponentPlayerInfo?.avatarUrl ?? 'assets/default_avatar.png'),
                              child: opponentPlayerInfo?.avatarUrl == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
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
      _selectedOption = null;
      _isAnswerLocked = false;
      _showAnswers = false;
      
      // Start timer for new question
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTimer();
      });
    }

    // Son soru kontrolü
    if (room.currentQuestionIndex >= room.questions.length - 1 && 
        room.questionStatus == QuestionStatus.feedback) {
      // Son soru ve feedback aşamasında ise result ekranına geç
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
        title: Text('Soru ${room.currentQuestionIndex + 1}/${room.questions.length}'),
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
