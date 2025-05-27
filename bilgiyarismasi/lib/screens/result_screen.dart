import 'package:flutter/material.dart';
import '../models/room.dart';
import '../services/auth_service.dart';

class ResultScreen extends StatelessWidget {
  final Room room;
  final AuthService _authService = AuthService();

  ResultScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid;
    final isHost = currentUserId == room.hostId;
    final opponentId = isHost ? room.guestId : room.hostId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyun Sonucu'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPlayerScore(
                  'Siz',
                  room.scores[currentUserId] ?? 0,
                  isHost ? room.hostScore : room.guestScore,
                ),
                _buildPlayerScore(
                  'Rakip',
                  room.scores[opponentId] ?? 0,
                  isHost ? room.guestScore : room.hostScore,
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Result message
            Text(
              _getResultMessage(
                room.scores[currentUserId] ?? 0,
                room.scores[opponentId] ?? 0,
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Play again button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Ana Menüye Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerScore(String label, int score, int totalScore) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Puan: $score',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getResultMessage(int playerScore, int opponentScore) {
    if (playerScore > opponentScore) {
      return 'Tebrikler! Kazandınız!';
    } else if (playerScore < opponentScore) {
      return 'Maalesef kaybettiniz.';
    } else {
      return 'Berabere!';
    }
  }
} 