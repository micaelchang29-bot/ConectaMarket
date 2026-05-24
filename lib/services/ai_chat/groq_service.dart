import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_chat_interface.dart';

class GroqService implements AiChatService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _model = 'llama-3.3-70b-versatile';

  @override
  Future<String> ask(String question, String context) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un asistente experto en gestión de inventario para pequeñas bodegas peruanas. '
                'Responde en español de forma concisa y práctica. '
                'Basa tus respuestas únicamente en el contexto de inventario proporcionado.\n\n'
                'Contexto del inventario:\n$context',
          },
          {
            'role': 'user',
            'content': question,
          },
        ],
        'temperature': 0.7,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq error ${response.statusCode}: ${response.body}');
  }
}
