import 'package:bilgiyarismasi/screens/category_stats_screen.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class CategorySummaryScreen extends StatelessWidget {
  const CategorySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kategori İstatistikleri'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService().getAllCategoryStats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          if (stats.isEmpty) {
            return const Center(child: Text('Hiç kategori istatistiği yok.'));
          }

          // En çok oynanan kategori
          final mostPlayed = stats.reduce(
            (a, b) => (a['totalPlays'] ?? 0) > (b['totalPlays'] ?? 0) ? a : b,
          );
          // Başarı oranı en yüksek kategori (en az 10 oyun oynanmış olanlar arasında)
          final bestSuccess =
              (stats
                      .where(
                        (cat) =>
                            (cat['totalCorrect'] + cat['totalWrong']) >= 10,
                      )
                      .toList()
                    ..sort((a, b) {
                      double aRate = _successRate(a);
                      double bRate = _successRate(b);
                      return bRate.compareTo(aRate);
                    }))
                  .first;
          // En yüksek toplam puanlı kategori
          final highestScore = stats.reduce(
            (a, b) => (a['totalScore'] ?? 0) > (b['totalScore'] ?? 0) ? a : b,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatCard(
                  title: 'En Çok Oynanan Kategori',
                  value: mostPlayed['category'],
                  icon: Icons.local_fire_department,
                  color: Colors.deepOrange,
                  subtitle: 'Toplam Oyun: ${mostPlayed['totalPlays'] ?? 0}',
                ),
                const SizedBox(height: 18),
                _StatCard(
                  title: 'Başarı Oranı En Yüksek Kategori',
                  value: bestSuccess['category'],
                  icon: Icons.emoji_events,
                  color: Colors.green,
                  subtitle:
                      'Başarı Oranı: %${_successRate(bestSuccess).toStringAsFixed(1)}',
                ),
                const SizedBox(height: 18),
                _StatCard(
                  title: 'En Yüksek Skorlu Kategori',
                  value: highestScore['category'],
                  icon: Icons.star,
                  color: Colors.amber[800]!,
                  subtitle: 'Toplam Skor: ${highestScore['totalScore'] ?? 0}',
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryStatsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.category),
                  label: const Text(
                    'Tüm Kategorileri Gör',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static double _successRate(Map<String, dynamic> cat) {
    final total = (cat['totalCorrect'] ?? 0) + (cat['totalWrong'] ?? 0);
    if (total == 0) return 0;
    return ((cat['totalCorrect'] ?? 0) / total) * 100;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryMiniCard extends StatelessWidget {
  final Map<String, dynamic> cat;
  const _CategoryMiniCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    final rate = CategorySummaryScreen._successRate(cat);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.category,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cat['category'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            'Oyun: ${cat['totalPlays'] ?? 0}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(width: 10),
          Text(
            'Başarı: %${rate.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 13, color: Colors.green),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoryStatsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: const Text('Detaylar'),
          ),
        ],
      ),
    );
  }
}
