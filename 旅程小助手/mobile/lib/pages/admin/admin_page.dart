import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/travel_api.dart';

/// 管理后台 — 长按首页标题进入
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  final _api = TravelApi();
  late TabController _tabController;

  Map<String, dynamic>? _dashboard;
  List<dynamic> _contentItems = [];
  Map<String, dynamic>? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadDashboard(), _loadContent(), _loadConfig()]);
    setState(() => _loading = false);
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await _api.get('/admin/dashboard');
      _dashboard = data as Map<String, dynamic>;
    } catch (_) {}
  }

  Future<void> _loadContent() async {
    try {
      final data = await _api.get('/admin/content');
      _contentItems = (data as Map)['items'] as List? ?? [];
    } catch (_) {}
  }

  Future<void> _loadConfig() async {
    try {
      final data = await _api.get('/admin/config');
      _config = data as Map<String, dynamic>;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理后台'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: '仪表盘'),
            Tab(icon: Icon(Icons.article), text: '内容缓存'),
            Tab(icon: Icon(Icons.settings), text: '系统配置'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(),
                _buildContent(),
                _buildConfig(),
              ],
            ),
    );
  }

  // ═══════════ 仪表盘 ═══════════
  Widget _buildDashboard() {
    final d = _dashboard ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _statCard('API 状态', _apiStatusText(d), _apiStatusIcon(d), _apiStatusColor(d)),
              const SizedBox(width: 12),
              _statCard('数据库', '${d['db_size'] ?? 'N/A'}', Icons.storage, AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('对比记录', '${d['total_comparisons'] ?? 0}', Icons.compare_arrows, AppTheme.primary),
              const SizedBox(width: 12),
              _statCard('内容缓存', '${d['total_content'] ?? 0}', Icons.article, AppTheme.accent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('聊天消息', '${d['total_chat_messages'] ?? 0}', Icons.chat, AppTheme.primary),
              const SizedBox(width: 12),
              _statCard('运行时间', '${d['uptime'] ?? 'N/A'}', Icons.timer_outlined, AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 20),
          Text('后端 API', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                _endpointRow('/api/v1/chat', 'AI 对话', 'POST'),
                _endpointRow('/api/v1/compare/destinations', '目的地对比', 'POST'),
                _endpointRow('/api/v1/compare/history', '对比历史', 'GET'),
                _endpointRow('/api/v1/itinerary/generate', '行程生成', 'POST'),
                _endpointRow('/api/v1/poi/search', 'POI 搜索', 'GET'),
                _endpointRow('/api/v1/admin/dashboard', '管理仪表盘', 'GET'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: AppTheme.caption),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTheme.body),
          const Spacer(),
          Text(value, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _endpointRow(String path, String name, String method) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: method == 'GET' ? AppTheme.secondary.withAlpha(30) : AppTheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(method, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: method == 'GET' ? AppTheme.secondary : AppTheme.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(path, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Text(name, style: AppTheme.caption),
        ],
      ),
    );
  }

  String _apiStatusText(Map d) {
    final api = d['api_status'] as Map? ?? {};
    final s = <String>[];
    if (api['deepseek'] == true) s.add('DeepSeek');
    if (api['amap'] == true) s.add('高德');
    return s.isEmpty ? '未配置' : s.join(' / ');
  }

  IconData _apiStatusIcon(Map d) {
    final api = d['api_status'] as Map? ?? {};
    return api['deepseek'] == true || api['amap'] == true ? Icons.check_circle : Icons.warning;
  }

  Color _apiStatusColor(Map d) {
    final api = d['api_status'] as Map? ?? {};
    return api['deepseek'] == true || api['amap'] == true ? AppTheme.success : AppTheme.error;
  }

  // ═══════════ 内容缓存 ═══════════
  Widget _buildContent() {
    if (_contentItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text('暂无缓存内容', style: AppTheme.body),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: _contentItems.length,
      itemBuilder: (context, index) {
        final item = _contentItems[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item['source'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item['destination'] ?? '', style: AppTheme.bodySmall)),
                  Text(item['created_at'] ?? '', style: AppTheme.caption),
                ],
              ),
              const SizedBox(height: 6),
              Text(item['title'] ?? '', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
              if (item['content'] != null) ...[
                const SizedBox(height: 4),
                Text(item['content'], style: AppTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════ 系统配置 ═══════════
  Widget _buildConfig() {
    final c = _config ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _configCard('DeepSeek', {
            '模型': c['deepseek_model'] ?? '',
            'API Key': c['deepseek_api_key'] ?? '',
          }),
          const SizedBox(height: 12),
          _configCard('高德地图', {
            'API Key': c['amap_api_key'] ?? '',
          }),
          const SizedBox(height: 12),
          _configCard('系统', {
            '数据库路径': c['database_path'] ?? '',
            '监听地址': '${c['host'] ?? ""}:${c['port'] ?? ""}',
            '调试模式': c['debug'] == true ? '开启' : '关闭',
          }),
        ],
      ),
    );
  }

  Widget _configCard(String title, Map<String, String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingMedium),
          const SizedBox(height: 12),
          ...items.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 80, child: Text(e.key, style: AppTheme.caption)),
                Expanded(child: Text(e.value, style: AppTheme.bodySmall.copyWith(fontFamily: 'monospace'))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
