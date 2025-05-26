import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';

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
} 