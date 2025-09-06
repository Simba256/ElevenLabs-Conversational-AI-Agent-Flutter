import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/elevenlabs_service.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _speechInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    final service = Provider.of<ElevenLabsService>(context, listen: false);
    // Only initialize speech if in call mode
    if (service.conversationMode == ConversationMode.call) {
      _speechInitialized = await service.initializeSpeech();
    } else {
      _speechInitialized = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    _contextController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Consumer<ElevenLabsService>(
          builder: (context, service, child) {
            final modeText = service.conversationMode == ConversationMode.call 
                ? 'Call Mode' 
                : 'Text-Only Mode';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ElevenLabs Chat',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  modeText,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Consumer<ElevenLabsService>(
        builder: (context, service, child) {
          return Column(
            children: [
              // Connection Status (with padding)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: _buildStatusCard(service),
              ),
              
              // Credentials Input (when not connected)
              if (service.status == ConnectionStatus.disconnected) 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _buildCredentialsCard(service),
                ),
              
              // Chat Messages (full width)
              Expanded(
                child: _buildMessagesList(service),
              ),
              
              // Message Input (when connected) - sticks to bottom
              if (service.status == ConnectionStatus.connected)
                _buildMessageInput(service),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(ElevenLabsService service) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (service.status) {
      case ConnectionStatus.disconnected:
        statusColor = Colors.red;
        statusText = 'Disconnected';
        statusIcon = Icons.offline_bolt;
        break;
      case ConnectionStatus.connecting:
        statusColor = Colors.orange;
        statusText = 'Connecting...';
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.connected:
        statusColor = Colors.green;
        statusText = 'Connected ${service.userName.isNotEmpty ? "as ${service.userName}" : ""}';
        statusIcon = Icons.check_circle;
        break;
      case ConnectionStatus.error:
        statusColor = Colors.red;
        statusText = 'Error';
        statusIcon = Icons.error;
        break;
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (service.error != null)
                    Text(
                      service.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (service.status == ConnectionStatus.connected)
              ElevatedButton(
                onPressed: service.disconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disconnect'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsCard(ElevenLabsService service) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Credentials',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Name input
            TextField(
              controller: _nameController,
              onChanged: service.setUserName,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Your Name',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Enter your name (required)',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Token input
            TextField(
              controller: _tokenController,
              onChanged: service.setAuthToken,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Auth Token',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Enter your secret auth token',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Context input (optional)
            TextField(
              controller: _contextController,
              onChanged: service.setUserContext,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'User Context (optional)',
                labelStyle: TextStyle(color: Colors.grey),
                hintText: 'Enter context about yourself...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Location inputs (optional)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    onChanged: (value) {
                      final lat = double.tryParse(value) ?? 0.0;
                      final lon = double.tryParse(_longitudeController.text) ?? 0.0;
                      service.setLocation(lat, lon);
                    },
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Latitude (optional)',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '0.0',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    onChanged: (value) {
                      final lat = double.tryParse(_latitudeController.text) ?? 0.0;
                      final lon = double.tryParse(value) ?? 0.0;
                      service.setLocation(lat, lon);
                    },
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Longitude (optional)',
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: '0.0',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Connect button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: service.canConnect ? service.connect : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  service.status == ConnectionStatus.connecting
                      ? 'Connecting...'
                      : 'Start Conversation',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ElevenLabsService service) {
    return Card(
      color: Colors.grey[900],
      child: service.messages.isEmpty
          ? const Center(
              child: Text(
                'No messages yet...\nConnect and start chatting!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: service.messages.length,
              itemBuilder: (context, index) {
                final message = service.messages[index];
                return _buildMessageBubble(message);
              },
            ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: message.isUser ? 60 : 16,
          right: message.isUser ? 16 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue[600] : Colors.grey[700],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: message.isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: message.isUser 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isUser ? Icons.person : Icons.smart_toy,
                  color: Colors.white.withOpacity(0.6),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${message.isUser ? "You" : "Agent"} • ${_formatTime(message.timestamp)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ElevenLabsService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          top: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice status indicator (prominent mobile-friendly size) - only in call mode
            if (_speechInitialized && service.conversationMode == ConversationMode.call)
              Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: service.isListening ? Colors.green : Colors.grey[600],
                  shape: BoxShape.circle,
                  boxShadow: service.isListening ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Icon(
                  service.isListening ? Icons.mic : Icons.mic_off,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: service.conversationMode == ConversationMode.call 
                      ? 'Type a message or use voice (always listening)...'
                      : 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
                onSubmitted: (_) => _sendMessage(service),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send button (mobile-optimized)
            Container(
              width: 56,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _sendMessage(service),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  elevation: 4,
                ),
                child: const Icon(Icons.send, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(ElevenLabsService service) {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      service.sendMessage(message);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}