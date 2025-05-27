import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import 'package:rxdart/rxdart.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final GeminiService _geminiService = GeminiService();

  // Create a new room
  Future<String> createRoom(String category) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      // Generate questions
      final questions = await _geminiService.generateQuestions(
        category: category,
        count: 10,
      );
      
      // Create room document
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
    } catch (e) {
      throw Exception('Oda oluşturulurken bir hata oluştu: $e');
    }
  }

  // Join an existing room
  Future<Room> joinRoom(String roomId) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      final roomRef = _firestore.collection('rooms').doc(roomId);
      
      return _firestore.runTransaction<Room>((transaction) async {
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
    } catch (e) {
      throw Exception('Odaya katılırken bir hata oluştu: $e');
    }
  }

  // Get room by ID
  Future<Room?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return Room.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Oda bilgileri alınırken bir hata oluştu: $e');
    }
  }

  // Watch room for real-time updates
  Stream<Room?> watchRoom(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.exists ? Room.fromJson(doc.data()!) : null);
  }

  // Submit answer
  Future<void> submitAnswer(String roomId, int questionIndex, String selectedOption) async {
    try {
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
    } catch (e) {
      throw Exception('Cevap gönderilirken bir hata oluştu: $e');
    }
  }

  // Move to next question
  Future<void> moveToNextQuestion(String roomId) async {
    try {
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
    } catch (e) {
      throw Exception('Sonraki soruya geçilirken bir hata oluştu: $e');
    }
  }

  // Cancel room
  Future<void> cancelRoom(String roomId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(roomRef);
        if (!doc.exists) throw Exception('Oda bulunamadı');

        final room = Room.fromJson(doc.data()!);
        if (room.status == RoomStatus.finished) {
          throw Exception('Oyun zaten bitmiş');
        }

        final updatedRoom = room.copyWith(
          status: RoomStatus.cancelled,
        );

        transaction.update(roomRef, updatedRoom.toJson());
      });
    } catch (e) {
      throw Exception('Oda iptal edilirken bir hata oluştu: $e');
    }
  }

  // Get active rooms
  Stream<List<Room>> getActiveRooms() {
    return _firestore
        .collection('rooms')
        .where('status', isEqualTo: RoomStatus.waiting.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());
  }

  // Get user's active rooms
  Stream<List<Room>> getUserActiveRooms() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final statusValues = [
      RoomStatus.waiting.toString().split('.').last,
      RoomStatus.playing.toString().split('.').last,
    ];

    // Get rooms where user is host
    final hostRoomsStream = _firestore
        .collection('rooms')
        .where('status', whereIn: statusValues)
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());

    // Get rooms where user is guest
    final guestRoomsStream = _firestore
        .collection('rooms')
        .where('status', whereIn: statusValues)
        .where('guestId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Room.fromJson(doc.data()))
            .toList());

    // Combine both streams
    return Rx.combineLatest2(
      hostRoomsStream,
      guestRoomsStream,
      (List<Room> hostRooms, List<Room> guestRooms) => [...hostRooms, ...guestRooms],
    );
  }
} 