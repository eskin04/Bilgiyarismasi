class Question {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String category;

  Question({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.category,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'category': category,
    };
  }
} 