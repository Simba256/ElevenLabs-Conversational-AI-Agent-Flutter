import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

enum ConversationMode {
  call, // Voice + text input, audio output
  textOnly, // Text input only, text output only
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ElevenLabsService with ChangeNotifier {
  static const String agentId = 'agent_8701k4dytec6e43ar0ms2v7ryn9e';
  bool _conversationReady = false;
  final List<String> _pendingMessages = [];
  
  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<ChatMessage> _messages = [];
  String? _error;
  
  // User credentials and context
  String _userName = '';
  String _authToken = '';
  String _userContext = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  
  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _audioStateSubscription;
  
  // Conversation mode
  ConversationMode _conversationMode = ConversationMode.call; // Default to call mode
  ConversationMode get conversationMode => _conversationMode;

  // Speech recognition (Cross-platform)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechSupported = false;
  bool _voiceCallMode = true; // Always enabled
  bool _isPlayingAudio = false;
  bool _waitingForUserInput = false;
  bool _messageSent = false; // Track if current speech message was already sent
  String _lastRecognizedText = ''; // Track the last partial result as fallback
  
  // Getters
  ConnectionStatus get status => _status;
  bool get isListening => _isListening;
  bool get voiceCallMode => _voiceCallMode;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String? get error => _error;
  String get userName => _userName;
  String get authToken => _authToken;
  String get userContext => _userContext;
  double get latitude => _latitude;
  double get longitude => _longitude;
  
  // Setters
  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }
  
  void setAuthToken(String token) {
    _authToken = token;
    notifyListeners();
  }
  
  void setUserContext(String context) {
    _userContext = context;
    notifyListeners();
  }
  
  void setLocation(double latitude, double longitude) {
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }
  
  void setConversationMode(ConversationMode mode) {
    _conversationMode = mode;
    
    // Reset speech-related flags when changing mode
    if (mode == ConversationMode.textOnly) {
      _speechSupported = false;
      _isListening = false;
      _voiceCallMode = false; // Disable voice in text-only mode
      _waitingForUserInput = false;
      _messageSent = false;
      _isPlayingAudio = false;
      
      // Stop any ongoing speech recognition
      if (_speech.isListening) {
        _speech.stop();
      }
      
      // Stop any ongoing audio playback
      _audioPlayer.stop();
      
    } else {
      _voiceCallMode = true; // Enable voice in call mode
    }
    
    print('🔧 Conversation mode set to: ${mode == ConversationMode.call ? 'Call' : 'Text-Only'}');
    notifyListeners();
  }
  
  
  // Check if ready to connect (only require essential fields)
  bool get canConnect => _userName.isNotEmpty && _authToken.isNotEmpty;
  
  // Connect to ElevenLabs WebSocket
  Future<void> connect() async {
    if (!canConnect) {
      _setError('Please provide both name and auth token');
      return;
    }
    
    if (_status == ConnectionStatus.connected || _status == ConnectionStatus.connecting) {
      dev.log('Already connected or connecting');
      return;
    }
    
    try {
      _setStatus(ConnectionStatus.connecting);
      _clearError();
      
      // Create WebSocket connection URL
      final wsUrl = 'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=$agentId';
      
      print('🔗 Connecting to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
          // Send conversation initiation data (ElevenLabs protocol)
      final initMessage = {
        'type': 'conversation_initiation_client_data',
        'dynamic_variables': {
          'secret__auth_token': _authToken,
          'user_name': _userName,
          'user_context': _userContext,
          'current_date_time': DateTime.now().toIso8601String(),
          'latitude': _latitude.toString(),
          'longitude': _longitude.toString(),
        }
      };
      
      // Add text-only override if in text-only mode
      if (_conversationMode == ConversationMode.textOnly) {
        initMessage['conversation_config_override'] = {
          'output_format': 'text_only',
          'voice_enabled': false,
          'audio_enabled': false,
        };
        print('📝 Adding text-only override to conversation initialization');
      }
      
      print('📤 Sending initiation event: ${jsonEncode(initMessage)}');
      _channel!.sink.add(jsonEncode(initMessage));
      
      // Listen to messages
      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) => _handleError(error),
        onDone: () => _handleDisconnection(),
      );
      
      _setStatus(ConnectionStatus.connected);
      dev.log('✅ Connected successfully');
      
    } catch (e) {
      dev.log('💥 Connection failed: $e');
      _setError('Failed to connect: $e');
      _setStatus(ConnectionStatus.error);
    }
  }
  
  // Send message
  void sendMessage(String message) {
    if (_status != ConnectionStatus.connected || _channel == null) {
      dev.log('❌ Cannot send message - not connected');
      return;
    }
    
    if (message.trim().isEmpty) return;
    
    try {
      // Add user message to chat
      _addMessage(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      
      // Check if conversation is ready
      if (!_conversationReady) {
        dev.log('⏳ Conversation not ready yet - queueing message');
        _pendingMessages.add(message);
        return;
      }
      
      _sendUserMessageNow(message);
      
    } catch (e) {
      dev.log('💥 Failed to send message: $e');
      _setError('Failed to send message: $e');
    }
  }
  
  void _sendUserMessageNow(String text) {
    if (_status != ConnectionStatus.connected || _channel == null) return;
    
    final payload = {
      'type': 'user_message',
      'text': text,
    };
    
    dev.log('📤 Sending message: ${jsonEncode(payload)}');
    _channel!.sink.add(jsonEncode(payload));
  }
  
  // Disconnect
  Future<void> disconnect() async {
    try {
      dev.log('🛑 Disconnecting...');
      await _channel?.sink.close();
      _channel = null;
      _setStatus(ConnectionStatus.disconnected);
      dev.log('✅ Disconnected successfully');
    } catch (e) {
      dev.log('💥 Error during disconnect: $e');
    }
  }
  
  // Clear messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
  
  // Initialize speech recognition (cross-platform)
  Future<bool> initializeSpeech() async {
    // Skip speech initialization in text-only mode
    if (_conversationMode == ConversationMode.textOnly) {
      print('📝 Skipping speech initialization - text-only mode');
      return false;
    }
    
    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        print('💥 Microphone permission denied');
        return false;
      }
      
      // Initialize speech recognition
      _speechSupported = await _speech.initialize(
        onStatus: (status) {
          print('🎤 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _onSpeechEnd();
          }
        },
        onError: (error) {
          print('💥 Speech error: $error');
          _isListening = false;
          notifyListeners();
        },
      );
      
      print('🎤 Speech recognition available: $_speechSupported');
      return _speechSupported;
    } catch (e) {
      print('💥 Speech initialization error: $e');
      return false;
    }
  }
  
  void _onSpeechEnd() {
    print('🎤 Speech recognition ended');
    _isListening = false;
    
    // If we have recognized text but haven't sent a message yet, send the last recognized text as fallback
    if (!_messageSent && _lastRecognizedText.trim().isNotEmpty) {
      print('🎤 Using fallback - sending last recognized text: $_lastRecognizedText');
      _messageSent = true;
      _waitingForUserInput = false;
      notifyListeners();
      sendMessage(_lastRecognizedText);
      return; // Don't restart listening immediately, wait for response
    }
    
    notifyListeners();
    
    // If in voice call mode (not text-only) and waiting for user input, restart listening
    if (_conversationMode == ConversationMode.call && _voiceCallMode && _waitingForUserInput && !_isPlayingAudio) {
      print('🎤 Auto-restarting voice input in call mode...');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_conversationMode == ConversationMode.call && _voiceCallMode && !_isListening && _waitingForUserInput && !_isPlayingAudio) {
          startListening();
        }
      });
    }
  }
  
  // Start listening for voice input
  Future<void> startListening() async {
    if (!_speechSupported || _isListening) return;
    
    try {
      _isListening = true;
      _messageSent = false; // Reset message sent flag for new listening session
      _lastRecognizedText = ''; // Reset last recognized text
      notifyListeners();
      
      await _speech.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords;
          print('🎤 Recognized: $recognizedText (final: ${result.finalResult})');
          
          // Always update the last recognized text for fallback
          _lastRecognizedText = recognizedText;
          
          // Only send if we haven't sent a message for this listening session
          if (!_messageSent && recognizedText.trim().isNotEmpty) {
            if (result.finalResult) {
              // Immediate send for final results - these are the most reliable
              _messageSent = true;
              _isListening = false;
              _waitingForUserInput = false;
              notifyListeners();
              sendMessage(recognizedText);
            }
          }
        },
        listenFor: const Duration(seconds: 10), // Longer listening window
        pauseFor: const Duration(seconds: 4), // Longer pause to capture complete sentences
        partialResults: true, // Keep for debugging and fallback
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        localeId: 'en_US',
      );
      
      print('🎤 Started listening...');
      
    } catch (e) {
      print('💥 Error starting speech recognition: $e');
      _isListening = false;
      _messageSent = false;
      notifyListeners();
    }
  }
  
  // Stop listening for voice input
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
      print('🎤 Stopped listening');
    } catch (e) {
      print('💥 Error stopping speech recognition: $e');
      _isListening = false;
      notifyListeners();
    }
  }
  
  // Private methods
  void _handleMessage(dynamic data) {
    try {
      print('📨 Received: $data');
      
      if (data is String) {
        final Map<String, dynamic> message = jsonDecode(data);
        dev.log('📨 Received message type: ${message['type']}');
        
        switch (message['type']) {
          case 'conversation_initiation_metadata':
            final conversationId = message['conversation_initiation_metadata_event']?['conversation_id'];
            dev.log('🎉 Conversation initialized: $conversationId');
            _conversationReady = true;
            
            // Send any pending messages
            if (_pendingMessages.isNotEmpty) {
              dev.log('📤 Sending pending messages: ${_pendingMessages.length}');
              for (final pendingMsg in _pendingMessages) {
                _sendUserMessageNow(pendingMsg);
              }
              _pendingMessages.clear();
            }
            
            // If in call mode (not text-only) and speech is supported, start listening
            if (_conversationMode == ConversationMode.call && _voiceCallMode && _speechSupported && !_isListening) {
              print('🎤 Starting voice call mode...');
              _waitingForUserInput = true;
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (_conversationMode == ConversationMode.call && _voiceCallMode && !_isListening && _conversationReady && _waitingForUserInput) {
                  startListening();
                }
              });
            } else if (_conversationMode == ConversationMode.textOnly) {
              print('📝 Text-only mode - no voice initialization');
            }
            break;
            
          case 'agent_response':
          case 'agent_text':
          case 'agent_response_text':
          case 'agent_response_event':
          case 'agent_response_text_event':
            final responseText = message['text'] ?? 
                               message['message'] ?? 
                               message['agent_response'] ??
                               message['agent_response_event']?['text'] ??
                               message['agent_response_event']?['agent_response'] ??
                               message['agent_response_text_event']?['text'];
            if (responseText != null) {
              dev.log('🤖 Agent response: $responseText');
              _addMessage(ChatMessage(
                text: responseText,
                isUser: false,
                timestamp: DateTime.now(),
              ));
            }
            break;
            
          case 'user_transcript':
          case 'user_text':
            final transcriptText = message['text'] ?? message['transcript'];
            if (transcriptText != null) {
              dev.log('👤 User transcript: $transcriptText');
            }
            break;
            
          case 'audio':
            final audioB64 = message['audio_event']?['audio_base_64'];
            if (audioB64 != null) {
              if (_conversationMode == ConversationMode.textOnly) {
                print('📝 Skipping audio in text-only mode');
              } else {
                print('🔊 Received audio from agent (length=${audioB64.length})');
                _playAudio(audioB64);
              }
            }
            break;
            
          case 'ping':
            dev.log('🏓 Received ping');
            break;
            
          case 'error':
            dev.log('❌ ElevenLabs error: ${message['message'] ?? message['error']}');
            _setError('ElevenLabs error: ${message['message'] ?? message['error']}');
            break;
            
          default:
            dev.log('❓ Unknown message type: ${message['type']}');
            
            // Check for agent response in unknown message types
            if (message['message'] != null) {
              dev.log('🤖 Found message in unknown type: ${message['message']}');
              _addMessage(ChatMessage(
                text: message['message'],
                isUser: false,
                timestamp: DateTime.now(),
              ));
            }
        }
      }
    } catch (e) {
      dev.log('💥 Error handling message: $e');
      _setError('Error processing message: $e');
    }
  }
  
  void _handleError(dynamic error) {
    dev.log('❌ WebSocket error: $error');
    _setError('Connection error: $error');
    _setStatus(ConnectionStatus.error);
  }
  
  void _handleDisconnection() {
    dev.log('🔴 WebSocket disconnected');
    _setStatus(ConnectionStatus.disconnected);
    _channel = null;
  }
  
  void _addMessage(ChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }
  
  void _setStatus(ConnectionStatus status) {
    _status = status;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Play audio from base64 encoded string
  Future<void> _playAudio(String audioBase64) async {
    // Skip audio playback in text-only mode
    if (_conversationMode == ConversationMode.textOnly) {
      print('📝 Skipping audio playback - text-only mode');
      return;
    }
    
    try {
      print('🔊 Playing audio...');
      _isPlayingAudio = true;
      _waitingForUserInput = false; // Stop waiting while AI is speaking
      
      // Stop listening while AI is speaking
      if (_isListening) {
        await stopListening();
      }
      
      // Cancel previous audio subscription
      await _audioStateSubscription?.cancel();
      
      // Decode base64 to bytes
      final audioBytes = base64Decode(audioBase64);
      print('🔊 Decoded audio bytes length: ${audioBytes.length}');
      
      // Create a data URI for the audio
      // ElevenLabs sends PCM audio, but for web we need to create a WAV header
      final wavBytes = _createWavFromPcm(audioBytes);
      final base64Wav = base64Encode(wavBytes);
      final dataUri = 'data:audio/wav;base64,$base64Wav';
      
      // Play the audio
      await _audioPlayer.setUrl(dataUri);
      await _audioPlayer.play();
      
      print('🔊 Audio started playing');
      
      // Listen for when audio completes (only one listener)
      _audioStateSubscription = _audioPlayer.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          _onAudioCompleted();
        }
      });
      
    } catch (e) {
      print('💥 Error playing audio: $e');
      dev.log('💥 Audio playback error: $e');
      _isPlayingAudio = false;
      _waitingForUserInput = _voiceCallMode; // Reset waiting state
    }
  }
  
  // Called when audio playback completes
  void _onAudioCompleted() {
    _isPlayingAudio = false;
    print('🔊 Audio playback completed');
    
    // If in voice call mode (not text-only), automatically start listening for user response
    if (_conversationMode == ConversationMode.call && _voiceCallMode && _speechSupported && !_isListening) {
      print('🎤 Auto-starting voice input after AI response...');
      _waitingForUserInput = true; // Now waiting for user input
      
      // Add a small delay to avoid picking up the end of the AI audio
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_conversationMode == ConversationMode.call && _voiceCallMode && !_isListening && _waitingForUserInput && !_isPlayingAudio) {
          startListening();
        }
      });
    }
  }
  
  // Create WAV header for PCM data
  Uint8List _createWavFromPcm(Uint8List pcmData) {
    final int sampleRate = 24000; // ElevenLabs default sample rate
    final int bitsPerSample = 16;
    final int channels = 1; // Mono
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final int blockAlign = channels * bitsPerSample ~/ 8;
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    final wavHeader = ByteData(44);
    
    // RIFF header
    wavHeader.setUint8(0, 0x52); // R
    wavHeader.setUint8(1, 0x49); // I
    wavHeader.setUint8(2, 0x46); // F
    wavHeader.setUint8(3, 0x46); // F
    wavHeader.setUint32(4, fileSize, Endian.little); // File size
    wavHeader.setUint8(8, 0x57); // W
    wavHeader.setUint8(9, 0x41); // A
    wavHeader.setUint8(10, 0x56); // V
    wavHeader.setUint8(11, 0x45); // E
    
    // Format chunk
    wavHeader.setUint8(12, 0x66); // f
    wavHeader.setUint8(13, 0x6D); // m
    wavHeader.setUint8(14, 0x74); // t
    wavHeader.setUint8(15, 0x20); // (space)
    wavHeader.setUint32(16, 16, Endian.little); // Format chunk size
    wavHeader.setUint16(20, 1, Endian.little); // Audio format (PCM)
    wavHeader.setUint16(22, channels, Endian.little); // Channels
    wavHeader.setUint32(24, sampleRate, Endian.little); // Sample rate
    wavHeader.setUint32(28, byteRate, Endian.little); // Byte rate
    wavHeader.setUint16(32, blockAlign, Endian.little); // Block align
    wavHeader.setUint16(34, bitsPerSample, Endian.little); // Bits per sample
    
    // Data chunk
    wavHeader.setUint8(36, 0x64); // d
    wavHeader.setUint8(37, 0x61); // a
    wavHeader.setUint8(38, 0x74); // t
    wavHeader.setUint8(39, 0x61); // a
    wavHeader.setUint32(40, dataSize, Endian.little); // Data size
    
    // Combine header and data
    final wavFile = Uint8List(44 + dataSize);
    wavFile.setRange(0, 44, wavHeader.buffer.asUint8List());
    wavFile.setRange(44, 44 + dataSize, pcmData);
    
    return wavFile;
  }
  
  @override
  void dispose() {
    disconnect();
    _audioStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}