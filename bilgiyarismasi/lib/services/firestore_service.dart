import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';
import '../models/user.dart';
import '../models/room.dart';
import 'dart:developer' as developer;
import '../services/auth_service.dart';
import 'dart:math';
import 'package:rxdart/rxdart.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  static const String _roomsCollection = 'rooms';
  static const String _usersCollection = 'users';

  String _generateShortId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _getUniqueRoomId() async {
    String roomId;
    bool isUnique = false;
    
    do {
      roomId = _generateShortId();
      final doc = await _firestore.collection(_roomsCollection).doc(roomId).get();
      isUnique = !doc.exists;
    } while (!isUnique);

    return roomId;
  }

  Future<void> saveQuizResult({
    required Question question,
    required String userAnswer,
    required bool isCorrect,
  }) async {
    try {
      final userId = _firestore.app.options.projectId!; // TODO: Replace with actual user ID
      await _firestore.collection('quiz_results').add({
        'userId': userId,
        'questionId': question.text,
        'userAnswer': userAnswer,
        'isCorrect': isCorrect,
        'category': question.category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error saving quiz result: $e');
      throw Exception('Quiz sonucu kaydedilirken bir hata oluştu: $e');
    }
  }

  Stream<QuerySnapshot> getUserQuizHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('quiz_results')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> saveUserData(UserModel user) async {
    try {
      final userData = {
        'uid': user.uid,
        'email': user.email,
        'username': user.username,
        'avatarUrl': user.avatarUrl,
      };
      
      await _firestore.collection('users').doc(user.uid).set(userData);
    } catch (e) {
      throw Exception('Kullanıcı bilgileri kaydedilirken bir hata oluştu: $e');
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return UserModel(
        uid: data['uid'] as String,
        email: data['email'] as String,
        username: data['username'] as String,
        avatarUrl: data['avatarUrl'] as String,
      );
    } catch (e) {
      throw Exception('Kullanıcı bilgileri alınırken bir hata oluştu: $e');
    }
  }

  Stream<UserModel?> getUserDataStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;

          return UserModel(
            uid: data['uid'] as String,
            email: data['email'] as String,
            username: data['username'] as String,
            avatarUrl: data['avatarUrl'] as String,
          );
        });
  }

  Future<String> createRoom({
    required String hostId,
    required String category,
    required List<Question> questions,
    required PlayerInfo hostInfo,
  }) async {
    final roomId = await _getUniqueRoomId();
    final room = Room(
      id: roomId,
      hostId: hostId,
      category: category,
      status: RoomStatus.waiting,
      currentQuestionIndex: 0,
      questions: questions,
      scores: {hostId: 0},
      createdAt: DateTime.now(),
      gameStarted: false,
      players: {hostId: hostInfo},
    );

    await _firestore.collection(_roomsCollection).doc(roomId).set(room.toJson());
    return roomId;
  }

  Future<Room?> getRoom(String roomId) async {
    final doc = await _firestore.collection(_roomsCollection).doc(roomId).get();
    if (!doc.exists) return null;
    return Room.fromJson(doc.data()!);
  }

  Future<Room> joinRoom(String roomId, String userId, PlayerInfo playerInfo) async {
    return _firestore.runTransaction<Room>((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status != RoomStatus.waiting) {
        throw Exception('Oda artık katılıma açık değil');
      }
      if (room.isFull) {
        throw Exception('Oda dolu');
      }

      final updatedRoom = room.copyWith(
        guestId: userId,
        players: {...room.players, userId: playerInfo},
      );

      transaction.update(roomRef, updatedRoom.toJson());
      return updatedRoom;
    });
  }

  Stream<Room?> watchRoom(String roomId) {
    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data()!;
          return Room.fromJson(data);
        });
  }

  Future<void> submitAnswer(
    String roomId,
    String userId,
    int questionIndex,
    String selectedOption,
    bool isCorrect,
    int responseTime,
    int score,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status != RoomStatus.playing) {
        throw Exception('Oyun devam etmiyor');
      }

      // Store answer details
      final answerRef = roomRef.collection('answers').doc('${userId}_$questionIndex');
      transaction.set(answerRef, {
        'userId': userId,
        'questionIndex': questionIndex,
        'selectedOption': selectedOption,
        'isCorrect': isCorrect,
        'responseTime': responseTime,
        'score': score,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update player's score
      final currentScore = room.scores[userId] ?? 0;
      final newScore = currentScore + score;

      final updatedRoom = room.copyWith(
        scores: {...room.scores, userId: newScore},
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Future<void> endGame(String roomId) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status != RoomStatus.playing) {
        throw Exception('Oyun devam etmiyor');
      }

      final updatedRoom = room.copyWith(
        status: RoomStatus.finished,
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Future<void> moveToNextQuestion(String roomId) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status != RoomStatus.playing) {
        throw Exception('Oyun devam etmiyor');
      }

      final nextQuestionIndex = room.currentQuestionIndex + 1;
      final isLastQuestion = nextQuestionIndex >= room.questions.length;

      final updatedRoom = room.copyWith(
        currentQuestionIndex: nextQuestionIndex,
        status: isLastQuestion ? RoomStatus.finished : RoomStatus.playing,
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Future<void> cancelRoom(String roomId) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status == RoomStatus.finished) {
        throw Exception('Oyun zaten bitmiş');
      }

      final updatedRoom = room.copyWith(status: RoomStatus.cancelled);
      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Stream<List<Room>> getActiveRooms() {
    return _firestore
        .collection(_roomsCollection)
        .where('status', isEqualTo: RoomStatus.waiting.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());
  }

  Stream<List<Room>> getUserActiveRooms(String userId) {
    final statusValues = [
      RoomStatus.waiting.toString().split('.').last,
      RoomStatus.playing.toString().split('.').last,
    ];

    final hostRoomsStream = _firestore
        .collection(_roomsCollection)
        .where('status', whereIn: statusValues)
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());

    final guestRoomsStream = _firestore
        .collection(_roomsCollection)
        .where('status', whereIn: statusValues)
        .where('guestId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());

    return Rx.combineLatest2(
      hostRoomsStream,
      guestRoomsStream,
      (List<Room> hostRooms, List<Room> guestRooms) => [...hostRooms, ...guestRooms],
    );
  }

  Future<void> saveUser(UserModel user) async {
    await _firestore.collection(_usersCollection).doc(user.uid).set(user.toJson());
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    return doc.exists ? UserModel.fromJson(doc.data()!) : null;
  }

  Future<void> updateUserScore(String userId, int score) async {
    await _firestore.collection(_usersCollection).doc(userId).update({
      'score': FieldValue.increment(score),
    });
  }

  Future<void> startGame(String roomId) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (!room.canStartGame) {
        throw Exception('Oyun başlatılamaz');
      }

      final updatedRoom = room.copyWith(
        gameStarted: true,
        status: RoomStatus.playing,
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Future<void> updatePlayerReady(String roomId, String userId, bool isReady) async {
    await _firestore.runTransaction((transaction) async {
      final roomRef = _firestore.collection(_roomsCollection).doc(roomId);
      final doc = await transaction.get(roomRef);
      
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      final playerInfo = room.players[userId];
      if (playerInfo == null) throw Exception('Oyuncu bulunamadı');

      final updatedPlayerInfo = playerInfo.copyWith(isReady: isReady);
      final updatedRoom = room.copyWith(
        players: {...room.players, userId: updatedPlayerInfo},
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }
} 