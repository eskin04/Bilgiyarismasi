import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';

class QuizProvider extends ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

  List<Question> questions = [];
  int currentQuestionIndex = 0;
  int score = 0;
  bool isQuizFinished = false;
  bool isLoading = false;
  String? error;

  int get totalQuestions => 10;
  int get remainingQuestions => totalQuestions - currentQuestionIndex;
  double get progress => currentQuestionIndex / totalQuestions;

  Future<void> generateQuestions(String category) async {
    try {
      isLoading = true;
      error = null;
      questions = [];
      currentQuestionIndex = 0;
      score = 0;
      isQuizFinished = false;
      notifyListeners();

      // Soruları oluştur
      questions = await _geminiService.generateQuestions(
        category: category,
        count: totalQuestions,
      );

      if (questions.isEmpty) {
        error = 'Soru oluşturulamadı';
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearCurrentQuestion() {
    questions = [];
    currentQuestionIndex = 0;
    score = 0;
    isQuizFinished = false;
    error = null;
    notifyListeners();
  }

  Future<void> submitAnswer(String answer) async {
    if (questions.isEmpty || currentQuestionIndex >= questions.length) return;

    final question = questions[currentQuestionIndex];
    final isCorrect = answer == question.correctAnswer;
    await _firestoreService.saveQuizResult(
      question: question,
      userAnswer: answer,
      isCorrect: isCorrect,
    );

    if (isCorrect) {
      score += 10;
    }

    currentQuestionIndex++;
    if (currentQuestionIndex >= totalQuestions) {
      isQuizFinished = true;
    }
    notifyListeners();
  }
}
