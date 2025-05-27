import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/question.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import 'dart:developer' as developer;

class GameProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();

  Room? _currentRoom;
  bool _isLoading = false;
  String? _error;
  int _timeRemaining = 30;
  bool _hasAnswered = false;
  String? _selectedOption;
  Stream<Room?>? _roomStream;
  StreamSubscription<Room?>? _roomSubscription;
  DateTime? _questionStartTime;

  Room? get currentRoom => _currentRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get timeRemaining => _timeRemaining;
  bool get hasAnswered => _hasAnswered;
  String? get selectedOption => _selectedOption;
  Stream<Room?>? get roomStream => _roomStream;
  bool get isHost => _currentRoom?.hostId == _authService.currentUser?.uid;
  bool get canStartGame => _currentRoom?.canStartGame ?? false;
  String? get currentUserId => _authService.currentUser?.uid;

  void updateTimer(int time) {
    _timeRemaining = time;
    if (_questionStartTime == null) {
      _questionStartTime = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> createRoom(String category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      // Get user info
      final userInfo = await _authService.getUser(userId);
      if (userInfo == null) throw Exception('Kullanıcı bilgileri alınamadı');

      // Generate questions
      final questions = await _geminiService.generateQuestions(
        category: category,
        count: 10,
      );

      // Create room in Firestore
      final roomId = await _firestoreService.createRoom(
        hostId: userId,
        category: category,
        questions: questions,
        hostInfo: PlayerInfo(
          username: userInfo.username,
          avatarUrl: userInfo.avatarUrl,
          isReady: false,
        ),
      );

      // Get the created room
      final room = await _firestoreService.getRoom(roomId);
      if (room != null) {
        _currentRoom = room;
        startListening(roomId);
      } else {
        _error = 'Oda oluşturulamadı';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinRoom(String roomId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      // Get user info
      final userInfo = await _authService.getUser(userId);
      if (userInfo == null) throw Exception('Kullanıcı bilgileri alınamadı');

      final room = await _firestoreService.joinRoom(
        roomId,
        userId,
        PlayerInfo(username: userInfo.username, avatarUrl: userInfo.avatarUrl),
      );

      if (room != null) {
        _currentRoom = room;
        startListening(roomId);
      } else {
        _error = 'Odaya katılınamadı';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startListening(String roomId) {
    _roomStream = _firestoreService.watchRoom(roomId);
    _roomSubscription?.cancel();
    _roomSubscription = _roomStream?.listen(
      (room) {
        if (room != null) {
          _currentRoom = room;
          notifyListeners();
        }
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> startGame() async {
    if (_currentRoom == null || !isHost || !canStartGame) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _firestoreService.startGame(_currentRoom!.id);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPlayerReady(bool isReady) async {
    if (_currentRoom == null) return;

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      await _firestoreService.updatePlayerReady(
        _currentRoom!.id,
        userId,
        isReady,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  Future<void> submitAnswer(String option) async {
    if (_currentRoom == null) return;

    try {
      // Ensure we have a valid question index
      if (_currentRoom!.currentQuestionIndex < 0 || 
          _currentRoom!.currentQuestionIndex >= _currentRoom!.questions.length) {
        throw Exception('Geçersiz soru indeksi');
      }

      _selectedOption = option;
      _hasAnswered = true;
      notifyListeners();

      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      final currentQuestion = _currentRoom!.questions[_currentRoom!.currentQuestionIndex];
      final isCorrect = option == currentQuestion.correctAnswer;
      
      // Calculate time taken to answer
      int timeTaken = 0;
      int score = 0;
      
      if (isCorrect && _questionStartTime != null) {
        // Calculate time taken in seconds
        timeTaken = DateTime.now().difference(_questionStartTime!).inSeconds;
        final maxTime = _currentRoom!.defaultTimeLimit;
        
        // Calculate time bonus based on how quickly they answered
        // The faster they answer, the higher the bonus
        final timeBonus = (5 * (1 - (timeTaken / maxTime))).round();
        score = 10 + timeBonus;
        
        // Ensure minimum score is base score
        score = score < 10 ? 10 : score;
      }

      // Submit answer with the calculated score
      await _firestoreService.submitAnswer(
        _currentRoom!.id,
        userId,
        _currentRoom!.currentQuestionIndex,
        option,
        isCorrect,
        timeTaken,
        score,
      );

      // Update the score immediately in the local state
      if (isCorrect) {
        final currentScore = _currentRoom!.scores[userId] ?? 0;
        _currentRoom = _currentRoom!.copyWith(
          scores: {
            ..._currentRoom!.scores,
            userId: currentScore + score,
          },
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateQuestionStatus(QuestionStatus status) async {
    if (_currentRoom == null) return;

    try {
      await _firestoreService.updateQuestionStatus(_currentRoom!.id, status);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveToNextQuestion() async {
    if (_currentRoom == null) return;

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      final nextIndex = _currentRoom!.currentQuestionIndex + 1;
      
      // Check if we've reached the end of the quiz
      if (nextIndex >= _currentRoom!.questions.length) {
        // Game is finished
        await _firestoreService.endGame(_currentRoom!.id);
        notifyListeners();
        return;
      }

      // Ensure the next index is valid
      if (nextIndex < 0 || nextIndex >= _currentRoom!.questions.length) {
        throw Exception('Geçersiz soru indeksi');
      }

      await _firestoreService.moveToNextQuestion(_currentRoom!.id, userId);
      _selectedOption = null;
      _hasAnswered = false;
      _timeRemaining = _currentRoom!.defaultTimeLimit;
      _questionStartTime = null; // Reset question start time
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearRoom() {
    _currentRoom = null;
    _roomStream = null;
    _error = null;
    _timeRemaining = 30;
    _selectedOption = null;
    _hasAnswered = false;
    notifyListeners();
  }

  Future<void> updateScore(int score) async {
    if (_currentRoom == null) return;

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      // Get current score
      final currentScore = _currentRoom!.scores[userId] ?? 0;
      
      // Update score in Firestore
      await _firestoreService.updateScore(_currentRoom!.id, userId, currentScore + score);
      
      // Update local state
      _currentRoom = _currentRoom!.copyWith(
        scores: {
          ..._currentRoom!.scores,
          userId: currentScore + score,
        },
      );
      
      notifyListeners();
    } catch (e) {
      _error = 'Puan güncellenirken bir hata oluştu: $e';
      notifyListeners();
    }
  }
}
