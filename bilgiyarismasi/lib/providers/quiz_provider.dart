import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';

class QuizProvider with ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  Question? _currentQuestion;
  bool _isLoading = false;
  String? _error;

  Question? get currentQuestion => _currentQuestion;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> generateQuestion(String category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final questions = await _geminiService.generateQuestions(
        category: category,
        count: 1,
      );
      if (questions.isNotEmpty) {
        _currentQuestion = questions.first;
      } else {
        _error = 'No questions generated';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitAnswer(String answer) async {
    if (_currentQuestion == null) return;

    final isCorrect = answer == _currentQuestion!.correctAnswer;
    await _firestoreService.saveQuizResult(
      question: _currentQuestion!,
      userAnswer: answer,
      isCorrect: isCorrect,
    );
  }
} 