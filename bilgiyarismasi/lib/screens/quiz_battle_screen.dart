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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata oluştu: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cevap gönderilemedi: $e')));
        setState(() {
          _isAnswerLocked = false;
          _selectedOption = null;
        });
      }
    }
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
                      Navigator.of(context).pop();
                    },
                    child: const Text('Geri Dön'),
                  ),
                ],
              ),
            ),
          );
        }

        // Eğer oda yoksa oda seçim ekranını göster
        if (gameProvider.currentRoom == null) {
          return _buildRoomSelection(context, gameProvider);
        }

        // Eğer oyun başlamamışsa lobby ekranını göster
        if (!gameProvider.currentRoom!.gameStarted) {
          return const RoomLobby();
        }

        // Eğer oyun başlamışsa ve son soruya gelinmişse, result ekranına git
        if (gameProvider.currentRoom!.currentQuestionIndex >=
                gameProvider.currentRoom!.questions.length - 1 &&
            gameProvider.currentRoom!.questionStatus ==
                QuestionStatus.feedback) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (context) => ResultScreen(room: gameProvider.currentRoom!),
              ),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Normal oyun ekranını göster
        return _buildGameScreen(context, gameProvider);
      },
    );
  }

  Widget _buildRoomSelection(BuildContext context, GameProvider gameProvider) {
    String selectedCategory = 'Genel Kültür';
    final List<String> categories = [
      'Genel Kültür',
      'Tarih',
      'Coğrafya',
      'Bilim',
      'Spor',
      'Sanat',
      'Teknoloji',
      'Eğlence',
    ];

    return Scaffold(
      body: Container(
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
          child: Column(
            children: [
              // Üst Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Çevrimiçi Oyun',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Ana İçerik
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kategori Seçimi
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.category,
                                      size: 32,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kategori Seçin',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Yarışmak istediğiniz kategoriyi seçin',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                items:
                                    categories.map((String category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    selectedCategory = newValue;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Oda Oluştur Butonu
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      size: 32,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Yeni Oda Oluştur',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Arkadaşlarını davet et ve yarışmaya başla',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await gameProvider.createRoom(
                                      selectedCategory,
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text(
                                    'Oda Oluştur',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Odaya Katıl
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.login,
                                      size: 32,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Odaya Katıl',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Var olan bir odaya katıl',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _roomIdController,
                                decoration: InputDecoration(
                                  labelText: 'Oda ID',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (_roomIdController.text.isNotEmpty) {
                                      await gameProvider.joinRoom(
                                        _roomIdController.text,
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.login),
                                  label: const Text(
                                    'Odaya Katıl',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      body: Container(
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
          child: Column(
            children: [
              // Üst Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        gameProvider.clearRoom();
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Soru ${room.currentQuestionIndex + 1}/${room.questions.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(currentQuestion.category),
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentQuestion.category,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Ana İçerik
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Oyuncu Bilgileri
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
                      const SizedBox(height: 16),
                      // Soru ve Seçenekler
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildQuestion(currentQuestion),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(
    PlayerInfo? playerInfo,
    int score,
    bool isCurrentUser,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor:
                  isCurrentUser
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.grey[200],
              child:
                  playerInfo?.avatarUrl != null
                      ? ClipOval(
                        child: Image.asset(
                          playerInfo!.avatarUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey,
                            );
                          },
                        ),
                      )
                      : const Icon(Icons.person, size: 40, color: Colors.grey),
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
        ),
      ),
    );
  }

  Widget _buildTimer(int timeRemaining) {
    final gameProvider = context.read<GameProvider>();
    final maxTime = gameProvider.currentRoom?.defaultTimeLimit ?? 30;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
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
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(Question question) {
    final gameProvider = context.read<GameProvider>();
    final room = gameProvider.currentRoom;
    if (room == null) return const SizedBox.shrink();

    final currentUserId = _authService.currentUser?.uid;
    final opponentId = room.players.keys.firstWhere(
      (id) => id != currentUserId,
    );
    final currentPlayerInfo = room.players[currentUserId];
    final opponentPlayerInfo = room.players[opponentId];

    // Feedback aşamasında revealedAnswers kullanılır, diğer durumda currentAnswers
    final isFeedback = room.questionStatus == QuestionStatus.feedback;
    final myAnswer =
        isFeedback
            ? room.revealedAnswers[currentUserId]
            : room.currentAnswers[currentUserId];
    final opponentAnswer =
        isFeedback
            ? room.revealedAnswers[opponentId]
            : room.currentAnswers[opponentId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          final bool isButtonEnabled =
              !isFeedback ? (myAnswer == null ? true : isMySelection) : false;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Stack(
              children: [
                ElevatedButton(
                  onPressed:
                      isButtonEnabled ? () => _handleAnswer(option) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    side: borderSide,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${String.fromCharCode(65 + index)}. $option',
                        style: TextStyle(
                          color:
                              isFeedback && (isCorrect || isWrong)
                                  ? Colors.black87
                                  : null,
                          fontWeight:
                              isFeedback && isCorrect
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontSize: 14,
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
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            child:
                                currentPlayerInfo?.avatarUrl != null
                                    ? ClipOval(
                                      child: Image.asset(
                                        currentPlayerInfo!.avatarUrl,
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.grey,
                                          );
                                        },
                                      ),
                                    )
                                    : const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                          ),
                        if (isOpponentSelection)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey[200],
                              child:
                                  opponentPlayerInfo?.avatarUrl != null
                                      ? ClipOval(
                                        child: Image.asset(
                                          opponentPlayerInfo!.avatarUrl,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return const Icon(
                                              Icons.person,
                                              size: 16,
                                              color: Colors.grey,
                                            );
                                          },
                                        ),
                                      )
                                      : const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'genel kültür':
        return Icons.school;
      case 'tarih':
        return Icons.history;
      case 'coğrafya':
        return Icons.public;
      case 'bilim':
        return Icons.science;
      case 'spor':
        return Icons.sports_soccer;
      case 'sanat':
        return Icons.palette;
      case 'teknoloji':
        return Icons.computer;
      default:
        return Icons.category;
    }
  }
}
