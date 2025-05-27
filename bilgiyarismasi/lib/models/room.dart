import 'package:cloud_firestore/cloud_firestore.dart';
import 'question.dart';
import 'user.dart';

enum RoomStatus {
  waiting,    // Waiting for opponent to join
  playing,    // Game is in progress
  finished,   // Game has ended
  cancelled   // Game was cancelled
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