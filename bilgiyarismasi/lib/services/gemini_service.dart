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
You are a quiz question generator. Generate $count multiple choice questions about $category.
Your response must be ONLY a JSON array with this exact format, no other text:
[
  {
    "text": "Question text",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": "Correct option",
    "category": "$category"
  }
]

Remember: Return ONLY the JSON array, no explanations, no markdown formatting, no additional text.
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
