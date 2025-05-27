import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class QuizScreen extends StatelessWidget {
  final List<String> categories = [
    'Tarih',
    'Bilim',
    'Sanat',
    'Spor',
    'Coğrafya',
    'Genel Kültür',
  ];

  QuizScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      final authService = AuthService();
      await authService.logout();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çıkış yapılırken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgi Yarışması'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Consumer<QuizProvider>(
        builder: (context, quizProvider, child) {
          if (quizProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (quizProvider.error != null) {
            return Center(
              child: Text(
                'Hata: ${quizProvider.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (quizProvider.currentQuestion == null) {
            return _buildCategorySelection(context, quizProvider);
          }

          return _buildQuestion(context, quizProvider);
        },
      ),
    );
  }

  Widget _buildCategorySelection(BuildContext context, QuizProvider quizProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Kategori Seçin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () => quizProvider.generateQuestion(category),
                  child: Text(category),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizProvider quizProvider) {
    final question = quizProvider.currentQuestion!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.question,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...question.options.map((option) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () async {
                    await quizProvider.submitAnswer(option);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            option == question.correctAnswer
                                ? 'Doğru cevap!'
                                : 'Yanlış cevap. Doğru cevap: ${question.correctAnswer}',
                          ),
                          backgroundColor: option == question.correctAnswer
                              ? Colors.green
                              : Colors.red,
                        ),
                      );
                      quizProvider.generateQuestion(question.category);
                    }
                  },
                  child: Text(option),
                ),
              )),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => quizProvider.generateQuestion(question.category),
            child: const Text('Yeni Soru'),
          ),
        ],
      ),
    );
  }
} 