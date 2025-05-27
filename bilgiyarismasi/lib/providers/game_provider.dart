import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/question.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import 'dart:developer' as developer;

class GameProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();
  
  Room? _currentRoom;
  bool _isLoading = false;
  String? _error;
  int _timeRemaining = 30;
  bool _hasAnswered = false;
  String? _selectedOption;
  Stream<Room?>? _roomStream;

  Room? get currentRoom => _currentRoom;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get timeRemaining => _timeRemaining;
  bool get hasAnswered => _hasAnswered;
  String? get selectedOption => _selectedOption;
  Stream<Room?>? get roomStream => _roomStream;

  void updateTimer(int time) {
    _timeRemaining = time;
    notifyListeners();
  }

  Future<void> createRoom(String category) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Generate questions
      final questions = await _geminiService.generateQuestions(
        category: category,
        count: 10,
      );
      
      // Create room in Firestore
      final roomId = await _firestoreService.createRoom(
        category: category,
        questions: questions,
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

      final room = await _firestoreService.joinRoom(roomId);
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
    _roomStream?.listen(
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

  Future<void> submitAnswer(String option) async {
    if (_currentRoom == null) return;

    try {
      _selectedOption = option;
      _hasAnswered = true;
      notifyListeners();

      await _firestoreService.submitAnswer(
        _currentRoom!.id,
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