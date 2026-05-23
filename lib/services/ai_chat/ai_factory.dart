import 'ai_chat_interface.dart';
// import 'claude_service.dart'; // Descomentar para usar Claude
import 'gemini_service.dart';

class AiChatFactory {
  static AiChatService create() {
    // return ClaudeService(); // Claude Haiku — pegar API key en claude_service.dart y descomentar esta línea
    return GeminiService(); // Gemini Flash (activo)
  }
}
