import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/poi.dart';
import '../../services/travel_api.dart';
import '../../services/voice_service.dart';
import '../admin/admin_page.dart';

/// 首页 — 极简三段式 + 历史对话 + AI 回复收藏
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = TravelApi();
  final _storage = LocalStorage();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _loading = false;
  bool _isListening = false;
  int _waitSec = 0; // 等待秒数
  String _displayBuffer = ''; // 流式缓冲，防频繁 setState
  int _streamTokenCount = 0;

  // 对话管理
  String _currentConvId = '';
  List<Map<String, dynamic>> _conversations = [];

  // 收藏
  List<Map<String, String>> _savedReplies = [];

  static const _suggestions = [
    '🏛️  北京 · 三日文化之旅',
    '🏖️  三亚 · 海边度假攻略',
    '🍜  成都 · 美食地图推荐',
    '🗺️  云南 · 自由行路线规划',
  ];

  @override
  void initState() { super.initState(); _loadHistory(); }

  // ═══════════════ 数据 ═══════════════

  Future<void> _loadHistory() async {
    // 生成或恢复对话 ID
    final storedId = await _storage.getDeviceId();
    _currentConvId = 'conv_${storedId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final h = await _api.getChatHistory();
      if (h != null && h.isNotEmpty) { if (!mounted) return; _onHistoryLoaded(h); return; }
    } catch (_) {}
    final h = await _storage.getChatHistory();
    if (!mounted) return;
    _onHistoryLoaded(h);
  }

  void _onHistoryLoaded(List<Map<String, String>> h) {
    setState(() => _messages = h.isNotEmpty ? h : [
      {'role': 'assistant', 'content': '你好！我是旅程小助手 ✈️\n告诉我你想去哪里玩，我来帮你规划行程！'},
    ]);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() { _messages.add({'role': 'user', 'content': text}); _loading = true; _waitSec = 0; _messages.add({'role': 'assistant', 'content': ''}); });
    _controller.clear();
    // 启动等待计时器（仅用于显示等待时长，不干扰流式）
    final waitTimer = Stream.periodic(const Duration(seconds: 1), (i) => i + 1).take(60).listen((s) {
      if (mounted && _loading) setState(() => _waitSec = s);
    });

    final apiMsgs = _messages.where((m) => m['role'] == 'user' || m['role'] == 'assistant').map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
    String accumulated = '';
    _displayBuffer = '';
    _streamTokenCount = 0;

    // 启动渲染定时器：每 50ms 刷新一次 UI，避免每个 token 都 setState
    final renderTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => _messages.last['content'] = _displayBuffer);
      _scrollTo(instant: true);
    });

    bool streamOk = false;
    try {
      await for (final t in _api.chatStream(apiMsgs)) {
        accumulated += t;
        _displayBuffer = accumulated;
        _streamTokenCount++;
        streamOk = true;
      }
    } catch (_) {}
    renderTimer.cancel();
    if (mounted) setState(() => _messages.last['content'] = accumulated);
    if (!streamOk) {
      try {
        accumulated = await _api.chat(apiMsgs);
        setState(() => _messages.last['content'] = accumulated);
      } catch (e) {
        setState(() => _messages.last['content'] = e.toString().contains('超时') ? '😅 AI 思考太久了，重新试试？' : '🤔 网络出了点问题，重新发送？');
      }
    }

    setState(() => _loading = false);
    waitTimer.cancel();
    await _storage.saveChatHistory(_messages);
    _saveConversation(); // 静默保存到后端
    _scrollTo();
  }

  Future<void> _saveConversation() async {
    await _api.saveConversation(_currentConvId, _messages);
  }

  Future<void> _newConversation() async {
    // 保存当前对话
    if (_messages.length > 1) {
      await _api.saveConversation(_currentConvId, _messages);
    }
    // 生成新 ID 并重置
    final storedId = await _storage.getDeviceId();
    if (!mounted) return;
    setState(() {
      _currentConvId = 'conv_${storedId.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';
      _messages = [{'role': 'assistant', 'content': '你好！我是旅程小助手 ✈️\n告诉我你想去哪里玩，我来帮你规划行程！'}];
    });
    await _storage.saveChatHistory(_messages);
  }

  Future<void> _loadConversation(String convId) async {
    final msgs = await _api.getConversation(convId);
    if (msgs == null || msgs.isEmpty) return;
    // 保存当前对话
    if (_messages.length > 1) await _api.saveConversation(_currentConvId, _messages);
    if (!mounted) return;
    setState(() {
      _currentConvId = convId;
      _messages = msgs;
    });
    await _storage.saveChatHistory(msgs);
    Navigator.pop(context); // 关闭历史面板
  }

  Future<void> _deleteConversation(String convId) async {
    await _api.deleteConversation(convId);
    await _loadConversationList();
  }

  Future<void> _loadConversationList() async {
    final list = await _api.getConversations();
    if (!mounted) return;
    setState(() => _conversations = list);
  }

  void _scrollTo({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (instant) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      else _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('清空对话'), content: const Text('确定要清空当前对话吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空', style: TextStyle(color: AppTheme.error))),
      ],
    ));
    if (ok != true) return;
    await _storage.saveChatHistory([]); await _api.deleteConversation(_currentConvId);
    if (!mounted) return;
    setState(() => _messages = [{'role': 'assistant', 'content': '你好！我是旅程小助手 ✈️\n告诉我你想去哪里玩，我来帮你规划行程！'}]);
  }

  // ═══════════════ 收藏 ═══════════════

  Future<void> _toggleBookmark(String content) async {
    final saved = await _storage.getSavedReplies();
    final exists = saved.any((i) => i['content'] == content);
    if (exists) {
      final idx = saved.indexWhere((i) => i['content'] == content);
      await _storage.deleteReply(idx);
      if (mounted) _showSnack('已取消收藏');
    } else {
      await _storage.saveReply(content);
      if (mounted) _showSnack('已收藏该回复');
    }
    if (mounted) setState(() => _savedReplies = saved);
  }

  Future<void> _loadSavedReplies() async {
    final saved = await _storage.getSavedReplies();
    if (mounted) setState(() => _savedReplies = saved);
  }

  // ═══════════════ 构建 ═══════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(gradient: AppTheme.horizonGradient, borderRadius: BorderRadius.circular(2))),
        Expanded(child: _buildBody()),
        _buildInput(),
      ])),
    );
  }

  // ═══════════════ 1. 固定品牌头部 + 功能按钮 ═══════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onLongPress: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPage())),
            child: ShaderMask(
              shaderCallback: (bounds) => AppTheme.horizonGradient.createShader(bounds),
              child: const Text('旅程小助手', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, fontFamily: 'serif', color: Colors.white, letterSpacing: 4, height: 1.1)),
            ),
          ),
        ),
        // 历史对话
        _headerBtn(Icons.history, '历史对话', _showHistoryPanel),
        // 收藏
        _headerBtn(Icons.bookmark_outline, '收藏回复', _showBookmarkPanel),
        // 新对话
        _headerBtn(Icons.add_circle_outline, '新对话', _newConversation),
        if (_messages.length > 1)
          IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppTheme.textHint), onPressed: _clearHistory, splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30, minHeight: 36)),
      ]),
    );
  }

  Widget _headerBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, size: 20, color: AppTheme.textSecondary), onPressed: onTap, tooltip: tooltip, splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  // ═══════════════ 2. 内容 ═══════════════

  Widget _buildBody() {
    final isWelcome = _messages.length == 1 && _messages[0]['role'] == 'assistant';
    return isWelcome ? _buildWelcome() : _buildChat();
  }

  // ── 欢迎态 ──

  Widget _buildWelcome() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: [
        const Text('想去哪里？', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.1)),
        const SizedBox(height: 6),
        const Text('告诉我你的旅行想法', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.3)),
        const SizedBox(height: 36),
        ..._suggestions.map((s) => _buildSuggestion(s)),
        const SizedBox(height: 32),
        Center(
          child: Text('在下方输入目的地开始规划', style: TextStyle(fontSize: 12, color: AppTheme.textHint.withAlpha(80))),
        ),
      ],
    );
  }

  Widget _buildSuggestion(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () { _controller.text = text; _sendMessage(); },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(children: [
              Text(text, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary, height: 1.4)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: AppTheme.textHint.withAlpha(60)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 对话态 ──

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loading && i == _messages.length) return _buildTyping();
        final msg = _messages[i];
        return _buildBubble(msg['content'] ?? '', msg['role'] == 'user');
      },
    );
  }

  Widget _buildRichText(String text, {Color? color, double fontSize = 14}) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(text: parts[i], style: TextStyle(fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400, fontSize: fontSize, color: color ?? AppTheme.textPrimary, height: 1.5)));
    }
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color ?? AppTheme.textPrimary, height: 1.5)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(width: 26, height: 26, decoration: BoxDecoration(gradient: AppTheme.horizonGradient, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.explore, size: 14, color: Colors.white)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(isUser ? 14 : 2), bottomRight: Radius.circular(isUser ? 2 : 14)),
                boxShadow: [BoxShadow(color: const Color(0xFF2C2416).withAlpha(8), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                isUser
                  ? Text(text, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white))
                  : _buildRichText(text),
                // 非用户消息：收藏 + 导出（醒目按钮）
                if (!isUser && text.isNotEmpty && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      // 收藏按钮
                      Material(
                        color: AppTheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _toggleBookmark(text),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.bookmark_border, size: 16, color: AppTheme.primary),
                              SizedBox(width: 3),
                              Text('收藏', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 导出按钮
                      Material(
                        color: AppTheme.secondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showExportOptions(text),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.download_outlined, size: 16, color: AppTheme.secondary),
                              SizedBox(width: 3),
                              Text('导出', style: TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.w500)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(width: 26, height: 26, decoration: BoxDecoration(color: AppTheme.accent.withAlpha(25), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.person, size: 14, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildTyping() {
    final tip = _waitSec < 3 ? '思考中' : _waitSec < 10 ? '思考中 ${_waitSec}s' : '生成中 ${_waitSec}s';
    return Padding(
      padding: const EdgeInsets.only(left: 34, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: const Color(0xFF2C2416).withAlpha(8), blurRadius: 12, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(), const SizedBox(width: 3), _dot(), const SizedBox(width: 3), _dot()]),
        ),
        const SizedBox(width: 8),
        Text(tip, style: AppTheme.caption),
      ]),
    );
  }

  Widget _dot() => Container(width: 5, height: 5, decoration: BoxDecoration(color: AppTheme.primary.withAlpha(120), shape: BoxShape.circle));

  // ═══════════════ 3. 浮动输入 ═══════════════

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider.withAlpha(50)),
          boxShadow: [BoxShadow(color: const Color(0xFF2C2416).withAlpha(10), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(children: [
          if (VoiceService.isSupported) _iconBtn(_isListening ? Icons.mic : Icons.mic_none, _isListening ? AppTheme.error : AppTheme.textHint, _onVoiceTap),
          Expanded(
            child: TextField(
              controller: _controller, textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: '输入目的地...', hintStyle: TextStyle(color: AppTheme.textHint),
                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10), isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          _iconBtn(Icons.place_outlined, AppTheme.textHint, _showPoiSearch),
          const SizedBox(width: 2),
          Material(
            color: _loading ? Colors.grey[200]! : AppTheme.primary,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: _loading ? null : _sendMessage,
              child: Container(width: 36, height: 36, alignment: Alignment.center, child: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textHint))
                : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 19, color: color))));
  }

  // ═══════════════ 历史对话面板 ═══════════════

  void _showHistoryPanel() async {
    await _loadConversationList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, ss) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              const Text('历史对话', style: AppTheme.headingMedium),
              const Spacer(),
              Text('${_conversations.length} 条', style: AppTheme.caption),
            ]),
            const SizedBox(height: 12),
            if (_conversations.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('暂无历史对话', style: TextStyle(color: AppTheme.textSecondary)))),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _conversations.length,
                itemBuilder: (context, i) {
                  final conv = _conversations[i];
                  final title = (conv['title'] as String? ?? '新建对话');
                  final count = conv['message_count'] ?? 0;
                  final updated = (conv['updated_at'] as String? ?? '').substring(0, 10);
                  final isActive = conv['id'] == _currentConvId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primary.withAlpha(10) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? AppTheme.primary.withAlpha(50) : AppTheme.divider.withAlpha(40)),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? AppTheme.primary : AppTheme.textPrimary)),
                      subtitle: Text('$count 条消息 · $updated', style: AppTheme.caption),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textHint),
                        onPressed: () => _deleteConversation(conv['id'] as String).then((_) => ss(() {})),
                      ),
                      onTap: () => _loadConversation(conv['id'] as String),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ═══════════════ 收藏面板 ═══════════════

  void _showBookmarkPanel() async {
    await _loadSavedReplies();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, ss) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              const Text('收藏回复', style: AppTheme.headingMedium),
              const Spacer(),
              Text('${_savedReplies.length} 条', style: AppTheme.caption),
            ]),
            const SizedBox(height: 12),
            if (_savedReplies.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('暂无收藏', style: TextStyle(color: AppTheme.textSecondary)))),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _savedReplies.length,
                itemBuilder: (context, i) {
                  final item = _savedReplies[i];
                  final content = item['content'] ?? '';
                  final savedAt = (item['saved_at'] ?? '').substring(0, 10);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider.withAlpha(40))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(content, style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary), maxLines: 4, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text(savedAt, style: AppTheme.caption),
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            await _storage.deleteReply(i);
                            await _loadSavedReplies();
                            ss(() {});
                            _showSnack('已删除');
                          },
                          child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textHint),
                        ),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ═══════════════ 导出文档 ═══════════════

  void _showExportOptions(String text) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('导出文档', style: AppTheme.headingMedium),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.description, color: AppTheme.primary, size: 20)),
            title: const Text('Word 文档', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('.doc 格式，可编辑', style: TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _exportDocument(text, 'doc'); },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.picture_as_pdf, color: AppTheme.secondary, size: 20)),
            title: const Text('PDF 文档', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: const Text('.pdf 格式，适合分享', style: TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _exportDocument(text, 'pdf'); },
          ),
        ]),
      ),
    );
  }

  void _exportDocument(String text, String format) {
    // 将 **加粗** 转为 HTML <strong>
    String htmlContent = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m[1]}</strong>');
    // 换行转 <br>
    htmlContent = htmlContent.replaceAll('\n', '<br>');

    final fullHtml = '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>旅程小助手 - 旅行规划</title>
<style>
  @page { margin: 2cm; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "PingFang SC", "Microsoft YaHei", "Noto Sans SC", sans-serif;
    color: #2C2416;
    line-height: 1.8;
    padding: 40px;
    max-width: 800px;
    margin: 0 auto;
  }
  .header {
    border-bottom: 3px solid transparent;
    border-image: linear-gradient(90deg, #C66B3D, #C08E3A, #8B9D83) 1;
    padding-bottom: 12px;
    margin-bottom: 24px;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .header h1 {
    font-size: 24px;
    font-weight: 700;
    letter-spacing: 2px;
    background: linear-gradient(135deg, #C66B3D, #8B9D83);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .header span { font-size: 20px; }
  .content { font-size: 14px; }
  .content strong { color: #C66B3D; }
  .footer {
    margin-top: 40px;
    padding-top: 16px;
    border-top: 1px solid #D6C9B8;
    font-size: 11px;
    color: #B08B6E;
    text-align: center;
  }
</style>
</head>
<body>
  <div class="header">
    <span>✈️</span>
    <h1>旅程小助手</h1>
  </div>
  <div class="content">$htmlContent</div>
  <div class="footer">由 旅程小助手 AI 生成 · ${DateTime.now().year}</div>
</body>
</html>
''';

    final blob = html.Blob([fullHtml], format == 'pdf' ? 'text/html' : 'application/msword');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final ext = format == 'pdf' ? 'html' : 'doc';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '旅程规划_${DateTime.now().millisecondsSinceEpoch}.$ext')
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    _showSnack('已下载 .$ext 文件');
  }

  // ═══════════════ POI 搜索 ═══════════════

  void _showPoiSearch() {
    final ctrl = TextEditingController();
    List<PoiItem>? results;
    bool loading = false;
    String err = '';

    void doSearch(String kw, void Function(void Function()) ss) {
      if (kw.isEmpty) return;
      ss(() { loading = true; err = ''; results = null; });
      _api.searchPoi(keywords: kw).then((r) => ss(() { results = r.pois; loading = false; })).catchError((_) => ss(() { loading = false; err = '搜索失败'; }));
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (context, ss) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16), const Text('搜索周边', style: AppTheme.headingMedium), const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: '如：火锅、景点、酒店...', prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: loading ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(icon: const Icon(Icons.send, size: 18), onPressed: () => doSearch(ctrl.text.trim(), ss)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onSubmitted: (v) => doSearch(v.trim(), ss),
          ),
          const SizedBox(height: 12),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(err, style: const TextStyle(color: AppTheme.error))),
          if (results != null)
            results!.isEmpty
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('未找到结果', style: TextStyle(color: AppTheme.textSecondary))))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true, itemCount: results!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = results![i];
                      return ListTile(
                        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.place, color: AppTheme.primary, size: 18)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('${p.address} · ${p.type}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(icon: const Icon(Icons.open_in_new, size: 16), onPressed: () => html.window.open(p.mapUrl, '_blank')),
                        onTap: () => html.window.open(p.mapUrl, '_blank'),
                      );
                    },
                  ),
                ),
        ]),
      )),
    );
  }

  // ═══════════════ 语音 ═══════════════

  Future<void> _onVoiceTap() async {
    if (_isListening) { VoiceService.stopListening(); setState(() => _isListening = false); return; }
    setState(() => _isListening = true);
    try {
      final text = await VoiceService.startListening();
      if (text.isNotEmpty && mounted) { _controller.text = text; _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length)); }
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
