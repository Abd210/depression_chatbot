import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

void main() {
  runApp(MyApp());
}

/// MyApp defines our MaterialApp with your provided color palette:
///   Primary:    #3674B5  
///   Accent:     #578FCA  
///   Light Blue: #A1E3F9  
///   Background: #D1F8EF
class MyApp extends StatelessWidget {
  static const Color primaryColor = Color(0xFF3674B5);
  static const Color accentColor = Color(0xFF578FCA);
  static const Color lightBlue = Color(0xFFA1E3F9);
  static const Color lightBackground = Color(0xFFD1F8EF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Depression Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: accentColor),
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          centerTitle: true,
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

/// AppData is a global singleton that holds journal and mood entries so that they can be shared across pages.
class AppData {
  static final List<JournalEntry> journalEntries = [];
  static final List<MoodEntry> moodEntries = [];
}

/// HomeScreen contains our bottom navigation bar and switches between pages.
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    ChatPage(),
    JournalPage(),
    MoodTrackerPage(),
    AnalysisPage(),
    ResourcesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: MyApp.primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (int index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: "Journal"),
          BottomNavigationBarItem(icon: Icon(Icons.mood), label: "Mood"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: "Analysis"),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: "Resources"),
        ],
      ),
    );
  }
}

/// ============================================================================
///                         CHAT PAGE & SUPPORT WIDGETS
/// ============================================================================

/// Message model holds text, sender type, a typing flag, and a timestamp.
class Message {
  final String text;
  final bool isUser;
  final bool isTyping;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    this.isTyping = false,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();
}

/// ChatPage is our advanced chatbot interface. It connects to your backend
/// using the same endpoints and syntax, shows smooth animations, and uses
/// a typewriter effect for bot replies.
class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final List<Message> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Use your backend endpoints (do not change syntax)
  final String _serverUrl = "http://localhost:3000/chat";
  final String _clearUrl = "http://localhost:3000/clear";

  bool _isWaitingResponse = false;
  int? _typingMessageIndex; // holds the index for the typing indicator

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Inserts a message into the AnimatedList with a smooth fade & slide.
  void _insertMessage(Message message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(_messages.length - 1, duration: const Duration(milliseconds: 300));
    _scrollToBottom();
  }

  /// Removes a message from the list with animation.
  void _removeMessageAt(int index) {
    if (index < 0 || index >= _messages.length) return;
    final Message removed = _messages.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => SmoothEntryTransition(
        animation: animation,
        child: ChatBubble(message: removed),
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// Scrolls to the bottom after a short delay.
  void _scrollToBottom() {
    Timer(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Inserts a special typing indicator message.
  void _showTypingIndicator() {
    if (_typingMessageIndex != null) return;
    Message typingMessage = Message(text: "", isUser: false, isTyping: true);
    _typingMessageIndex = _messages.length;
    _insertMessage(typingMessage);
  }

  /// Removes the typing indicator if present.
  void _removeTypingIndicator() {
    if (_typingMessageIndex == null) return;
    int index = _typingMessageIndex!;
    if (index < _messages.length && _messages[index].isTyping) {
      _removeMessageAt(index);
    }
    _typingMessageIndex = null;
  }

  /// Sends the user's message to your backend. While waiting, a typing
  /// indicator is shown. When a reply is received, it is animated with a
  /// typewriter effect.
  Future<void> _sendMessage() async {
    String messageText = _controller.text.trim();
    if (messageText.isEmpty || _isWaitingResponse) return;

    // Insert user message.
    _insertMessage(Message(text: messageText, isUser: true));
    _controller.clear();

    // Show bot typing indicator.
    _showTypingIndicator();
    _isWaitingResponse = true;

    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': messageText}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['reply'] ?? "Error: No reply received.";
        _removeTypingIndicator();
        _insertMessage(Message(text: reply, isUser: false));
      } else {
        _removeTypingIndicator();
        _insertMessage(Message(
          text: "Error: ${response.statusCode} ${response.reasonPhrase}",
          isUser: false,
        ));
      }
    } catch (error) {
      _removeTypingIndicator();
      _insertMessage(Message(
        text: "Error: Something went wrong. Please try again.",
        isUser: false,
      ));
    }
    _isWaitingResponse = false;
  }

  /// Clears the conversation on both the backend and locally.
  Future<void> _clearConversation() async {
    try {
      final response = await http.post(Uri.parse(_clearUrl), headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        for (int i = _messages.length - 1; i >= 0; i--) {
          _removeMessageAt(i);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to clear conversation: ${response.statusCode}")),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error clearing conversation.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat with Compassion"),
        actions: [
          IconButton(
            tooltip: "Clear Conversation",
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearConversation,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          // Gradient background using your color palette.
          gradient: LinearGradient(
            colors: [Color(0xFFD1F8EF), Color(0xFFA1E3F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: AnimatedList(
                key: _listKey,
                controller: _scrollController,
                initialItemCount: _messages.length,
                itemBuilder: (context, index, animation) {
                  return SmoothEntryTransition(
                    animation: animation,
                    child: ChatBubble(message: _messages[index]),
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  /// Builds the input area (TextField + Send button).
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white.withOpacity(0.9),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 16.0, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: "Type your message...",
                hintStyle: TextStyle(color: Colors.black45),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8.0),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: MyApp.primaryColor,
            child: const Icon(Icons.send, color: Colors.white),
            tooltip: "Send Message",
          ),
        ],
      ),
    );
  }
}

/// SmoothEntryTransition applies a subtle fade and slight upward slide.
class SmoothEntryTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const SmoothEntryTransition({Key? key, required this.animation, required this.child})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}

/// ChatBubble displays a single message with rounded corners, an avatar,
/// a timestamp, and supports long-press to copy the text.
class ChatBubble extends StatelessWidget {
  final Message message;
  const ChatBubble({Key? key, required this.message}) : super(key: key);

  String _formatTimestamp(DateTime dt) {
    int hour = dt.hour;
    int minute = dt.minute;
    String period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$hour:${minute.toString().padLeft(2, '0')} $period";
  }

  @override
  Widget build(BuildContext context) {
    final Color userBubbleColor = MyApp.primaryColor;
    final Color botBubbleColor = MyApp.lightBlue;
    final bubbleColor = message.isUser ? userBubbleColor : botBubbleColor;
    final avatarIcon = message.isUser ? Icons.person : Icons.smart_toy;
    final textStyle = const TextStyle(fontSize: 16.0, color: Colors.white);

    // For bot messages (not the typing indicator), use a typewriter effect.
    Widget messageContent;
    if (message.isTyping) {
      messageContent = const TypingIndicator();
    } else {
      messageContent = message.isUser
          ? Text(message.text, style: textStyle)
          : TypewriterText(text: message.text, style: textStyle);
    }

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Copied to clipboard")),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!message.isUser)
                  CircleAvatar(
                    backgroundColor: MyApp.accentColor,
                    child: Icon(avatarIcon, color: Colors.white, size: 20.0),
                  ),
                if (!message.isUser) const SizedBox(width: 8.0),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: message.isUser ? const Radius.circular(16.0) : Radius.zero,
                        bottomRight: message.isUser ? Radius.zero : const Radius.circular(16.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4.0,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: messageContent,
                  ),
                ),
                if (message.isUser) const SizedBox(width: 8.0),
                if (message.isUser)
                  CircleAvatar(
                    backgroundColor: MyApp.accentColor,
                    child: Icon(avatarIcon, color: Colors.white, size: 20.0),
                  ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(_formatTimestamp(message.timestamp),
                style: TextStyle(fontSize: 10.0, color: Colors.grey[300])),
          ],
        ),
      ),
    );
  }
}

/// TypewriterText animates bot text so it appears letter-by-letter with a blinking cursor.
/// It uses RichText so that the text wraps properly.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed; // Delay per character.
  const TypewriterText({
    Key? key,
    required this.text,
    required this.style,
    this.speed = const Duration(milliseconds: 30),
  }) : super(key: key);
  @override
  _TypewriterTextState createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    _startTyping();
  }
  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _currentIndex++;
          _displayedText = widget.text.substring(0, _currentIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _displayedText),
          if (_currentIndex < widget.text.length)
            WidgetSpan(child: BlinkingCursor(style: widget.style)),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }
}

/// BlinkingCursor shows a blinking vertical bar to simulate a text cursor.
class BlinkingCursor extends StatefulWidget {
  final TextStyle style;
  const BlinkingCursor({Key? key, required this.style}) : super(key: key);
  @override
  _BlinkingCursorState createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text("|", style: widget.style),
    );
  }
}

/// TypingIndicator displays three animated dots.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);
  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  Widget _buildDot(int index) {
    return FadeTransition(
      opacity: DelayTween(begin: 0.0, end: 1.0, delay: index * 0.2).animate(_animationController),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: const CircleAvatar(radius: 4.0, backgroundColor: Colors.white),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.start,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }
}

/// DelayTween adds a delay to an animation’s tween.
class DelayTween extends Tween<double> {
  final double delay;
  DelayTween({double? begin, double? end, this.delay = 0.0})
      : super(begin: begin, end: end);
  @override
  double lerp(double t) {
    final double adjustedT = (t - delay).clamp(0.0, 1.0);
    return super.lerp(adjustedT);
  }
}

/// ============================================================================
///                          JOURNAL PAGE
/// ============================================================================

/// JournalEntry holds a journal text and timestamp.
class JournalEntry {
  final String text;
  final DateTime timestamp;
  JournalEntry({required this.text, DateTime? timestamp}) : this.timestamp = timestamp ?? DateTime.now();
}

/// JournalPage lets users write and view daily journal entries.
class JournalPage extends StatefulWidget {
  @override
  _JournalPageState createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final List<JournalEntry> _entries = [];

  void _addEntry(String text) {
    final entry = JournalEntry(text: text);
    setState(() {
      _entries.insert(0, entry);
    });
    // Also add to global AppData.
    AppData.journalEntries.insert(0, entry);
  }

  void _showAddEntryDialog() {
    final TextEditingController _entryController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Journal Entry"),
        content: TextField(
          controller: _entryController,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "Write your thoughts..."),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () { Navigator.pop(context); },
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () {
              if (_entryController.text.trim().isNotEmpty) {
                _addEntry(_entryController.text.trim());
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal"),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD1F8EF), Color(0xFFA1E3F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _entries.isEmpty
            ? const Center(child: Text("No entries yet. Tap + to add one.", style: TextStyle(fontSize: 16.0)))
            : ListView.separated(
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return ListTile(
                    title: Text(entry.text),
                    subtitle: Text(_formatTimestamp(entry.timestamp)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() { _entries.removeAt(index); });
                        AppData.journalEntries.removeAt(index);
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntryDialog,
        backgroundColor: MyApp.primaryColor,
        child: const Icon(Icons.add),
        tooltip: "Add Journal Entry",
      ),
    );
  }
}

/// ============================================================================
///                        MOOD TRACKER PAGE
/// ============================================================================

/// MoodEntry holds a mood (as a string/emoji) and a timestamp.
class MoodEntry {
  final String mood;
  final DateTime timestamp;
  MoodEntry({required this.mood, DateTime? timestamp}) : this.timestamp = timestamp ?? DateTime.now();
}

/// MoodTrackerPage allows users to log their mood.
class MoodTrackerPage extends StatefulWidget {
  @override
  _MoodTrackerPageState createState() => _MoodTrackerPageState();
}

class _MoodTrackerPageState extends State<MoodTrackerPage> {
  final List<MoodEntry> _moodEntries = [];
  final List<String> _moodOptions = ["😀", "🙂", "😐", "😟", "😢", "😠"];

  void _addMood(String mood) {
    final entry = MoodEntry(mood: mood);
    setState(() {
      _moodEntries.insert(0, entry);
    });
    // Also add to global AppData.
    AppData.moodEntries.insert(0, entry);
  }

  void _showMoodPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("How are you feeling?"),
        content: Wrap(
          spacing: 12.0,
          children: _moodOptions.map((mood) {
            return GestureDetector(
              onTap: () {
                _addMood(mood);
                Navigator.pop(context);
              },
              child: CircleAvatar(
                backgroundColor: MyApp.accentColor,
                child: Text(mood, style: const TextStyle(fontSize: 24.0)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mood Tracker"),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD1F8EF), Color(0xFFA1E3F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _moodEntries.isEmpty
            ? const Center(child: Text("No mood entries yet. Tap + to add one.", style: TextStyle(fontSize: 16.0)))
            : ListView.separated(
                itemCount: _moodEntries.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = _moodEntries[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: MyApp.accentColor,
                      child: Text(entry.mood, style: const TextStyle(fontSize: 24.0)),
                    ),
                    title: Text("Mood: ${entry.mood}", style: const TextStyle(fontSize: 18.0)),
                    subtitle: Text(_formatTimestamp(entry.timestamp)),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMoodPicker,
        backgroundColor: MyApp.primaryColor,
        child: const Icon(Icons.add),
        tooltip: "Log Mood",
      ),
    );
  }
}

/// ============================================================================
///                          ANALYSIS PAGE
/// ============================================================================

/// AnalysisPage compiles the user’s journal and mood data and sends it to the backend
/// (using the same /chat endpoint) so that the AI can analyze the user’s mental state and provide feedback.
class AnalysisPage extends StatefulWidget {
  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  String _analysisResult = "";
  bool _isAnalyzing = false;
  final String _serverUrl = "http://localhost:3000/chat";

  Future<void> _analyzeData() async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = "";
    });
    // Compile journal entries.
    String journalData = AppData.journalEntries.isNotEmpty
        ? AppData.journalEntries
            .map((entry) => "- ${entry.text} (at ${entry.timestamp.month}/${entry.timestamp.day}/${entry.timestamp.year})")
            .join("\n")
        : "No journal entries provided.";
    // Compile mood entries.
    String moodData = AppData.moodEntries.isNotEmpty
        ? AppData.moodEntries
            .map((entry) => "- ${entry.mood} (at ${entry.timestamp.month}/${entry.timestamp.day}/${entry.timestamp.year})")
            .join("\n")
        : "No mood entries provided.";
    // Construct the prompt.
    String prompt = "Analyze my current mental state based on the following data.\n\n"
        "Journal Entries:\n$journalData\n\n"
        "Mood Tracker Entries:\n$moodData\n\n"
        "Please provide a detailed analysis along with recommendations to improve my mental well-being.";
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': prompt}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['reply'] ?? "Error: No analysis received.";
        setState(() {
          _analysisResult = reply;
        });
      } else {
        setState(() {
          _analysisResult = "Error: ${response.statusCode} ${response.reasonPhrase}";
        });
      }
    } catch (error) {
      setState(() {
        _analysisResult = "Error: Something went wrong. Please try again.";
      });
    }
    setState(() {
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis"),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD1F8EF), Color(0xFFA1E3F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isAnalyzing
            ? const Center(child: CircularProgressIndicator())
            : _analysisResult.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Press the button below to analyze your mental state.",
                            style: TextStyle(fontSize: 16.0), textAlign: TextAlign.center),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: _analyzeData,
                          style: ElevatedButton.styleFrom(backgroundColor: MyApp.primaryColor),
                          child: const Text("Analyze Now"),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Analysis Result:", style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12.0),
                        TypewriterText(text: _analysisResult, style: const TextStyle(fontSize: 16.0, color: Colors.white)),
                        const SizedBox(height: 16.0),
                        ElevatedButton(
                          onPressed: _analyzeData,
                          style: ElevatedButton.styleFrom(backgroundColor: MyApp.primaryColor),
                          child: const Text("Re-run Analysis"),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// ============================================================================
///                          RESOURCES PAGE
/// ============================================================================

/// ResourcesPage displays helpful depression-related resources and self-care tips.
class ResourcesPage extends StatelessWidget {
  // Make _tips a non-const list to allow shuffling.
  final List<String> _tips = [
    "Take a short walk and get some fresh air.",
    "Practice deep breathing exercises for 5 minutes.",
    "Write down three things you are grateful for today.",
    "Take a break and listen to your favorite music.",
    "Try a brief meditation session – even 5 minutes can help.",
  ];

  final List<Map<String, String>> _resources = const [
    {
      "icon": "phone",
      "title": "National Suicide Prevention Lifeline",
      "subtitle": "Call 988 (US) or 1-800-273-8255 if in crisis. Outside the US, contact local emergency services.",
    },
    {
      "icon": "message",
      "title": "Crisis Text Line",
      "subtitle": "Text HOME to 741741 (US only) to connect with a crisis counselor.",
    },
    {
      "icon": "self_improvement",
      "title": "Mindfulness & Self-Care",
      "subtitle": "Try meditation, deep breathing, or gentle physical activity.",
    },
    {
      "icon": "support",
      "title": "Talk to Someone",
      "subtitle": "Reach out to trusted friends, family, or mental health professionals.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final List<String> tipsCopy = List.from(_tips);
    tipsCopy.shuffle();
    final String tip = tipsCopy.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Helpful Resources"),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFD1F8EF), Color(0xFFA1E3F9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: [
            Text("Tip of the Day", style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
            const SizedBox(height: 8.0),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(tip, style: const TextStyle(fontSize: 16.0)),
              ),
            ),
            const SizedBox(height: 16.0),
            ..._resources.map((resource) {
              IconData iconData;
              switch (resource["icon"]) {
                case "phone":
                  iconData = Icons.phone;
                  break;
                case "message":
                  iconData = Icons.message;
                  break;
                case "self_improvement":
                  iconData = Icons.self_improvement;
                  break;
                case "support":
                  iconData = Icons.support;
                  break;
                default:
                  iconData = Icons.help;
              }
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: Icon(iconData, color: MyApp.primaryColor),
                  title: Text(resource["title"]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(resource["subtitle"]!),
                ),
              );
            }).toList(),
            const SizedBox(height: 16.0),
            const Center(
              child: Text(
                "Remember: You are not alone. If you feel unsafe, please call emergency services immediately.",
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
