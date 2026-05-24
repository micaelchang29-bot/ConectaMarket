import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_chat_interface.dart';

class ClaudeService implements AiChatService {
  static const String _apiKey = String.fromEnvironment('CLAUDE_API_KEY');
  static const String _model = 'claude-haiku-4-5-20251001';

  @override
  Future<String> ask(String question, String context) async {
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system':
            'Eres un asistente experto en gestión de inventario para pequeñas bodegas peruanas. '
            'Responde en español de forma concisa y práctica. '
            'Basa tus respuestas únicamente en el contexto de inventario proporcionado.',
        'messages': [
          {
            'role': 'user',
            'content': 'Contexto del inventario:\n$context\n\nPregunta: $question',
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['content'][0]['text'] as String;
    }
    throw Exception('Claude error ${response.statusCode}: ${response.body}');
  }
}
