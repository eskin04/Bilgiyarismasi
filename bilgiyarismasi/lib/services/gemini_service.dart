import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/question.dart';
import '../models/room.dart';

class GeminiService {
  final GenerativeModel _model;
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  GeminiService()
    : _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
      );

  Future<List<Question>> generateQuestions({
    required String category,
    required int count,
  }) async {
    try {
      final prompt = '''
Sen bir bilgi yarışması soru üreticisisin. Bana $category kategorisinde, $count adet çoktan seçmeli soru üret.

Cevabın sadece aşağıdaki biçimde saf JSON array olmalı, başka hiçbir açıklama veya metin ekleme:

[
  {
    "text": "Soru metni",
    "options": ["A şıkkı", "B şıkkı", "C şıkkı", "D şıkkı"],
    "correctAnswer": "Doğru şık",
    "category": "$category"
  }
]

Gereksinimler:
- Daha önce sorulmuş olabilecek veya klasikleşmiş soruları tekrarlama. Özgün ve yeni sorular üret.
- Sorular Türkçe olmalı.
- Farklı zorluk seviyelerinde (kolay, orta, zor) dengeli dağılımlı olmalı.
- Sorular özgün, yaratıcı ve adil olmalı.
- Cevaplar karışık sıralanmalı.
- Sorular mantıklı, tutarlı ve genel bilgiye dayalı olmalı.

Sadece geçerli JSON array döndür, ekstra bilgi veya markdown kullanma.

''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null) {
        throw Exception('Empty response from Gemini API');
      }

      // Extract JSON array from the response
      String jsonText = responseText.trim();

      // Find the first '[' and last ']'
      final startIndex = jsonText.indexOf('[');
      final endIndex = jsonText.lastIndexOf(']');

      if (startIndex == -1 || endIndex == -1) {
        developer.log('Invalid response: $jsonText');
        throw FormatException('Could not find JSON array in response');
      }

      // Extract just the JSON array
      jsonText = jsonText.substring(startIndex, endIndex + 1);

      // Parse the JSON response
      final List<dynamic> jsonList = json.decode(jsonText);

      // Convert JSON to Question objects
      return jsonList
          .map((json) => Question.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error generating questions: $e');
      throw Exception('Failed to generate questions: $e');
    }
  }
}
