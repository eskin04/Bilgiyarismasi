import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/question.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
  }

  Future<Question> generateQuestion(String category) async {
    final prompt = '''
    Türkçe olarak $category kategorisinde çoktan seçmeli bir soru oluştur.
    Yanıt aşağıdaki JSON formatında olmalı:
    {
      "question": "Soru metni",
      "options": ["A şıkkı", "B şıkkı", "C şıkkı", "D şıkkı"],
      "correctAnswer": "Doğru şık",
      "category": "$category"
    }
    Soru zorlayıcı ama adil olmalı, şıklar net ve anlaşılır olmalı.
    Sadece JSON nesnesini döndür, başka bir şey ekleme. Markdown formatı veya kod blokları kullanma.
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '{}';
      
      developer.log('Gemini API Response: $responseText');
      
      // Markdown formatını temizle
      String cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      // JSON string'i parse et
      final Map<String, dynamic> jsonResponse = json.decode(cleanJson);
      
      return Question.fromJson(jsonResponse);
    } catch (e) {
      developer.log('Error in generateQuestion: $e');
      throw Exception('Failed to generate question: $e');
    }
  }
}
