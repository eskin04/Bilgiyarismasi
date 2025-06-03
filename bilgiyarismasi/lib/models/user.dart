import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String avatarUrl;
  final int singleScore;
  final int onlineScore;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.avatarUrl,
    this.singleScore = 0,
    this.onlineScore = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String,
      singleScore: json['single_score'] ?? 0,
      onlineScore: json['online_score'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
      'single_score': singleScore,
      'online_score': onlineScore,
    };
  }

  factory UserModel.fromFirebaseUser(User user, {required String username, required String avatarUrl}) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      username: username,
      avatarUrl: avatarUrl,
      singleScore: 0,
      onlineScore: 0,
    );
  }
} 