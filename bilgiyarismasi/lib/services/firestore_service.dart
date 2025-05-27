import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';
import '../models/user.dart';
import '../models/room.dart';
import 'dart:developer' as developer;
import '../services/auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

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
    required String category,
    required List<Question> questions,
  }) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final roomRef = _firestore.collection('rooms').doc();
    final now = DateTime.now();

    final room = Room(
      id: roomRef.id,
      hostId: userId,
      category: category,
      status: RoomStatus.waiting,
      currentQuestionIndex: 0,
      questions: questions,
      scores: {userId: 0},
      createdAt: now,
    );

    await roomRef.set(room.toJson());
    return roomRef.id;
  }

  Future<Room?> getRoom(String roomId) async {
    final doc = await _firestore.collection('rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return Room.fromJson(doc.data()!);
  }

  Future<Room?> joinRoom(String roomId) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    return _firestore.runTransaction<Room?>((transaction) async {
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
        status: RoomStatus.playing,
        scores: {...room.scores, userId: 0},
      );

      transaction.update(roomRef, updatedRoom.toJson());
      return updatedRoom;
    });
  }

  Stream<Room?> watchRoom(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.exists ? Room.fromJson(doc.data()!) : null);
  }

  Future<void> submitAnswer(
    String roomId,
    int questionIndex,
    String selectedOption,
  ) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(roomRef);
      if (!doc.exists) throw Exception('Oda bulunamadı');

      final room = Room.fromJson(doc.data()!);
      if (room.status != RoomStatus.playing) {
        throw Exception('Oyun devam etmiyor');
      }

      final currentQuestion = room.questions[questionIndex];
      final isCorrect = selectedOption == currentQuestion.correctAnswer;
      final currentScore = room.scores[userId] ?? 0;
      final newScore = isCorrect ? currentScore + 1 : currentScore;

      final updatedRoom = room.copyWith(
        scores: {...room.scores, userId: newScore},
      );

      transaction.update(roomRef, updatedRoom.toJson());
    });
  }

  Future<void> moveToNextQuestion(String roomId) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    await _firestore.runTransaction((transaction) async {
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
} 