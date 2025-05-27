import '../models/room.dart';
import '../models/question.dart';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';

class RoomService {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final GeminiService _geminiService = GeminiService();

  // Create a new room
  Future<String> createRoom(String category) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      // Get user info
      final userInfo = await _authService.getUser(userId);
      if (userInfo == null) throw Exception('Kullanıcı bilgileri alınamadı');

      // Generate questions
      final questions = await _geminiService.generateQuestions(
        category: category,
        count: 10,
      );
      
      // Create room using FirestoreService
      return _firestoreService.createRoom(
        hostId: userId,
        category: category,
        questions: questions,
        hostInfo: PlayerInfo(
          username: userInfo.username,
          avatarUrl: userInfo.avatarUrl,
          isReady: false,
        ),
      );
    } catch (e) {
      throw Exception('Oda oluşturulurken bir hata oluştu: $e');
    }
  }

  // Join an existing room
  Future<Room> joinRoom(String roomId) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      // Get user info
      final userInfo = await _authService.getUser(userId);
      if (userInfo == null) throw Exception('Kullanıcı bilgileri alınamadı');

      final room = await _firestoreService.joinRoom(
        roomId,
        userId,
        PlayerInfo(
          username: userInfo.username,
          avatarUrl: userInfo.avatarUrl,
          isReady: false,
        ),
      );

      return room;
    } catch (e) {
      throw Exception('Odaya katılırken bir hata oluştu: $e');
    }
  }

  // Get room by ID
  Future<Room?> getRoom(String roomId) async {
    try {
      return _firestoreService.getRoom(roomId);
    } catch (e) {
      throw Exception('Oda bilgileri alınırken bir hata oluştu: $e');
    }
  }

  // Watch room for real-time updates
  Stream<Room?> watchRoom(String roomId) {
    return _firestoreService.watchRoom(roomId);
  }

  // Submit answer
  Future<void> submitAnswer(
    String roomId,
    int questionIndex,
    String selectedOption,
    bool isCorrect,
    int responseTime,
    int score,
  ) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) throw Exception('Kullanıcı girişi yapılmamış');

      await _firestoreService.submitAnswer(
        roomId,
        userId,
        questionIndex,
        selectedOption,
        isCorrect,
        responseTime,
        score,
      );
    } catch (e) {
      throw Exception('Cevap gönderilirken bir hata oluştu: $e');
    }
  }

  // Move to next question
  Future<void> moveToNextQuestion(String roomId, String userId) async {
    try {
      await _firestoreService.moveToNextQuestion(roomId, userId);
    } catch (e) {
      throw Exception('Sonraki soruya geçilemedi: $e');
    }
  }

  // Cancel room
  Future<void> cancelRoom(String roomId) async {
    try {
      await _firestoreService.cancelRoom(roomId);
    } catch (e) {
      throw Exception('Oda iptal edilirken bir hata oluştu: $e');
    }
  }

  // Get active rooms
  Stream<List<Room>> getActiveRooms() {
    return _firestoreService.getActiveRooms();
  }

  // Get user's active rooms
  Stream<List<Room>> getUserActiveRooms() {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    return _firestoreService.getUserActiveRooms(userId);
  }
}
