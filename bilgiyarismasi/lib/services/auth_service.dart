import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'dart:developer' as developer;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcıyı getir
  User? get currentUser => _auth.currentUser;

  // Kullanıcı durumu değişikliklerini dinle
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Kayıt ol
  Future<UserModel> register({
    required String email,
    required String password,
    required String username,
    required String avatarUrl,
  }) async {
    try {
      developer.log('Firebase Auth ile kullanıcı oluşturuluyor...');
      
      // 1. Firebase Auth ile kullanıcı oluştur
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Kullanıcı oluşturulamadı');
      }

      developer.log('Firebase Auth kullanıcısı oluşturuldu: ${userCredential.user!.uid}');

      // 2. UserModel oluştur
      final userModel = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        username: username,
        avatarUrl: avatarUrl,
      );

      // 3. Firestore'a kullanıcı bilgilerini kaydet
      final userData = userModel.toJson();
      userData['createdAt'] = FieldValue.serverTimestamp();

      developer.log('Firestore\'a kullanıcı bilgileri kaydediliyor...');
      developer.log('Kullanıcı verileri: $userData');

      try {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);

        developer.log('Firestore\'a kullanıcı bilgileri başarıyla kaydedildi');
        return userModel;
      } catch (e) {
        developer.log('Firestore kayıt hatası: $e');
        // Firestore kayıt hatası durumunda Auth'dan kullanıcıyı sil
        await userCredential.user!.delete();
        throw Exception('Kullanıcı bilgileri kaydedilemedi: $e');
      }
    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth hatası: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Bu e-posta adresi zaten kullanımda';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi';
          break;
        case 'weak-password':
          errorMessage = 'Şifre çok zayıf';
          break;
        default:
          errorMessage = e.message ?? 'Bir hata oluştu';
      }
      throw Exception(errorMessage);
    } catch (e) {
      developer.log('Genel hata: $e');
      throw Exception('Kayıt işlemi sırasında bir hata oluştu: $e');
    }
  }

  // Giriş yap
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Giriş yapılamadı');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }

      return UserModel.fromJson(userDoc.data()!);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
          break;
        case 'wrong-password':
          errorMessage = 'Hatalı şifre';
          break;
        case 'invalid-email':
          errorMessage = 'Geçersiz e-posta adresi';
          break;
        default:
          errorMessage = e.message ?? 'Bir hata oluştu';
      }
      throw Exception(errorMessage);
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Çıkış yapılırken bir hata oluştu');
    }
  }

  // Kullanıcı bilgilerini getir
  Future<UserModel?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      return UserModel.fromJson(userDoc.data()!);
    } catch (e) {
      return null;
    }
  }

  // Kullanıcı bilgilerini dinle
  Stream<UserModel?> getUserDataStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserModel.fromJson(doc.data()!);
        });
  }

  // Avatar güncelle
  Future<void> updateUserAvatar(String avatarUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'avatarUrl': avatarUrl});
    } catch (e) {
      throw Exception('Avatar güncellenirken bir hata oluştu: $e');
    }
  }
} 