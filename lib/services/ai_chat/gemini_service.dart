import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_chat_interface.dart';

class GeminiService implements AiChatService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _model = 'gemini-2.0-flash';

  @override
  Future<String> ask(String question, String context) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Eres un asistente experto en gestión de inventario para pequeñas bodegas peruanas. '
                    'Responde en español de forma concisa y práctica. '
                    'Basa tus respuestas únicamente en el contexto de inventario proporcionado.\n\n'
                    'Contexto del inventario:\n$context\n\nPregunta: $question',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    throw Exception('Gemini error ${response.statusCode}: ${response.body}');
  }
}
