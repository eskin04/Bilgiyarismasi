import 'package:cloud_firestore/cloud_firestore.dart';
import 'question.dart';
import 'user.dart';

enum RoomStatus {
  waiting,    // Waiting for opponent to join
  playing,    // Game is in progress
  finished,   // Game has ended
  cancelled   // Game was cancelled
}

enum QuestionStatus {
  waiting,    // Question is active, waiting for answers
  feedback,   // Both players answered or time is up, showing feedback
  next        // Ready to move to next question
}

class Room {
  final String id;
  final String hostId;
  final String? guestId;
  final String category;
  final RoomStatus status;
  final int currentQuestionIndex;
  final List<Question> questions;
  final Map<String, int> scores;
  final DateTime createdAt;
  final bool gameStarted;
  final Map<String, PlayerInfo> players;
  final QuestionStatus questionStatus;
  final Map<String, String> currentAnswers;
  final int defaultTimeLimit;
  final DateTime? questionStartTime;
  final Map<String, String> revealedAnswers;
  final bool rematchRequested;
  final String? rematchRequestedBy;

  Room({
    required this.id,
    required this.hostId,
    this.guestId,
    required this.category,
    required this.status,
    required this.currentQuestionIndex,
    required this.questions,
    required this.scores,
    required this.createdAt,
    this.gameStarted = false,
    required this.players,
    this.questionStatus = QuestionStatus.waiting,
    this.currentAnswers = const {},
    this.defaultTimeLimit = 30,
    this.questionStartTime,
    this.revealedAnswers = const {},
    this.rematchRequested = false,
    this.rematchRequestedBy,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      hostId: json['hostId'] as String,
      guestId: json['guestId'] as String?,
      category: json['category'] as String,
      status: RoomStatus.values.firstWhere(
        (e) => e.toString() == 'RoomStatus.${json['status']}',
        orElse: () => RoomStatus.waiting,
      ),
      currentQuestionIndex: json['currentQuestionIndex'] as int,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
      scores: Map<String, int>.from(json['scores'] as Map),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      gameStarted: json['gameStarted'] as bool? ?? false,
      players: (json['players'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              PlayerInfo.fromJson(value as Map<String, dynamic>),
            ),
          ) ??
          {},
      questionStatus: QuestionStatus.values.firstWhere(
        (e) => e.toString() == 'QuestionStatus.${json['questionStatus']}',
        orElse: () => QuestionStatus.waiting,
      ),
      currentAnswers: Map<String, String>.from(json['currentAnswers'] as Map? ?? {}),
      defaultTimeLimit: json['defaultTimeLimit'] as int? ?? 30,
      questionStartTime: json['questionStartTime'] != null
          ? (json['questionStartTime'] as Timestamp).toDate()
          : null,
      revealedAnswers: Map<String, String>.from(json['revealedAnswers'] as Map? ?? {}),
      rematchRequested: json['rematchRequested'] as bool? ?? false,
      rematchRequestedBy: json['rematchRequestedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hostId': hostId,
      'guestId': guestId,
      'category': category,
      'status': status.toString().split('.').last,
      'currentQuestionIndex': currentQuestionIndex,
      'questions': questions.map((q) => q.toJson()).toList(),
      'scores': scores,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameStarted': gameStarted,
      'players': players.map((key, value) => MapEntry(key, value.toJson())),
      'questionStatus': questionStatus.toString().split('.').last,
      'currentAnswers': currentAnswers,
      'defaultTimeLimit': defaultTimeLimit,
      'questionStartTime': questionStartTime != null ? Timestamp.fromDate(questionStartTime!) : null,
      'revealedAnswers': revealedAnswers,
      'rematchRequested': rematchRequested,
      'rematchRequestedBy': rematchRequestedBy,
    };
  }

  bool get isFull => guestId != null;
  bool get isWaiting => status == RoomStatus.waiting;
  bool get isPlaying => status == RoomStatus.playing;
  bool get isFinished => status == RoomStatus.finished;
  bool get isCancelled => status == RoomStatus.cancelled;
  bool get canStartGame => isFull && !gameStarted;

  int get hostScore => scores[hostId] ?? 0;
  int get guestScore => guestId != null ? scores[guestId!] ?? 0 : 0;

  PlayerInfo? get hostInfo => players[hostId];
  PlayerInfo? get guestInfo => guestId != null ? players[guestId!] : null;

  Room copyWith({
    String? id,
    String? hostId,
    String? guestId,
    String? category,
    RoomStatus? status,
    int? currentQuestionIndex,
    List<Question>? questions,
    Map<String, int>? scores,
    DateTime? createdAt,
    bool? gameStarted,
    Map<String, PlayerInfo>? players,
    QuestionStatus? questionStatus,
    Map<String, String>? currentAnswers,
    int? defaultTimeLimit,
    DateTime? questionStartTime,
    Map<String, String>? revealedAnswers,
    bool? rematchRequested,
    String? rematchRequestedBy,
  }) {
    return Room(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      guestId: guestId ?? this.guestId,
      category: category ?? this.category,
      status: status ?? this.status,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      questions: questions ?? this.questions,
      scores: scores ?? this.scores,
      createdAt: createdAt ?? this.createdAt,
      gameStarted: gameStarted ?? this.gameStarted,
      players: players ?? this.players,
      questionStatus: questionStatus ?? this.questionStatus,
      currentAnswers: currentAnswers ?? this.currentAnswers,
      defaultTimeLimit: defaultTimeLimit ?? this.defaultTimeLimit,
      questionStartTime: questionStartTime ?? this.questionStartTime,
      revealedAnswers: revealedAnswers ?? this.revealedAnswers,
      rematchRequested: rematchRequested ?? this.rematchRequested,
      rematchRequestedBy: rematchRequestedBy ?? this.rematchRequestedBy,
    );
  }
}

class PlayerInfo {
  final String username;
  final String avatarUrl;
  final bool isReady;

  PlayerInfo({
    required this.username,
    required this.avatarUrl,
    this.isReady = false,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String,
      isReady: json['isReady'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'avatarUrl': avatarUrl,
      'isReady': isReady,
    };
  }

  PlayerInfo copyWith({
    String? username,
    String? avatarUrl,
    bool? isReady,
  }) {
    return PlayerInfo(
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isReady: isReady ?? this.isReady,
    );
  }
}

class PlayerScore {
  final int totalScore;
  final Map<int, Answer> answers;

  PlayerScore({
    this.totalScore = 0,
    this.answers = const {},
  });

  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      totalScore: json['totalScore'] as int? ?? 0,
      answers: (json['answers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              int.parse(key),
              Answer.fromJson(value as Map<String, dynamic>),
            ),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalScore': totalScore,
      'answers': answers.map((key, value) => MapEntry(key.toString(), value.toJson())),
    };
  }
}

class Answer {
  final String selectedOption;
  final bool isCorrect;
  final int responseTime;
  final int score;

  Answer({
    required this.selectedOption,
    required this.isCorrect,
    required this.responseTime,
    required this.score,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      selectedOption: json['selectedOption'] as String,
      isCorrect: json['isCorrect'] as bool,
      responseTime: json['responseTime'] as int,
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedOption': selectedOption,
      'isCorrect': isCorrect,
      'responseTime': responseTime,
      'score': score,
    };
  }
} 