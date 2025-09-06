# Flutter App Setup Instructions

## Quick Start

1. **Navigate to the Flutter app directory**:
   ```bash
   cd "/media/basim/New Volume1/Basim/Saad Bhai/Chamelion Ideas/Ollie/official_repo/NEXT/elevenlabs-flutter-app"
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Check Flutter setup** (optional):
   ```bash
   flutter doctor
   ```

4. **Run the app**:
   ```bash
   # For Android emulator/device
   flutter run
   
   # For web (if available)
   flutter run -d web-server --web-port 8080
   
   # For specific device
   flutter devices  # List available devices
   flutter run -d <device_id>
   ```

## Testing the ElevenLabs Integration

### Step 1: Launch the App
- The app will open with a black theme
- You'll see the connection status at the top (should show "Disconnected")

### Step 2: Enter Credentials
- **Name Field**: Enter any name (e.g., "Test User")
- **Auth Token Field**: Enter your secret token (same as used in web app)

### Step 3: Connect
- Tap "Start Conversation" button
- Status should change to "Connecting..." then "Connected as [Your Name]"

### Step 4: Chat
- Type a message in the bottom input field
- Tap the send button (green circle with arrow)
- Your message appears on the right (blue bubble)
- Agent response appears on the left (gray bubble)

### Step 5: Test Features
- Send multiple messages
- Check timestamps on messages
- Test disconnection with "Disconnect" button
- Try reconnecting with different credentials

## Expected Behavior

### ✅ **Working Features**
- Dark theme UI with white text
- Real-time WebSocket connection
- Message bubbles with timestamps
- Connection status indicators
- Input validation (button disabled until both fields filled)
- Scroll to bottom on new messages
- Error handling and display

### 🔍 **Debug Information**
Check the Flutter console/logs for:
- `🔗 Connecting to: wss://api.elevenlabs.io/...`
- `📤 Sending init message: {...}`
- `✅ Connected successfully`
- `📤 Sending message: [your message]`
- `📨 Received: [agent response]`

### ❌ **Common Issues**
1. **"Please provide both name and auth token"** - Fill both fields
2. **Connection fails** - Check internet, verify credentials
3. **No agent response** - Check agent configuration
4. **UI not updating** - Check Provider state management

## Debugging Commands

```bash
# Run with verbose logging
flutter run --verbose

# Run in debug mode with hot reload
flutter run --debug

# Check for issues
flutter analyze

# Clear build cache if needed
flutter clean
flutter pub get
```

## Platform-Specific Notes

### Android
- Requires internet permission (already in manifest)
- Works on emulator or physical device
- Hot reload available during development

### iOS 
- May need additional WebSocket permissions
- Test on simulator or device
- Requires Xcode for device deployment

### Web
- WebSocket connections work in browser
- CORS may affect some operations
- Good for quick testing

## Next Steps for Testing

1. **Basic Functionality Test**:
   - Connect, send message, receive response, disconnect

2. **Error Handling Test**:
   - Try invalid credentials
   - Disconnect during conversation
   - Send empty messages

3. **UI/UX Test**:
   - Check message formatting
   - Verify scrolling behavior
   - Test on different screen sizes

4. **Performance Test**:
   - Send multiple rapid messages
   - Long conversation threads
   - Memory usage over time

The Flutter app is ready for testing! It provides the same core functionality as the Next.js web app but in a native mobile interface.