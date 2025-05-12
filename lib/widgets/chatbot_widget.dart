import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatbotWidget extends StatefulWidget {
  const ChatbotWidget({super.key});

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Message de bienvenue initial
    _addMessage('Bonjour! Je suis l\'assistant Hotello. Comment puis-je vous aider aujourd\'hui?', false);
  }

  void _addMessage(String message, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(
        content: message,
        isUser: isUser,
      ));
    });
    _scrollToBottom();
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

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();
    _addMessage(text, true);

    setState(() {
      _isTyping = true;
    });

    // Simuler un délai de réponse pour une expérience utilisateur plus naturelle
    await Future.delayed(const Duration(milliseconds: 800));

    // Réponses prédéfinies basées sur les mots-clés
    String botResponse;
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('bonjour') || lowerText.contains('salut') || lowerText.contains('hello')) {
      botResponse = 'Bonjour ! Comment puis-je vous aider avec votre recherche d\'hôtel ?';
    } else if (lowerText.contains('réserv')) {
      botResponse = 'Pour réserver un hôtel, naviguez vers l\'onglet Explore, sélectionnez un hôtel qui vous plaît, puis cliquez sur le bouton Réserver. Vous pourrez ensuite choisir vos dates de séjour.';
    } else if (lowerText.contains('prix') || lowerText.contains('tarif') || lowerText.contains('coût')) {
      botResponse = 'Nos prix varient selon la période et le type de chambre. Vous pouvez consulter tous les tarifs dans la section Explore de l\'application.';
    } else if (lowerText.contains('annul')) {
      botResponse = 'Pour annuler une réservation, rendez-vous dans l\'onglet "Mes Réservations" et utilisez le bouton d\'annulation à côté de la réservation concernée.';
    } else if (lowerText.contains('merci')) {
      botResponse = 'Je vous en prie ! N\'hésitez pas si vous avez d\'autres questions.';
    } else if (lowerText.contains('aide')) {
      botResponse = 'Je peux vous aider à trouver un hôtel, faire une réservation, ou répondre à vos questions concernant nos services. Que souhaitez-vous savoir ?';
    } else if (lowerText.contains('qui') && lowerText.contains('tu')) {
      botResponse = 'Je suis votre assistant Hotello. Je peux vous aider avec les réservations d\'hôtel, les informations sur les chambres, et autres questions liées à votre séjour. Comment puis-je vous aider aujourd\'hui ?';
    } else if (lowerText.contains('chambr')) {
      botResponse = 'Nos chambres sont équipées de tout le confort nécessaire : WiFi, télévision, climatisation, salle de bain privée. Certains établissements proposent également des options supplémentaires comme un mini-bar ou une vue panoramique.';
    } else if (lowerText.contains('wifi') || lowerText.contains('internet')) {
      botResponse = 'Tous nos hôtels proposent une connexion WiFi gratuite et illimitée pour nos clients.';
    } else if (lowerText.contains('petit') && lowerText.contains('déjeuner')) {
      botResponse = 'La plupart de nos hôtels proposent un petit-déjeuner. Vous pouvez vérifier cette option dans la description de l\'hôtel ou lors de votre réservation.';
    } else if (lowerText.contains('contact')) {
      botResponse = 'Vous pouvez contacter notre service client au +212 522 123 456 ou par email à contact@hotello.com';
    } else {
      botResponse = 'Je ne suis pas sûr de comprendre votre demande. Pouvez-vous reformuler ou me demander des informations sur les réservations, les chambres, les prix ou nos services ?';
    }

    _addMessage(botResponse, false);
    
    setState(() {
      _isTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: _messages.length,
            itemBuilder: (_, index) => _buildMessage(_messages[index]),
          ),
        ),
        if (_isTyping)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Assistant écrit...'),
              ],
            ),
          ),
        _buildInputField(),
      ],
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: message.isUser ? 64 : 8,
        right: message.isUser ? 8 : 64,
      ),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.deepPurple.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(message.content),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Tapez votre message...',
                border: InputBorder.none,
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}