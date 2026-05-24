import 'ai_chat_interface.dart';
// import 'claude_service.dart';
// import 'gemini_service.dart';
import 'groq_service.dart';

class AiChatFactory {
  static AiChatService create() {
    // return ClaudeService();
    // return GeminiService();
    return GroqService(); // Groq — llama-3.3-70b-versatile
  }
}
