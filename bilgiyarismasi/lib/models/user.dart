import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String avatarUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
    };
  }

  factory UserModel.fromFirebaseUser(User user, {required String username, required String avatarUrl}) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      avatarUrl: avatarUrl,
    );
  }
} 