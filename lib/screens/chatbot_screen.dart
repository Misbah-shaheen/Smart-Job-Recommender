// screens/chatbot_screen.dart
// AI Career Assistant — powered by Google Gemini API
//
// Gemini API format:
//   POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=API_KEY
//   Headers: { 'Content-Type': 'application/json' }
//   Body: {
//     "system_instruction": { "parts": [{ "text": "..." }] },
//     "contents": [
//       { "role": "user",  "parts": [{ "text": "..." }] },
//       { "role": "model", "parts": [{ "text": "..." }] }
//     ],
//     "generationConfig": { "maxOutputTokens": 1024, "temperature": 0.7 }
//   }
//   Response: data['candidates'][0]['content']['parts'][0]['text']

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a single chat message
// ─────────────────────────────────────────────────────────────────────────────
class _ChatMessage {
  final String role; // 'user' or 'model'  ← Gemini uses 'model' not 'assistant'
  final String text;
  final DateTime time;

  _ChatMessage({required this.role, required this.text, DateTime? time})
      : time = time ?? DateTime.now();

  // Gemini API format: { "role": "user"|"model", "parts": [{"text": "..."}] }
  Map<String, dynamic> toGeminiMessage() => {
    'role': role,
    'parts': [
      {'text': text}
    ],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Chatbot Screen
// ─────────────────────────────────────────────────────────────────────────────
class ChatbotBody extends StatefulWidget {
  const ChatbotBody({super.key});

  @override
  State<ChatbotBody> createState() => _ChatbotBodyState();
}

class _ChatbotBodyState extends State<ChatbotBody>
    with SingleTickerProviderStateMixin {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  final List<_ChatMessage> _messages = [];

  bool    _isLoading = false;
  String? _errorText;

  late AnimationController _dotAnim;

  static const _starters = [
    '🎯 What jobs match my skills?',
    '📚 What skills should I learn next?',
    '💰 What salary can I expect?',
    '✍️ Help me improve my resume',
    '🔍 How do I stand out in interviews?',
    '🚀 How do I switch to a tech career?',
  ];

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<AppProvider>().profile;
      final name =
      profile?.name.isNotEmpty == true ? profile!.name : 'there';
      setState(() {
        _messages.add(_ChatMessage(
          role: 'model',
          text: "Hi $name! 👋 I'm your AI Career Assistant, powered by Gemini.\n\n"
              "I know your profile and skill set, so I can give you "
              "personalised career advice, salary insights, skill gap analysis, "
              "job search tips, and more.\n\n"
              "What can I help you with today?",
        ));
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _dotAnim.dispose();
    super.dispose();
  }

  // ── Build system instruction (Gemini calls it system_instruction) ─────
  String _buildSystemPrompt() {
    final provider   = context.read<AppProvider>();
    final profile    = provider.profile;
    final jobs       = provider.filteredJobs;

    final name         = profile?.name.isNotEmpty == true ? profile!.name : 'the user';
    final skills       = profile?.skills       ?? [];
    final experienceYr = profile?.experience   ?? 0;
    final targetRole   = profile?.preferredRole ?? '';

    final jobSample = jobs.take(20).map((j) =>
    '• ${j.jobTitle} at ${j.company} (${j.workType}, '
        '\$${(j.salary / 1000).toStringAsFixed(0)}k, '
        '${j.experience}yr exp, '
        'skills: ${j.skills.take(4).join(', ')})'
    ).join('\n');

    return """You are an expert AI Career Assistant integrated into a Smart Job Recommender app.

USER PROFILE:
- Name: $name
- Skills: ${skills.isEmpty ? 'Not set yet' : skills.join(', ')}
- Years of Experience: $experienceYr
- Target / Preferred Role: ${targetRole.isEmpty ? 'Not specified' : targetRole}

CURRENT JOB LISTINGS IN THE APP (sample of 20):
${jobSample.isEmpty ? 'No jobs loaded yet' : jobSample}

YOUR RESPONSIBILITIES:
1. Give personalised, actionable career advice based on the user's actual profile
2. Suggest specific skills to learn based on their current skills and target role
3. Provide realistic salary expectations for their skill level
4. Help with resume tips, interview preparation, and job search strategies
5. Identify skill gaps between their current skills and job requirements
6. Recommend career paths and growth opportunities
7. Be encouraging, honest, and specific — avoid generic advice

TONE: Professional but friendly. Use bullet points for lists. Keep responses concise (under 250 words) unless asked for detail. Always tie advice back to the user's specific skills and goals. Reference the job listings above when relevant.""";
  }

  // ── Send message to Gemini API ─────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _inputCtrl.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: trimmed));
      _isLoading = true;
      _errorText = null;
    });
    _scrollToBottom();

    try {
      // Gemini multi-turn: exclude the local welcome message (index 0)
      // and only send real user/model turns to the API
      final history = _messages
          .skip(1) // skip welcome message generated locally
          .map((m) => m.toGeminiMessage())
          .toList();

      // Gemini endpoint: key goes in the URL as a query parameter
      final url = Uri.parse(AppConstants.geminiEndpoint)
          .replace(queryParameters: {'key': AppConstants.geminiApiKey});

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // System instruction — sets the AI's persona and context
          'system_instruction': {
            'parts': [
              {'text': _buildSystemPrompt()}
            ]
          },
          // Full conversation history for multi-turn context
          'contents': history,
          'generationConfig': {
            'maxOutputTokens': 1024,
            'temperature':     0.7,
            'topP':            0.9,
          },
          'safetySettings': [
            {
              'category':  'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE',
            },
            {
              'category':  'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_NONE',
            },
          ],
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Gemini response path:
        // data['candidates'][0]['content']['parts'][0]['text']
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini returned no candidates. '
              'The prompt may have been blocked by safety filters.');
        }

        final content = candidates[0]['content'] as Map<String, dynamic>?;
        if (content == null) {
          throw Exception('Gemini response missing content field.');
        }

        final parts = content['parts'] as List<dynamic>?;
        if (parts == null || parts.isEmpty) {
          throw Exception('Gemini response missing parts.');
        }

        final reply = parts
            .where((p) => p['text'] != null)
            .map((p) => p['text'].toString())
            .join('');

        if (reply.isEmpty) throw Exception('Gemini returned empty text.');

        setState(() {
          _messages.add(_ChatMessage(role: 'model', text: reply));
          _isLoading = false;
        });
      } else {
        // Parse Gemini error format: { "error": { "message": "..." } }
        Map<String, dynamic>? errBody;
        try {
          errBody = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {}

        final msg = errBody?['error']?['message'] ??
            'HTTP ${response.statusCode}: ${response.body}';
        throw Exception(msg);
      }
    } catch (e) {
      final errText = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
        _errorText = errText;
        _messages.add(_ChatMessage(
          role: 'model',
          text: '⚠️ $errText\n\n'
              'Check that your Gemini API key in app_constants.dart is correct '
              'and that the Generative Language API is enabled in Google Cloud Console.',
        ));
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    final profile = context.read<AppProvider>().profile;
    final name =
    profile?.name.isNotEmpty == true ? profile!.name : 'there';
    setState(() {
      _messages.clear();
      _errorText = null;
      _messages.add(_ChatMessage(
        role: 'model',
        text: "Hi $name! 👋 Chat cleared. What would you like to discuss?",
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ───────────────────────────────────────────────────
        Container(
          color: const Color(0xFF1A1A35),
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF1A73E8).withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 12, color: Color(0xFF1A73E8)),
                    const SizedBox(width: 5),
                    Text('Gemini Flash',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A73E8))),
                  ],
                ),
              ),
              const Spacer(),
              if (_messages.length > 1)
                TextButton.icon(
                  onPressed: _clearChat,
                  icon: const Icon(Icons.refresh_rounded,
                      size: 14, color: Colors.white54),
                  label: Text('Clear',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white54)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4)),
                ),
            ],
          ),
        ),

        // ── Message list ──────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _messages.length
                + (_messages.length == 1 ? 1 : 0) // starters row
                + (_isLoading        ? 1 : 0),      // typing indicator
            itemBuilder: (context, index) {
              // First message (welcome)
              if (index == 0) {
                return _MessageBubble(message: _messages[0]);
              }

              // Starters row shown right after welcome
              if (_messages.length == 1 && index == 1) {
                return _StartersRow(
                    starters: _starters, onTap: _sendMessage);
              }

              final starterOffset = _messages.length == 1 ? 1 : 0;
              final msgIndex = index - starterOffset;

              // Typing indicator
              if (_isLoading && msgIndex >= _messages.length) {
                return _TypingIndicator(animation: _dotAnim);
              }

              if (msgIndex >= _messages.length) {
                return const SizedBox.shrink();
              }
              return _MessageBubble(message: _messages[msgIndex]);
            },
          ),
        ),

        // ── Input bar ─────────────────────────────────────────────────
        _InputBar(
          controller: _inputCtrl,
          focusNode:  _focusNode,
          isLoading:  _isLoading,
          onSend:     _sendMessage,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  bool get isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: Colors.white),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(
                    ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context).size.width * 0.78,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.primary
                      : const Color(0xFF1E1E3A),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isUser
                      ? null
                      : Border.all(
                      color: Colors.white.withOpacity(0.07)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormattedText(
                        text: message.text, isUser: isUser),
                    const SizedBox(height: 4),
                    Text(
                      _fmt(message.time),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isUser
                            ? Colors.white54
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Formatted text (bold + bullets + numbered lists)
// ─────────────────────────────────────────────────────────────────────────────
class _FormattedText extends StatelessWidget {
  final String text;
  final bool isUser;
  const _FormattedText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final color = isUser ? Colors.white : AppTheme.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: text.split('\n').map((line) {
        final t = line.trim();
        if (t.isEmpty) return const SizedBox(height: 4);

        if (t.startsWith('**') && t.endsWith('**') && t.length > 4) {
          return Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(t.substring(2, t.length - 2),
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          );
        }
        if (t.startsWith('• ') ||
            t.startsWith('- ') ||
            t.startsWith('* ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isUser
                            ? Colors.white70
                            : AppTheme.primary)),
                Expanded(child: _inline(t.substring(2), color)),
              ],
            ),
          );
        }
        final num = RegExp(r'^\d+\.\s').firstMatch(t);
        if (num != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(num.group(0)!,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isUser
                            ? Colors.white70
                            : AppTheme.primary)),
                Expanded(
                    child: _inline(
                        t.substring(num.group(0)!.length), color)),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 1),
          child: _inline(t, color),
        );
      }).toList(),
    );
  }

  Widget _inline(String raw, Color color) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(raw)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: raw.substring(last, m.start),
            style: GoogleFonts.inter(fontSize: 13, color: color)));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color)));
      last = m.end;
    }
    if (last < raw.length) {
      spans.add(TextSpan(
          text: raw.substring(last),
          style: GoogleFonts.inter(fontSize: 13, color: color)));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator
// ─────────────────────────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final Animation<double> animation;
  const _TypingIndicator({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 16, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E3A),
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(18),
                topRight:    Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft:  Radius.circular(4),
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.07)),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase =
                      (animation.value + i / 3) % 1.0;
                  final offset =
                  phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.primary
                          .withOpacity(0.4 + offset * 0.6),
                      shape: BoxShape.circle,
                    ),
                    transform: Matrix4.translationValues(
                        0, -4 * offset, 0),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Starter prompt chips
// ─────────────────────────────────────────────────────────────────────────────
class _StartersRow extends StatelessWidget {
  final List<String> starters;
  final void Function(String) onTap;
  const _StartersRow({required this.starters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 38),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: starters
            .map((s) => GestureDetector(
          onTap: () => onTap(s),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color:
                  AppTheme.primary.withOpacity(0.25)),
            ),
            child: Text(s,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500)),
          ),
        ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input bar
// ─────────────────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A35),
      padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:      controller,
              focusNode:       focusNode,
              enabled:         !isLoading,
              maxLines:        4,
              minLines:        1,
              textInputAction: TextInputAction.newline,
              keyboardType:    TextInputType.multiline,
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask me anything about your career…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: Colors.white38),
                filled:    true,
                fillColor: const Color(0xFF13132B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: AppTheme.primary.withOpacity(0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
              onSubmitted:
              isLoading ? null : onSend,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isLoading
                  ? null
                  : const LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFF48CAE4)
                ],
              ),
              color: isLoading
                  ? const Color(0xFF2A2A4A)
                  : null,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isLoading
                  ? null
                  : () => onSend(controller.text),
              icon: isLoading
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

typedef ChatbotScreen = ChatbotBody;