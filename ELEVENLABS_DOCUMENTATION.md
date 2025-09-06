# ElevenLabs Conversational AI Integration Documentation

## Overview
This document provides a comprehensive reference for the ElevenLabs Conversational AI integration in our Flutter web application, covering configuration, communication protocols, settings, and implementation details.

---

## Table of Contents
1. [Agent Configuration](#agent-configuration)
2. [Connection Settings](#connection-settings)
3. [WebSocket Communication Protocol](#websocket-communication-protocol)
4. [Message Types & Parsing](#message-types--parsing)
5. [Conversation Modes](#conversation-modes)
6. [Code Structure & Files](#code-structure--files)
7. [Audio Processing](#audio-processing)
8. [Speech Recognition](#speech-recognition)
9. [Error Handling](#error-handling)
10. [UI Components](#ui-components)
11. [Testing & Debug](#testing--debug)

---

## Agent Configuration

### Basic Agent Settings
- **Agent ID**: `agent_8701k4dytec6e43ar0ms2v7ryn9e`
- **API Endpoint**: `wss://api.elevenlabs.io/v1/convai/conversation`
- **Connection Type**: WebSocket
- **Authentication**: Token-based via dynamic variables

### Dynamic Variables
Variables sent during conversation initialization:
```dart
'dynamic_variables': {
  'secret__auth_token': _authToken,    // JWT authentication token 
  'user_name': _userName,              // User's display name 
  'user_context': _userContext,        // Additional context about user from database field additional_context
  'current_date_time': DateTime.now().toIso8601String(), // Timestamp
  'latitude': _latitude.toString(),    // User's latitude 
  'longitude': _longitude.toString(),  // User's longitude
}
```

### Security Settings
- **Agent Override Configuration**: Enabled in ElevenLabs dashboard
- **Text-Only Mode**: Supported via `conversation_config_override`
- **CORS**: Handled through WebSocket connections (bypasses typical CORS restrictions)

---

## Connection Settings

### WebSocket Configuration
**File**: `lib/services/elevenlabs_service.dart:103-137`

```dart
// Create WebSocket connection URL
final wsUrl = 'wss://api.elevenlabs.io/v1/convai/conversation?agent_id=$agentId';

// Connection setup
_channel = WebSocketChannel.connect(Uri.parse(wsUrl));

// Message listener
_channel!.stream.listen(
  (data) => _handleMessage(data),
  onError: (error) => _handleError(error),
  onDone: () => _handleDisconnection(),
);
```

### Connection States
**File**: `lib/services/elevenlabs_service.dart:12`
```dart
enum ConnectionStatus { 
  disconnected, 
  connecting, 
  connected, 
  error 
}
```

### Reconnection Strategy
- Manual reconnection via `connect()` method
- Automatic disconnection handling via `_handleDisconnection()`
- Error state management with user feedback

---

## WebSocket Communication Protocol

### 1. Conversation Initialization
**Message Type**: `conversation_initiation_client_data`
**File**: `lib/services/elevenlabs_service.dart:127-149`

```dart
final initMessage = {
  'type': 'conversation_initiation_client_data',
  'dynamic_variables': {
    'secret__auth_token': _authToken,
    'user_name': _userName,
    'name_of_user': _userName,
    'current_date_time': DateTime.now().toIso8601String(),
  }
};

// Text-only mode override
if (_conversationMode == ConversationMode.textOnly) {
  initMessage['conversation_config_override'] = {
    'output_format': 'text_only',
    'voice_enabled': false,
    'audio_enabled': false,
  };
}
```

### 2. User Message Sending
**Message Type**: `user_message`
**File**: `lib/services/elevenlabs_service.dart:174-181`

```dart
final payload = {
  'type': 'user_message',
  'text': text,
};
_channel!.sink.add(jsonEncode(payload));
```

### 3. Message Queue System
**File**: `lib/services/elevenlabs_service.dart:157-163`
- Pending messages are queued until conversation is ready
- Messages sent automatically once `conversation_initiation_metadata` is received

---

## Message Types & Parsing

### Incoming Message Handler
**File**: `lib/services/elevenlabs_service.dart:365-466`

### 1. Conversation Metadata
```json
{
  "conversation_initiation_metadata_event": {
    "conversation_id": "conv_xxx",
    "agent_output_audio_format": "pcm_16000",
    "user_input_audio_format": "pcm_16000"
  },
  "type": "conversation_initiation_metadata"
}
```

### 2. Agent Text Responses
**Parsing Logic**: `lib/services/elevenlabs_service.dart:414-428`
```dart
case 'agent_response':
case 'agent_response_event':
  final responseText = message['text'] ?? 
                     message['message'] ?? 
                     message['agent_response'] ??
                     message['agent_response_event']?['text'] ??
                     message['agent_response_event']?['agent_response'];
```

**Response Format**:
```json
{
  "agent_response_event": {
    "agent_response": "Hello! I'm here to help you stay healthy and happy.\nBasim"
  },
  "type": "agent_response"
}
```

### 3. Audio Data
```json
{
  "audio_event": {
    "audio_base_64": "[base64_encoded_pcm_audio]"
  },
  "type": "audio"
}
```

### 4. User Transcripts
```json
{
  "text": "transcribed_user_speech",
  "type": "user_transcript"
}
```

### 5. Ping Messages
```json
{
  "ping_event": {
    "event_id": 2,
    "ping_ms": null
  },
  "type": "ping"
}
```

---

## Conversation Modes

### Mode Enumeration
**File**: `lib/services/elevenlabs_service.dart:14-17`
```dart
enum ConversationMode {
  call,      // Voice + text input, audio output
  textOnly,  // Text input only, text output only
}
```

### Mode Selection Screen
**File**: `lib/screens/mode_selection_screen.dart`
- **Call Mode**: Green button, enables voice recognition and audio playback
- **Text-Only Mode**: Blue button, disables all audio features

### Mode Configuration Logic
**File**: `lib/services/elevenlabs_service.dart:83-109`

#### Text-Only Mode Settings:
```dart
if (mode == ConversationMode.textOnly) {
  _speechSupported = false;
  _isListening = false;
  _voiceCallMode = false;
  _waitingForUserInput = false;
  _messageSent = false;
  _isPlayingAudio = false;
  
  // Stop any ongoing audio/speech
  if (_speech.isListening) _speech.stop();
  _audioPlayer.stop();
}
```

---

## Code Structure & Files

### 1. Main Application Entry
**File**: `lib/main.dart`
- Sets up Provider for state management
- Initializes with `ModeSelectionScreen`

### 2. ElevenLabs Service (Core Logic)
**File**: `lib/services/elevenlabs_service.dart`
- **Lines 31-98**: Class properties and getters
- **Lines 102-150**: Connection management
- **Lines 152-201**: Message sending
- **Lines 203-245**: Speech recognition initialization
- **Lines 365-466**: WebSocket message handling
- **Lines 505-623**: Audio processing and playback

### 3. Mode Selection Screen
**File**: `lib/screens/mode_selection_screen.dart`
- **Lines 44-68**: Mode selection buttons
- **Lines 76-97**: Mode selection logic with service reset

### 4. Conversation Screen
**File**: `lib/screens/conversation_screen.dart`
- **Lines 61-84**: Dynamic app bar showing current mode
- **Lines 167-251**: Credentials input form
- **Lines 344-430**: Message input with conditional voice indicator
- **Lines 277-342**: Message bubble rendering

---

## Audio Processing

### 1. PCM to WAV Conversion
**File**: `lib/services/elevenlabs_service.dart:571-622`
```dart
Uint8List _createWavFromPcm(Uint8List pcmData) {
  final int sampleRate = 24000; // ElevenLabs default
  final int bitsPerSample = 16;
  final int channels = 1; // Mono
  // ... WAV header creation
}
```

### 2. Audio Playback
**File**: `lib/services/elevenlabs_service.dart:510-550`
```dart
Future<void> _playAudio(String audioBase64) async {
  // Skip in text-only mode
  if (_conversationMode == ConversationMode.textOnly) {
    print('📝 Skipping audio playback - text-only mode');
    return;
  }
  
  // Decode and convert to WAV
  final audioBytes = base64Decode(audioBase64);
  final wavBytes = _createWavFromPcm(audioBytes);
  final dataUri = 'data:audio/wav;base64,${base64Encode(wavBytes)}';
  
  // Play using just_audio
  await _audioPlayer.setUrl(dataUri);
  await _audioPlayer.play();
}
```

### 3. Audio State Management
- `_isPlayingAudio`: Tracks playback state
- `_audioStateSubscription`: Monitors playback completion
- `_onAudioCompleted()`: Handles post-playback voice reactivation

---

## Speech Recognition

### 1. Cross-Platform Implementation
**File**: `lib/services/elevenlabs_service.dart:209-245`
**Package**: `speech_to_text: ^6.1.1`

### 2. Initialization
```dart
Future<bool> initializeSpeech() async {
  // Skip in text-only mode
  if (_conversationMode == ConversationMode.textOnly) {
    return false;
  }
  
  // Request microphone permission
  final micPermission = await Permission.microphone.request();
  
  // Initialize speech recognition
  _speechSupported = await _speech.initialize(
    onStatus: (status) => _onSpeechStatusChange(status),
    onError: (error) => _onSpeechError(error),
  );
}
```

### 3. Voice Recognition Parameters
**File**: `lib/services/elevenlabs_service.dart:308-334`
```dart
await _speech.listen(
  onResult: (result) => _onSpeechResult(result),
  listenFor: const Duration(seconds: 10),    // Extended listening window
  pauseFor: const Duration(seconds: 4),      // Longer pause detection
  partialResults: true,                      // Enable partial results
  cancelOnError: true,
  listenMode: stt.ListenMode.dictation,
  localeId: 'en_US',
);
```

### 4. Continuous Voice Mode
- Auto-restart after audio playback completes
- Fallback system for incomplete speech capture
- Duplicate message prevention with `_messageSent` flag

---

## Error Handling

### 1. Connection Errors
**File**: `lib/services/elevenlabs_service.dart:472-481`
```dart
void _handleError(dynamic error) {
  dev.log('❌ WebSocket error: $error');
  _setError('Connection error: $error');
  _setStatus(ConnectionStatus.error);
}
```

### 2. Speech Recognition Errors
```dart
onError: (error) {
  print('💥 Speech error: $error');
  _isListening = false;
  notifyListeners();
}
```

### 3. Audio Playback Errors
```dart
catch (e) {
  print('💥 Error playing audio: $e');
  _isPlayingAudio = false;
  _waitingForUserInput = _voiceCallMode;
}
```

### 4. User Feedback
- Error messages displayed in UI via `_error` property
- Connection status indicators
- Console logging for debugging

---

## UI Components

### 1. Connection Status Card
**File**: `lib/screens/conversation_screen.dart:96-165`
- Shows current connection state with colored indicators
- Displays user name when connected
- Provides disconnect button

### 2. Message Bubbles
**File**: `lib/screens/conversation_screen.dart:277-342`
- Differentiated styling for user vs agent messages
- Timestamp and sender indicators
- Responsive design with proper constraints

### 3. Voice Indicator
**File**: `lib/screens/conversation_screen.dart:378-399`
- Only visible in Call Mode
- Green when listening, gray when inactive
- Animated glow effect during active listening

### 4. Input Field
**File**: `lib/screens/conversation_screen.dart:401-406`
- Dynamic hint text based on conversation mode
- Multi-line support with auto-expansion
- Mobile-optimized styling

---

## Testing & Debug

### 1. Console Logging Patterns
```
🚀 Flutter app starting...
🔧 Conversation mode set to: [Call/Text-Only]
📱 Mode selected: [Mode] Mode
🔗 Connecting to: wss://api.elevenlabs.io/...
📤 Sending initiation event: {...}
📨 Received: {...}
🎤 Speech recognition available: [true/false]
🔊 Received audio from agent (length=X)
📝 Skipping audio in text-only mode
🤖 Agent response: [text]
```

### 2. Message Flow Testing
1. **Initialization**: Check for conversation metadata
2. **Text Messaging**: Send message → receive agent response
3. **Audio Testing**: Verify audio playback in call mode
4. **Voice Testing**: Test speech recognition and transcription
5. **Mode Switching**: Verify behavior changes between modes

### 3. Error Scenarios
- **Network disconnection**: WebSocket reconnection
- **Invalid credentials**: Authentication errors
- **Audio permission denied**: Graceful fallback to text
- **Rate limiting**: ElevenLabs API throttling

---

## Dependencies

### Flutter Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  web_socket_channel: ^2.4.0      # WebSocket communication
  http: ^1.1.0                    # HTTP requests
  just_audio: ^0.9.34             # Audio playback
  speech_to_text: ^6.1.1          # Speech recognition
  permission_handler: ^10.4.3     # Microphone permissions
  provider: ^6.0.5                # State management

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
```

### Platform Configuration

#### Android Permissions
**File**: `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MICROPHONE" />
```

#### Web Configuration
- CORS handled via WebSocket connections
- No additional web-specific configuration required
- Chrome browser recommended for optimal performance

---

## Performance Considerations

### 1. Memory Management
- Audio player disposal in service destructor
- WebSocket connection cleanup
- Speech recognition resource management

### 2. Network Optimization
- Message queuing system to prevent lost messages
- Automatic reconnection handling
- Ping/pong keep-alive mechanism

### 3. Audio Processing
- Efficient PCM to WAV conversion
- Base64 decoding optimization
- Streaming audio playback

---

## Security Notes

### 1. Authentication
- JWT tokens handled securely
- No hardcoded credentials in source code
- Dynamic variable injection for user context

### 2. Data Handling
- All communication over WSS (encrypted WebSocket)
- No sensitive data logged in production
- Proper credential input validation

---

## Deployment Considerations

### 1. Web Deployment
- Ensure WebSocket support in hosting environment
- Configure proper MIME types for audio playback
- Handle browser compatibility for speech recognition

### 2. Environment Configuration
- Separate development/production agent IDs
- Environment-specific token management
- Debug logging controls

---

## Future Enhancements

### 1. Planned Features
- Multiple agent support
- Custom voice selection
- Conversation history persistence
- Real-time conversation metrics

### 2. Performance Improvements
- Audio streaming optimization
- Connection pooling
- Advanced error recovery

---

## Support & Troubleshooting

### Common Issues

1. **No audio in text-only mode**: Expected behavior
2. **Speech recognition not working**: Check microphone permissions
3. **WebSocket connection fails**: Verify network and credentials
4. **Text responses not appearing**: Check message parsing logic

### Debug Commands
```bash
# Run with verbose logging
flutter run -d chrome --verbose

# Hot reload changes
# Press 'r' in terminal

# Hot restart
# Press 'R' in terminal

# Clear Flutter cache
flutter clean && flutter pub get
```

### Contact Information
- **ElevenLabs API Documentation**: https://elevenlabs.io/docs
- **Flutter Documentation**: https://flutter.dev/docs
- **Project Repository**: [Repository URL]

---

*Last Updated: [Current Date]*

*Version: 1.0*
