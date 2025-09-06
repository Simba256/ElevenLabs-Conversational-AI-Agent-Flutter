# ElevenLabs Flutter App

A basic Flutter mobile application for testing ElevenLabs conversational AI integration.

## Features

✅ **Text-only conversation** with ElevenLabs agent  
✅ **Dark theme** UI with black background  
✅ **Real-time messaging** via WebSocket connection  
✅ **Dynamic variables** support (user_name, secret__auth_token)  
✅ **Connection status** indicators  
✅ **Message history** with timestamps  
✅ **Input validation** for credentials  

## Agent Configuration

- **Agent ID**: `agent_8701k4dytec6e43ar0ms2v7ryn9e`
- **Connection**: WebSocket to ElevenLabs API
- **Mode**: Text-only (no voice support yet)

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)

### Installation

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the app**:
   ```bash
   flutter run
   ```

### Usage

1. **Enter credentials**:
   - Your name (required)
   - Auth token (required, password field)

2. **Connect**:
   - Tap "Start Conversation" to connect

3. **Chat**:
   - Type messages and tap send
   - View conversation history
   - See connection status

4. **Disconnect**:
   - Tap "Disconnect" to end session

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   └── conversation_screen.dart  # Main chat UI
└── services/
    └── elevenlabs_service.dart   # WebSocket service
```

## Dependencies

- **web_socket_channel**: WebSocket communication
- **http**: HTTP requests (future use)
- **provider**: State management
- **json_annotation**: JSON serialization

## WebSocket Protocol

The app communicates with ElevenLabs using WebSocket messages:

### Connection
```json
{
  "user_name": "John Doe",
  "secret__auth_token": "your_token_here"
}
```

### Send Message
```json
{
  "type": "message",
  "message": "Hello, agent!"
}
```

### Receive Message
```json
{
  "message": "Hello! How can I help you?"
}
```

## Error Handling

- **Connection failures**: Displayed in status card
- **Invalid credentials**: Validation prevents connection
- **WebSocket errors**: Automatic error handling and reconnection prompts
- **Message failures**: Logged and displayed to user

## Future Enhancements

- **Voice support**: Add microphone integration
- **Multiple modes**: Text-only, text+voice, voice-first
- **Local persistence**: Save conversation history
- **Push notifications**: Background message handling
- **Custom themes**: Light/dark theme switching
- **Multi-platform**: Web and desktop support

## Testing

Run the app in debug mode to see detailed console logs:
- Connection attempts and status
- Message sending/receiving
- Error details and stack traces

## Troubleshooting

### Common Issues

1. **"Please provide both name and auth token"**
   - Fill in both credential fields

2. **WebSocket connection failed**
   - Check internet connection
   - Verify agent ID is correct
   - Ensure credentials are valid

3. **Messages not sending**
   - Check connection status
   - Verify WebSocket is connected

### Debug Logs

The app provides extensive logging:
- 🔗 Connection attempts
- 📤 Outgoing messages  
- 📨 Incoming messages
- ❌ Errors and exceptions
- ✅ Success confirmations

View logs in your IDE's debug console or use `flutter logs`.