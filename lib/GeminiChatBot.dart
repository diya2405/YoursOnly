import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'GeminiModel.dart';
import 'global.dart';

// ─── YoursOnly Design Tokens ──────────────────────────────────────────────────
class YO {
  static const Color bg          = Color(0xFF0D0B1A);
  static const Color surface     = Color(0xFF15122A);
  static const Color surface2    = Color(0xFF1E1A38);
  static const Color border      = Color(0xFF2E2850);
  static const Color purple      = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFA78BFA);
  static const Color pink        = Color(0xFFEC4899);
  static const Color textPrim    = Color(0xFFE9E6F8);
  static const Color textMuted   = Color(0xFF8A85AA);
  static const Color textDim     = Color(0xFF4E4A6A);

  static const LinearGradient primaryGrad = LinearGradient(
    colors: [purple, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── Roles ────────────────────────────────────────────────────────────────────
class BotRole {
  final String name;
  final String emoji;
  final String systemPrompt;
  final String subtitle;
  const BotRole({
    required this.name,
    required this.emoji,
    required this.systemPrompt,
    required this.subtitle,
  });
}

const List<BotRole> kRoles = [
  BotRole(
    name: 'Companion',
    emoji: '🌙',
    subtitle: 'A calm, non-judgmental listener',
    systemPrompt:
    'You are YoursOnly — a warm emotional companion. NOT a therapist. '
        'Talk like a trusted late-night friend. Validate feelings first. '
        'Never use toxic positivity. Ask one thoughtful follow-up. Keep responses to 2-4 sentences.',
  ),
  BotRole(
    name: 'Friend',
    emoji: '😊',
    subtitle: 'Casual, warm, supportive',
    systemPrompt: 'You are a friendly, casual companion. Relaxed, warm, and supportive. Simple language.',
  ),
  BotRole(
    name: 'Teacher',
    emoji: '📚',
    subtitle: 'Patient step-by-step explanations',
    systemPrompt: 'You are a patient teacher. Explain step by step with examples. Encourage and check understanding.',
  ),
  BotRole(
    name: 'Coach',
    emoji: '💪',
    subtitle: 'Energetic and goal-oriented',
    systemPrompt: 'You are a motivational life coach. Energetic, positive, action-oriented. Push toward goals.',
  ),
  BotRole(
    name: 'Therapist',
    emoji: '🧠',
    subtitle: 'Empathetic emotional support',
    systemPrompt:
    'You are a calm, empathetic support companion (NOT a replacement for a real therapist). '
        'Listen, validate feelings, ask thoughtful follow-up questions. Never give diagnoses.',
  ),
  BotRole(
    name: 'Coder',
    emoji: '💻',
    subtitle: 'Precise, well-explained code',
    systemPrompt: 'You are an expert software engineer. Precise, well-commented code. Explain reasoning. Clean modern approaches.',
  ),
];

// ─── Tones ────────────────────────────────────────────────────────────────────
class BotTone {
  final String name;
  final String emoji;
  final String instruction;
  const BotTone({required this.name, required this.emoji, required this.instruction});
}

const List<BotTone> kTones = [
  BotTone(name: 'Balanced', emoji: '⚖️', instruction: 'Use a balanced, neutral tone.'),
  BotTone(name: 'Formal',   emoji: '🎩', instruction: 'Formal, professional. No contractions or slang.'),
  BotTone(name: 'Casual',   emoji: '😎', instruction: 'Very casual and relaxed. Short sentences.'),
  BotTone(name: 'Funny',    emoji: '😂', instruction: 'Witty and humorous. Light jokes where appropriate.'),
  BotTone(name: 'Concise',  emoji: '⚡', instruction: 'Extremely concise. Short direct answers. No filler.'),
  BotTone(name: 'Detailed', emoji: '📝', instruction: 'Thorough and detailed. Cover edge cases. Explain fully.'),
];

// ─── Saved conversation ───────────────────────────────────────────────────────
class SavedConversation {
  final String id;
  final String title;
  final String roleName;
  final String roleEmoji;
  final DateTime savedAt;
  final List<ModelMessage> messages;

  SavedConversation({
    required this.id,
    required this.title,
    required this.roleName,
    required this.roleEmoji,
    required this.savedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'roleName': roleName,
    'roleEmoji': roleEmoji,
    'savedAt': savedAt.toIso8601String(),
    'messages': messages.map((m) => {
      'isprompt': m.isprompt,
      'message': m.message,
      'time': m.time.toIso8601String(),
    }).toList(),
  };

  factory SavedConversation.fromJson(Map<String, dynamic> json) => SavedConversation(
    id: json['id'],
    title: json['title'],
    roleName: json['roleName'],
    roleEmoji: json['roleEmoji'],
    savedAt: DateTime.parse(json['savedAt']),
    messages: (json['messages'] as List).map((m) => ModelMessage(
      isprompt: m['isprompt'],
      message: m['message'],
      time: DateTime.parse(m['time']),
    )).toList(),
  );
}

// ─── Main widget ──────────────────────────────────────────────────────────────
class Geminichatbot extends StatefulWidget {
  const Geminichatbot({super.key});
  @override
  State<Geminichatbot> createState() => _GeminichatbotState();
}

class _GeminichatbotState extends State<Geminichatbot>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<ModelMessage> _messages = [];
  bool _isLoading = false;

  BotRole _role = kRoles[0];
  BotTone _tone = kTones[0];

  late ChatSession _chat;
  late GenerativeModel _model;
  static const int _maxContextPairs = 10;

  List<SavedConversation> _history = [];
  static const String _historyKey = 'chat_history_v2';

  // Typing dot animation controller
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _initModel();
    _loadHistory();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── Model ──────────────────────────────────────────────────────────────────
  void _initModel() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.system(
          '${_role.systemPrompt}\n\nTone: ${_tone.instruction}'),
    );
    _chat = _model.startChat();
  }

  void _trimSession() {
    final h = _chat.history.toList();
    final from = h.length - (_maxContextPairs * 2);
    final trimmed = from > 0 ? h.sublist(from) : h;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.system(
          '${_role.systemPrompt}\n\nTone: ${_tone.instruction}'),
    );
    _chat = _model.startChat(history: trimmed);
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isLoading) {
      _snack('Still thinking…', 'Give me a moment 🌙');
      return;
    }

    setState(() {
      _inputCtrl.clear();
      FocusScope.of(context).unfocus();
      _messages.add(ModelMessage(isprompt: true, message: text, time: DateTime.now()));
      _isLoading = true;
    });
    _scrollDown();

    try {
      if (_chat.history.length > _maxContextPairs * 2) _trimSession();
      final res = await _chat.sendMessage(Content.text(text));
      setState(() {
        _isLoading = false;
        _messages.add(ModelMessage(
          isprompt: false,
          message: res.text ?? 'No response generated.',
          time: DateTime.now(),
        ));
      });
      _scrollDown();
    } on SocketException {
      _onError('No internet. Check your connection and try again.');
    } catch (e, s) {
      debugPrint('Gemini Error: $e');
      debugPrintStack(stackTrace: s);
      _onError('Error: $e');
    }
  }

  void _onError(String msg) {
    setState(() {
      _isLoading = false;
      _messages.add(ModelMessage(isprompt: false, message: msg, time: DateTime.now()));
    });
    _scrollDown();
  }

  // ── Role / Tone ─────────────────────────────────────────────────────────────
  void _changeRole(BotRole r) {
    setState(() => _role = r);
    _initModel();
    _snack('${r.emoji} ${r.name}', 'Role switched. Starting fresh.');
  }

  void _changeTone(BotTone t) {
    setState(() => _tone = t);
    _initModel();
    _snack('${t.emoji} ${t.name}', 'Tone updated.');
  }

  void _clearChat() {
    setState(() => _messages.clear());
    _initModel();
  }

  // ── History ────────────────────────────────────────────────────────────────
  Future<void> _saveConvo() async {
    if (_messages.isEmpty) { _snack('Nothing here', 'Start a conversation first'); return; }
    final first = _messages.firstWhere((m) => m.isprompt, orElse: () => _messages.first);
    final title = first.message.length > 42
        ? '${first.message.substring(0, 42)}…'
        : first.message;
    final c = SavedConversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      roleName: _role.name,
      roleEmoji: _role.emoji,
      savedAt: DateTime.now(),
      messages: List.from(_messages),
    );
    setState(() => _history.insert(0, c));
    await _persist();
    _snack('Saved 🔖', 'Conversation saved');
  }

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_historyKey);
      if (raw == null) return;
      setState(() {
        _history = (jsonDecode(raw) as List)
            .map((e) => SavedConversation.fromJson(e))
            .toList();
      });
    } catch (e) { debugPrint('History load error: $e'); }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_historyKey, jsonEncode(_history.map((c) => c.toJson()).toList()));
    } catch (e) { debugPrint('History save error: $e'); }
  }

  Future<void> _deleteConvo(String id) async {
    setState(() => _history.removeWhere((c) => c.id == id));
    await _persist();
  }

  void _restoreConvo(SavedConversation c) {
    final role = kRoles.firstWhere((r) => r.name == c.roleName, orElse: () => kRoles[0]);
    setState(() {
      _role = role;
      _messages..clear()..addAll(c.messages);
    });
    _initModel();
    Navigator.pop(context);
    _scrollDown();
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────
  void _snack(String title, String msg) {
    Get.snackbar(title, msg,
      backgroundColor: YO.surface2,
      colorText: YO.textPrim,
      borderColor: YO.border,
      borderWidth: 1,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      borderRadius: 14,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _copy(String msg) {
    Clipboard.setData(ClipboardData(text: msg));
    _snack('Copied ✓', 'Message copied');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YO.bg,
      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: YO.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              // Gradient ring avatar
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: YO.primaryGrad,
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: YO.surface,
                  ),
                  child: Center(
                    child: Text(_role.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('YoursOnly',
                      style: TextStyle(
                          color: YO.textPrim,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2)),
                  Text(
                    '${_role.name}  ·  ${_tone.emoji} ${_tone.name}',
                    style: const TextStyle(color: YO.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Save + History grouped
          _iconBtn(Icons.bookmark_add_outlined, 'Save', _saveConvo),
          _iconBtn(Icons.history_rounded,        'History', _showHistorySheet),
          // Settings pill — shows current role emoji + tune icon
          GestureDetector(
            onTap: _showSettingsSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: YO.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: YO.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, color: YO.purpleLight, size: 14),
                  const SizedBox(width: 4),
                  const Text('Tune', style: TextStyle(color: YO.purpleLight, fontSize: 12)),
                ],
              ),
            ),
          ),
          _iconBtn(Icons.delete_sweep_outlined, 'Clear', _confirmClear),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: YO.border),
        ),
      ),

      body: Column(
        children: [
          // ── Role strip (single row, compact) ────────────────────────────
          _buildRoleStrip(),

          // ── Messages ────────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length && _isLoading) {
                  return _buildTypingBubble();
                }
                final m = _messages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: m.isprompt
                      ? _userBubble(m.message, DateFormat('hh:mm a').format(m.time))
                      : _aiBubble(m.message, DateFormat('hh:mm a').format(m.time)),
                );
              },
            ),
          ),

          // ── Input area ──────────────────────────────────────────────────
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Icon button helper ─────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: fn,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, color: YO.textMuted, size: 21),
      ),
    ),
  );

  // ── Role strip — single horizontal row, NO tone row ───────────────────────
  // Tone lives only in the bottom-sheet to keep the header clean
  Widget _buildRoleStrip() {
    return Container(
      color: YO.surface,
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        children: kRoles.map((r) {
          final sel = _role.name == r.name;
          return GestureDetector(
            onTap: () => _changeRole(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? YO.purple.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? YO.purple : YO.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    r.name,
                    style: TextStyle(
                      color: sel ? YO.purpleLight : YO.textMuted,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    final chips = _quickChips();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing avatar
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: YO.primaryGrad,
                boxShadow: [
                  BoxShadow(
                    color: YO.purple.withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Text(_role.emoji,
                    style: const TextStyle(fontSize: 34)),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.06, duration: 2200.ms, curve: Curves.easeInOut),

            const SizedBox(height: 20),

            Text(
              _role.name == 'Companion' ? 'Someone who stays.' : 'Talking to ${_role.name}',
              style: const TextStyle(
                color: YO.textPrim,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _role.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: YO.textMuted, fontSize: 13, height: 1.55),
            ),

            const SizedBox(height: 30),

            // Divider with label
            Row(children: [
              Expanded(child: Container(height: 1, color: YO.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('start here', style: TextStyle(color: YO.textDim, fontSize: 11)),
              ),
              Expanded(child: Container(height: 1, color: YO.border)),
            ]),

            const SizedBox(height: 16),

            // Quick chips — tappable starters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: chips.map((chip) => GestureDetector(
                onTap: () {
                  _inputCtrl.text = chip;
                  _send();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: YO.surface2,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: YO.border),
                  ),
                  child: Text(chip,
                      style: const TextStyle(color: YO.textMuted, fontSize: 13)),
                ),
              )).toList(),
            ),
          ],
        ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.04, end: 0),
      ),
    );
  }

  List<String> _quickChips() {
    switch (_role.name) {
      case 'Companion':
        return ['I feel really exhausted today', 'I just need someone to listen', 'Everything feels heavy lately'];
      case 'Coder':
        return ['Explain async/await', 'Review my Flutter code', 'Best way to manage state?'];
      case 'Teacher':
        return ['Explain this concept simply', 'Give me an example', 'Quiz me on this topic'];
      case 'Coach':
        return ['I need motivation today', 'Help me set a goal', 'I keep procrastinating'];
      default:
        return ['How are you?', 'Tell me something interesting', 'I need help with something'];
    }
  }

  // ── User bubble ─────────────────────────────────────────────────────────────
  Widget _userBubble(String message, String date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: const BoxDecoration(
              gradient: YO.primaryGrad,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.45)),
                const SizedBox(height: 4),
                Text(date,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // User avatar — small circle
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: YO.surface2,
            border: Border.all(color: YO.purple.withOpacity(0.5)),
          ),
          child: const Icon(Icons.person_rounded, color: YO.purpleLight, size: 16),
        ),
      ],
    ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.05, end: 0);
  }

  // ── AI bubble ───────────────────────────────────────────────────────────────
  Widget _aiBubble(String message, String date) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Role avatar with gradient ring
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: YO.primaryGrad,
          ),
          padding: const EdgeInsets.all(1.5),
          child: Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: YO.surface),
            child: Center(
              child: Text(_role.emoji, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: YO.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: YO.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(
                        color: YO.textPrim, fontSize: 15, height: 1.5)),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            color: YO.textDim, fontSize: 11)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _copy(message),
                      child: const Icon(Icons.copy_rounded,
                          size: 13, color: YO.textDim),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 220.ms).slideX(begin: -0.05, end: 0);
  }

  // ── Animated typing indicator ─────────────────────────────────────────────
  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: YO.primaryGrad,
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: YO.surface),
              child: Center(
                child: Text(_role.emoji, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: YO.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: YO.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _dot(i)),
            ),
          ),
        ],
      ),
    );
  }

  // Bouncing dot
  Widget _dot(int i) {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) {
        // Each dot offset by 0.33 of the animation cycle
        final phase = (_dotCtrl.value + i * 0.33) % 1.0;
        // 0→0.5 = going up, 0.5→1 = going down
        final t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        final offset = -6.0 * Curves.easeInOut.transform(t);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7,
          height: 7,
          transform: Matrix4.translationValues(0, offset, 0),
          decoration: BoxDecoration(
            color: YO.purpleLight.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // ── Input area ─────────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      color: YO.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: YO.border),
          Padding(
            // Use MediaQuery safe area for bottom padding so it works on
            // notched phones AND phones without notches
            padding: EdgeInsets.fromLTRB(
                12, 10, 12,
                MediaQuery.of(context).padding.bottom + 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text field
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.18,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: YO.surface2,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: YO.border),
                      ),
                      child: TextField(
                        controller: _inputCtrl,
                        maxLines: null,
                        style: const TextStyle(color: YO.textPrim, fontSize: 15),
                        cursorColor: YO.purpleLight,
                        decoration: InputDecoration(
                          hintText: _role.name == 'Companion'
                              ? 'what\'s on your mind…'
                              : 'Ask me anything…',
                          hintStyle: const TextStyle(
                              color: YO.textDim, fontSize: 15),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send button — gradient when ready, muted when loading
                GestureDetector(
                  onTap: _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isLoading ? null : YO.primaryGrad,
                      color: _isLoading ? YO.surface2 : null,
                      border: _isLoading
                          ? Border.all(color: YO.border)
                          : null,
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: YO.purpleLight,
                            strokeWidth: 2),
                      )
                          : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 21),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings sheet — role + tone ───────────────────────────────────────────
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: YO.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: YO.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Role grid ────────────────────────────────────────────────
              const Text('Choose a role',
                  style: TextStyle(
                      color: YO.textPrim,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.55,
                children: kRoles.map((r) {
                  final sel = _role.name == r.name;
                  return GestureDetector(
                    onTap: () { setSheet(() {}); _changeRole(r); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: sel
                            ? YO.purple.withOpacity(0.15)
                            : YO.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sel ? YO.purple : YO.border,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(r.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(r.name,
                              style: TextStyle(
                                color: sel ? YO.purpleLight : YO.textMuted,
                                fontSize: 11,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Role description pill
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: YO.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: YO.border),
                ),
                child: Text(_role.subtitle,
                    style: const TextStyle(
                        color: YO.textMuted, fontSize: 12, height: 1.4)),
              ),

              const SizedBox(height: 22),

              // ── Tone chips ───────────────────────────────────────────────
              const Text('Tone of conversation',
                  style: TextStyle(
                      color: YO.textPrim,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kTones.map((t) {
                  final sel = _tone.name == t.name;
                  return GestureDetector(
                    onTap: () { setSheet(() {}); _changeTone(t); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? YO.pink.withOpacity(0.12)
                            : YO.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? YO.pink.withOpacity(0.6)
                              : YO.border,
                          width: sel ? 1.4 : 1,
                        ),
                      ),
                      child: Text(
                        '${t.emoji} ${t.name}',
                        style: TextStyle(
                          color: sel ? YO.pink : YO.textMuted,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: YO.surface2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: YO.border)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done',
                      style: TextStyle(color: YO.purpleLight, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── History sheet ───────────────────────────────────────────────────────────
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: YO.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: YO.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.history_rounded,
                    color: YO.purpleLight, size: 18),
                const SizedBox(width: 8),
                const Text('Past conversations',
                    style: TextStyle(
                        color: YO.textPrim,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const Spacer(),
                Text('${_history.length} saved',
                    style: const TextStyle(color: YO.textDim, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              Container(height: 1, color: YO.border),
              const SizedBox(height: 4),

              if (_history.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: YO.surface2,
                            border: Border.all(color: YO.border),
                          ),
                          child: const Icon(Icons.history_rounded,
                              color: YO.textDim, size: 26),
                        ),
                        const SizedBox(height: 14),
                        const Text('No saved conversations',
                            style: TextStyle(color: YO.textMuted, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Tap 🔖 to save the current chat',
                            style: TextStyle(color: YO.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    itemCount: _history.length,
                    separatorBuilder: (_, __) =>
                        Container(height: 1, color: YO.border.withOpacity(0.5)),
                    itemBuilder: (ctx, i) {
                      final c = _history[i];
                      return InkWell(
                        onTap: () => _restoreConvo(c),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13, horizontal: 4),
                          child: Row(children: [
                            // Role badge
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: YO.surface2,
                                border: Border.all(color: YO.border),
                              ),
                              child: Center(
                                child: Text(c.roleEmoji,
                                    style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: YO.textPrim,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${c.roleName}  ·  ${c.messages.length} messages  ·  '
                                        '${DateFormat('MMM d, hh:mm a').format(c.savedAt)}',
                                    style: const TextStyle(
                                        color: YO.textDim, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Delete
                            GestureDetector(
                              onTap: () {
                                _deleteConvo(c.id);
                                Navigator.pop(ctx);
                                _showHistorySheet();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.delete_outline_rounded,
                                    color: YO.textDim, size: 18),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Clear dialog ───────────────────────────────────────────────────────────
  void _confirmClear() {
    if (_messages.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: YO.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: YO.border)),
        title: const Text('Clear this chat?',
            style: TextStyle(color: YO.textPrim, fontSize: 16)),
        content: const Text(
          'This conversation will be lost.\nSave it first if you want to keep it.',
          style: TextStyle(color: YO.textMuted, fontSize: 13, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: YO.textMuted)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _clearChat(); },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}