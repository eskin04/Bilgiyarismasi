import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quiz_provider.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class QuizScreen extends StatefulWidget {
  final List<String> categories = [
    'Tarih',
    'Bilim',
    'Sanat',
    'Spor',
    'Coğrafya',
    'Genel Kültür',
  ];

  QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _showAnswers = false;
  String? _selectedOption;

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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Consumer<QuizProvider>(
                      builder:
                          (context, quizProvider, child) => Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                if (quizProvider.currentQuestion != null) {
                                  quizProvider.clearCurrentQuestion();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ),
                    ),
                    const Spacer(),
                    Consumer<QuizProvider>(
                      builder:
                          (context, quizProvider, child) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (quizProvider.currentQuestion != null) ...[
                                  Icon(
                                    _getCategoryIcon(
                                      quizProvider.currentQuestion!.category,
                                    ),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  quizProvider.currentQuestion != null
                                      ? quizProvider.currentQuestion!.category
                                      : 'Bilgi Yarışması',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ),
                    const Spacer(),
                    // Sağ tarafta boşluk bırakıyoruz
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Ana İçerik
              Expanded(
                child: Consumer<QuizProvider>(
                  builder: (context, quizProvider, child) {
                    if (quizProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      );
                    }

                    if (quizProvider.error != null) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Hata: ${quizProvider.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    if (quizProvider.currentQuestion == null) {
                      return _buildCategorySelection(context, quizProvider);
                    }

                    return _buildQuestion(context, quizProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection(
    BuildContext context,
    QuizProvider quizProvider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                ...widget.categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
                      onPressed: () => quizProvider.generateQuestion(category),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
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
                              _getCategoryIcon(category),
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getCategoryDescription(category),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuizProvider quizProvider) {
    final question = quizProvider.currentQuestion!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Soru Kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ...question.options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ElevatedButton(
                      onPressed:
                          _showAnswers
                              ? null
                              : () async {
                                if (context.mounted) {
                                  setState(() {
                                    _showAnswers = true;
                                    _selectedOption = option;
                                  });

                                  Future.delayed(
                                    const Duration(seconds: 2),
                                    () {
                                      if (context.mounted) {
                                        setState(() {
                                          _showAnswers = false;
                                          _selectedOption = null;
                                        });
                                        quizProvider.generateQuestion(
                                          question.category,
                                        );
                                      }
                                    },
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _showAnswers
                                ? option == question.correctAnswer
                                    ? Colors.green.withOpacity(0.1)
                                    : option == _selectedOption
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.white
                                : Colors.white,
                        foregroundColor:
                            _showAnswers
                                ? option == question.correctAnswer
                                    ? Colors.green.shade700
                                    : option == _selectedOption
                                    ? Colors.red.shade700
                                    : Colors.grey.shade400
                                : Theme.of(context).colorScheme.primary,
                        elevation: _showAnswers ? 0 : 2,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                              _showAnswers
                                  ? BorderSide(
                                    color:
                                        option == question.correctAnswer
                                            ? Colors.green.shade700
                                            : option == _selectedOption
                                            ? Colors.red.shade700
                                            : Colors.grey.shade300,
                                    width: 2,
                                  )
                                  : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    _showAnswers
                                        ? option == question.correctAnswer
                                            ? Colors.green.shade700
                                            : option == _selectedOption
                                            ? Colors.red.shade700
                                            : Colors.grey.shade400
                                        : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          if (_showAnswers && option == question.correctAnswer)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                          if (_showAnswers &&
                              option == _selectedOption &&
                              option != question.correctAnswer)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Yeni Soru Butonu
          ElevatedButton.icon(
            onPressed: () => quizProvider.generateQuestion(question.category),
            icon: const Icon(Icons.refresh),
            label: const Text('Yeni Soru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.9),
              foregroundColor: Theme.of(context).colorScheme.primary,
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
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

  String _getCategoryDescription(String category) {
    switch (category.toLowerCase()) {
      case 'genel kültür':
        return 'Genel bilgi ve kültür soruları';
      case 'tarih':
        return 'Tarihi olaylar ve kişiler';
      case 'coğrafya':
        return 'Ülkeler, şehirler ve doğal güzellikler';
      case 'bilim':
        return 'Bilimsel keşifler ve buluşlar';
      case 'spor':
        return 'Spor dalları ve sporcular';
      case 'sanat':
        return 'Sanat eserleri ve sanatçılar';
      default:
        return 'Kategori hakkında sorular';
    }
  }
}
