class Question {
  final String text;
  final List<String> options;
  final String correctAnswer;
  final int timeLimit;
  final String category;

  Question({
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.timeLimit = 30,
    required this.category,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      text: json['text'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correctAnswer'] as String,
      timeLimit: json['timeLimit'] as int? ?? 30,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'timeLimit': timeLimit,
      'category': category,
    };
  }
} 