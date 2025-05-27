import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveQuizResult({
    required Question question,
    required String userAnswer,
    required bool isCorrect,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('quiz_results').add({
      'userId': user.uid,
      'question': question.toJson(),
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'timestamp': FieldValue.serverTimestamp(),
    });
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
} 