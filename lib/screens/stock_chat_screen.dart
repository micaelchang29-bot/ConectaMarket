import 'package:flutter/material.dart';
import '../services/ai_chat/ai_factory.dart';
import '../services/dashboard_service.dart';

class StockChatScreen extends StatefulWidget {
  const StockChatScreen({super.key});

  @override
  State<StockChatScreen> createState() => _StockChatScreenState();
}

class _StockChatScreenState extends State<StockChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_Message> _history = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _buildContext() async {
    final service = DashboardAiService();
    final alerts = await service.getLowStockAlerts();
    final providers = await service.getProviderRanking();

    final buffer = StringBuffer();

    buffer.writeln('=== ALERTAS DE STOCK ===');
    if (alerts.isEmpty) {
      buffer.writeln('Todos los productos tienen stock saludable.');
    } else {
      for (final p in alerts) {
        buffer.writeln(
          '- ${p['nombre'] ?? '?'}: stock=${p['stock'] ?? 0}, '
          'umbral=${p['umbralAlerta'] ?? 0}, '
          'estado=${p['estadoStock'] ?? '?'}, '
          'faltan=${p['unidadesFaltantes'] ?? 0} unidades',
        );
      }
    }

    buffer.writeln('');
    buffer.writeln('=== RANKING DE PROVEEDORES ===');
    if (providers.isEmpty) {
      buffer.writeln('No hay historial de proveedores registrado.');
    } else {
      for (int i = 0; i < providers.length && i < 5; i++) {
        final p = providers[i];
        buffer.writeln(
          '${i + 1}. ${p['nombre'] ?? '?'}: score=${p['global_score'] ?? 0}/100, '
          'compras=${p['num_compras'] ?? 0}, '
          'recomendación=${p['recommendation'] ?? '?'}',
        );
      }
    }

    return buffer.toString();
  }

  Future<void> _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _history.add(_Message(role: _Role.user, text: question));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final context = await _buildContext();
      final answer = await AiChatFactory.create().ask(question, context);
      setState(() {
        _history.add(_Message(role: _Role.assistant, text: answer));
      });
    } catch (e) {
      setState(() {
        _history.add(_Message(
          role: _Role.assistant,
          text: 'Error al consultar la IA: ${e.toString()}',
          isError: true,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005440)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.psychology_outlined, color: Color(0xFF0F6E56), size: 22),
            SizedBox(width: 8),
            Text(
              'Consulta de Stock IA',
              style: TextStyle(
                color: Color(0xFF005440),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _history.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _history.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _history.length) {
                        return _buildLoadingBubble();
                      }
                      return _buildMessageBubble(_history[index]);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_outlined, color: Color(0xFF0F6E56), size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pregúntale a la IA sobre tu stock',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ejemplo: "¿Qué productos debo reabastecer urgente?" o "¿Cuál es mi mejor proveedor?"',
              style: TextStyle(fontSize: 13, color: Color(0xFF3F4944)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    final isUser = msg.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0F6E56),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0F6E56)
                    : msg.isError
                        ? const Color(0xFFFFEBEE)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? const Color(0xFFEF9A9A)
                            : const Color(0xFFE1E3E4),
                      ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? const Color(0xFFBA1A1A)
                          : const Color(0xFF191C1D),
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF0F6E56),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFE1E3E4)),
            ),
            child: const SizedBox(
              width: 36,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F6E56)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E3E4))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Escribe tu pregunta...',
                  hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE1E3E4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE1E3E4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF0F6E56), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _sendQuestion(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _isLoading ? const Color(0xFFBEC9C3) : const Color(0xFF0F6E56),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isLoading ? null : _sendQuestion,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Role { user, assistant }

class _Message {
  final _Role role;
  final String text;
  final bool isError;

  const _Message({required this.role, required this.text, this.isError = false});
}
