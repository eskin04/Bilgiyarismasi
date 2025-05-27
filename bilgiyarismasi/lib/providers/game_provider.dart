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
        PlayerInfo(
          username: userInfo.username,
          avatarUrl: userInfo.avatarUrl,
        ),
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
      _selectedOption = option;
      _hasAnswered = true;
      notifyListeners();

      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      await _firestoreService.submitAnswer(
        _currentRoom!.id,
        userId,
        _currentRoom!.currentQuestionIndex,
        option,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> moveToNextQuestion() async {
    if (_currentRoom == null) return;

    try {
      await _firestoreService.moveToNextQuestion(_currentRoom!.id);
      _selectedOption = null;
      _hasAnswered = false;
      _timeRemaining = 30;
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
} 