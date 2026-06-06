import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/compare.dart';
import '../../models/itinerary.dart';
import '../../services/travel_api.dart';
import '../../widgets/compare_table_widget.dart';
import '../../widgets/radar_chart_widget.dart';
import '../../widgets/itinerary_card.dart';

/// 目的地对比页 - 带画像、记忆、评分
class ComparePage extends StatefulWidget {
  const ComparePage({super.key});

  @override
  State<ComparePage> createState() => ComparePageState();
}

class ComparePageState extends State<ComparePage> with SingleTickerProviderStateMixin {
  final _api = TravelApi();
  final _storage = LocalStorage();
  late TabController _tabController;

  // 对比相关
  final List<TextEditingController> _destControllers = [
    TextEditingController(text: '成都'),
    TextEditingController(text: '重庆'),
  ];
  CompareResult? _compareResult;
  bool _comparing = false;
  String _compareStatus = ''; // 流式对比状态文本

  // 用户画像
  String _purpose = 'leisure';
  String _withWho = 'alone';
  bool _withPet = false;
  String _travelStyle = 'free';
  String _budgetLevel = 'medium';
  int _travelDays = 3;
  String _preferredSeason = ''; // 偏好季节
  final _specialNeedsController = TextEditingController(); // 特殊需求

  // 历史记录
  List<CompareHistoryItem> _history = [];
  bool _loadingHistory = false;

  // 出发日期
  DateTime _departureDate = DateTime.now().add(const Duration(days: 30));

  // 行程生成相关
  final _itineraryDestController = TextEditingController(text: '成都');
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  int _itineraryDays = 1;
  int _activeDay = 0;
  Itinerary? _itinerary;
  bool _generating = false;
  String _itineraryStatus = ''; // 流式行程状态文本
  List<Map<String, dynamic>> _streamingDayPlans = []; // 流式已收到的 day 数据
  bool _itinerarySaved = false; // 当前行程是否已收藏

  /// 供父级调用：刷新历史对比列表
  void refreshHistory() {
    if (_tabController.index == 2 || _tabController.index == 0) _loadHistory();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
      if (_tabController.index == 2) _loadHistory();
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      _history = await _api.getCompareHistory();
    } catch (_) {}
    setState(() => _loadingHistory = false);
  }

  Future<void> _doCompare() async {
    final destinations = _destControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    if (destinations.length < 2) {
      _showSnack('请至少输入 2 个目的地');
      return;
    }

    setState(() { _comparing = true; _compareResult = null; _compareStatus = '正在准备...'; });

    // 先尝试流式，失败则降级到非流式
    bool streamOk = false;
    try {
      final departureDateStr = DateFormat('yyyy-MM-dd').format(_departureDate);
      await for (final event in _api.compareStream(
        destinations: destinations,
        travelDays: _travelDays,
        budgetLevel: _budgetLevel,
        purpose: _purpose,
        withWho: _withWho,
        withPet: _withPet,
        travelStyle: _travelStyle,
        preferredSeason: _preferredSeason,
        specialNeeds: _specialNeedsController.text.trim(),
        departureDate: departureDateStr,
      )) {
        final type = event['type'] as String?;
        if (type == 'status') {
          setState(() => _compareStatus = event['text'] as String? ?? '');
        } else if (type == 'weather') {
          final weatherData = event['data'] as List? ?? [];
          setState(() {
            _compareResult ??= CompareResult(table: CompareTable(headers: [''], rows: []), recommendation: '', verdict: '', scores: []);
            _compareResult = CompareResult(
              table: _compareResult!.table,
              recommendation: _compareResult!.recommendation,
              verdict: _compareResult!.verdict,
              scores: _compareResult!.scores,
              weather: weatherData.map((e) => WeatherInfo.fromJson(e as Map<String, dynamic>)).toList(),
            );
          });
        } else if (type == 'complete') {
          streamOk = true;
          final data = event['data'] as Map<String, dynamic>? ?? {};
          final rowsRaw = (data['rows'] as List?) ?? [];
          final headers = ['维度', ...destinations];
          final rows = rowsRaw.map((r) => CompareRow(
            dimension: r['dimension'] ?? '',
            values: (r['values'] as List?)?.cast<String>() ?? [],
            detail: r['detail'] as String? ?? '',
          )).toList();
          final scoresRaw = data['scores'] as List? ?? [];
          final scores = scoresRaw.map((s) => DestinationScore(
            destination: s['destination'] ?? '',
            overall: (s['overall'] ?? 0).toDouble(),
            details: Map<String, double>.from((s['details'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ?? {}),
          )).toList();

          setState(() {
            _compareResult = CompareResult(
              table: CompareTable(headers: headers, rows: rows),
              recommendation: data['recommendation'] ?? '',
              verdict: data['verdict'] ?? '',
              scores: scores,
              weather: _compareResult?.weather ?? [],
            );
            _compareStatus = '';
          });
        }
      }
    } catch (_) {}

    // 流式失败 → 非流式降级
    if (!streamOk) {
      try {
        final departureDateStr = DateFormat('yyyy-MM-dd').format(_departureDate);
        final result = await _api.compareDestinations(
          destinations: destinations,
          travelDays: _travelDays,
          budgetLevel: _budgetLevel,
          purpose: _purpose,
          withWho: _withWho,
          withPet: _withPet,
          travelStyle: _travelStyle,
          preferredSeason: _preferredSeason,
          specialNeeds: _specialNeedsController.text.trim(),
          departureDate: departureDateStr,
        );
        setState(() => _compareResult = result);
      } catch (e) {
        _showSnack('对比失败：$e');
      }
    }

    // 对比完成 → 刷新历史列表
    _loadHistory();

    setState(() { _comparing = false; _compareStatus = ''; });
  }

  Future<void> _generateItinerary() async {
    final dest = _itineraryDestController.text.trim();
    if (dest.isEmpty) {
      _showSnack('请输入目的地');
      return;
    }
    setState(() { _generating = true; _itinerary = null; _activeDay = 0; _streamingDayPlans = []; _itinerarySaved = false; _itineraryStatus = '正在准备...'; });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 先尝试流式
    bool streamOk = false;
    try {
      await for (final event in _api.generateItineraryStream(
        destination: dest, date: dateStr,
        preferences: ['美食', '历史文化'],
        days: _itineraryDays, withPet: _withPet,
      )) {
        final type = event['type'] as String?;
        if (type == 'status') {
          setState(() => _itineraryStatus = event['text'] as String? ?? '');
        } else if (type == 'day') {
          // 收到一天的数据
          final dayData = event['data'] as Map<String, dynamic>?;
          if (dayData != null) {
            setState(() {
              _streamingDayPlans.add(dayData);
              // 若有多天则显示最新进度
              _itineraryStatus = '已生成 ${_streamingDayPlans.length}/$_itineraryDays 天';
            });
          }
        } else if (type == 'items') {
          // 单日行程，收到一批 items
          final itemsData = event['data'] as List? ?? [];
          setState(() => _itineraryStatus = '已收到 ${itemsData.length} 个行程点');
        } else if (type == 'complete') {
          streamOk = true;
          final data = event['data'] as Map<String, dynamic>?;
          if (data != null) {
            setState(() {
              _itinerary = Itinerary.fromJson(data);
              _streamingDayPlans = [];
              _itineraryStatus = '';
            });
          }
        }
      }
    } catch (_) {}

    // 流式失败 → 非流式降级
    if (!streamOk) {
      try {
        final result = await _api.generateItinerary(
          destination: dest, date: dateStr,
          preferences: ['美食', '历史文化'],
          days: _itineraryDays, withPet: _withPet,
        );
        setState(() => _itinerary = result);
      } catch (e) {
        _showSnack('行程生成失败：$e');
      }
    }

    setState(() { _generating = false; _itineraryStatus = ''; _streamingDayPlans = []; });
  }

  Future<void> _toggleSaveItinerary() async {
    if (_itinerary == null) return;
    final trip = SavedTrip.fromItinerary(_itinerary!);
    if (_itinerarySaved) {
      await _storage.deleteTrip(trip.id);
      setState(() => _itinerarySaved = false);
      _showSnack('已取消收藏');
    } else {
      await _storage.saveTrip(trip);
      setState(() => _itinerarySaved = true);
      _showSnack('已收藏到「我的行程」');
    }
  }

  void _addDestination() {
    if (_destControllers.length >= 5) { _showSnack('最多对比 5 个目的地'); return; }
    setState(() => _destControllers.add(TextEditingController()));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── 历史对比明细 ──
  Future<void> _showHistoryDetail(String compId, String title) async {
    showDialog(
      context: context,
      builder: (ctx) => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    try {
      final detail = await _api.getCompareHistoryDetail(compId);
      if (!mounted) return;
      Navigator.pop(context); // 关掉 loading

      final result = detail['result'] as Map<String, dynamic>? ?? {};
      final rowsRaw = result['rows'] as List? ?? [];
      final recommendation = result['recommendation'] as String? ?? '';
      final verdict = result['verdict'] as String? ?? '';
      final scoresRaw = result['scores'] as List? ?? [];

      if (rowsRaw.isEmpty && recommendation.isEmpty) {
        _showSnack('该记录是旧版对比，无详细数据，请重新对比');
        return;
      }

      _showDetailDialog(title, rowsRaw, recommendation, verdict, scoresRaw);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('加载明细失败：$e');
    }
  }

  void _showDetailDialog(String title, List rowsRaw, String recommendation, String verdict, List scoresRaw) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.compare_arrows, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 评分
                      if (scoresRaw.isNotEmpty) ...[
                        const Text('综合评分', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: Row(
                            children: scoresRaw.map((s) {
                              final dest = s['destination'] ?? '';
                              final overall = ((s['overall'] ?? 0) as num).toDouble();
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(dest, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(overall.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: overall >= 4 ? AppTheme.primary : AppTheme.accent)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 结论
                      if (verdict.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF7A45), Color(0xFFFF5A4F)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AI 结论', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text(verdict, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                              if (recommendation.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(recommendation, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 对比表格
                      if (rowsRaw.isNotEmpty) ...[
                        const Text('详细对比', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Table(
                          border: TableBorder.all(color: AppTheme.divider, borderRadius: BorderRadius.circular(8)),
                          columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(2)},
                          children: [
                            ...rowsRaw.map((row) {
                              final dim = row['dimension'] ?? '';
                              final vals = (row['values'] as List?)?.cast<String>() ?? [];
                              return TableRow(
                                decoration: BoxDecoration(color: rowsRaw.indexOf(row) % 2 == 0 ? Colors.white : AppTheme.background),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(dim, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(vals.join('  |  '), style: const TextStyle(fontSize: 13, height: 1.4)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 导出 ──
  Future<void> _copyItinerary() async {
    if (_itinerary == null) return;
    await Clipboard.setData(ClipboardData(text: _formatItineraryText(_itinerary!)));
    if (mounted) _showSnack('已复制到剪贴板');
  }

  void _downloadItinerary() {
    if (_itinerary == null) return;
    final text = _formatItineraryText(_itinerary!);
    final uri = Uri.dataFromString(text, mimeType: 'text/plain', encoding: utf8);
    final anchor = html.AnchorElement(href: uri.toString())
      ..setAttribute('download', '${_itinerary!.destination}_行程.txt')
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
  }

  void _viewOnMap() {
    if (_itinerary == null) return;
    final dest = Uri.encodeComponent(_itinerary!.destination);
    html.window.open('https://ditu.amap.com/search?query=$dest', '_blank');
  }

  String _formatItineraryText(Itinerary it) {
    final buf = StringBuffer();
    buf.writeln('=== $it.title ===');
    buf.writeln('目的地：${it.destination}');
    buf.writeln('');
    if (it.hasMultiDay) {
      for (final plan in it.dayPlans) {
        buf.writeln('【${plan.title}】${plan.date}'); buf.writeln('---');
        for (final item in plan.items) {
          buf.writeln('${item.time} ${item.name}（${item.typeLabel}）');
          if (item.address.isNotEmpty) buf.writeln('  地址：${item.address}');
          buf.writeln('  时长：${item.durationMinutes}分钟');
          if (item.tips.isNotEmpty) buf.writeln('  提示：${item.tips}');
          buf.writeln('');
        }
        if (plan.summary.isNotEmpty) buf.writeln('总结：${plan.summary}\n');
      }
    } else {
      for (final item in it.items) {
        buf.writeln('${item.time} ${item.name}（${item.typeLabel}）');
        if (item.address.isNotEmpty) buf.writeln('  地址：${item.address}');
        buf.writeln('  时长：${item.durationMinutes}分钟');
        if (item.tips.isNotEmpty) buf.writeln('  提示：${item.tips}');
        buf.writeln('');
      }
    }
    if (it.summary.isNotEmpty) buf.writeln('总结：${it.summary}');
    return buf.toString();
  }

  // ── 删除对比历史 ──
  Future<void> _deleteHistoryItem(String compId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除记录'),
        content: const Text('确定要删除这条对比历史吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.deleteCompareHistory(compId);
        await _loadHistory();
        if (mounted) _showSnack('已删除');
      } catch (e) {
        if (mounted) _showSnack('删除失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目的地对比'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.white.withAlpha(200),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: '表格对比'),
                Tab(text: '单日行程'),
                Tab(text: '历史对比'),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: [_buildCompareTab(), _buildItineraryTab(), _buildHistoryTab()],
      ),
    );
  }

  // ═══════════════════ 对比 Tab ═══════════════════
  Widget _buildCompareTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildDestInputCard(),
          const SizedBox(height: 20),
          if (_compareResult != null) _buildResultSection(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('你的旅行画像', style: AppTheme.headingMedium),
            ],
          ),
          const SizedBox(height: 16),
          // 第一行：目的 + 预算
          Row(
            children: [
              Expanded(child: _buildDropdown('旅行目的', _purpose, TravelProfile.purposes, (v) => _purpose = v)),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('预算', _budgetLevel, {'low': '经济省钱', 'medium': '适中', 'high': '高端舒适'}, (v) => _budgetLevel = v)),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：同谁 + 风格
          Row(
            children: [
              Expanded(child: _buildDropdown('和谁去', _withWho, TravelProfile.withWho, (v) => _withWho = v)),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown('旅行风格', _travelStyle, TravelProfile.styles, (v) => _travelStyle = v)),
            ],
          ),
          const SizedBox(height: 12),
          // 宠物开关
          Row(
            children: [
              Icon(Icons.pets, size: 20, color: _withPet ? AppTheme.primary : AppTheme.textHint),
              const SizedBox(width: 8),
              const Text('带宠物出行', style: AppTheme.body),
              const Spacer(),
              Switch(
                value: _withPet,
                onChanged: (v) => setState(() => _withPet = v),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 天数
          Row(
            children: [
              const Icon(Icons.date_range, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('天数', style: AppTheme.body),
              const Spacer(),
              SizedBox(
                width: 200,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1天')),
                    ButtonSegment(value: 3, label: Text('3天')),
                    ButtonSegment(value: 5, label: Text('5天')),
                    ButtonSegment(value: 7, label: Text('7天')),
                  ],
                  selected: {_travelDays},
                  onSelectionChanged: (v) => setState(() => _travelDays = v.first),
                  style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 出发日期
          Row(
            children: [
              const Icon(Icons.flight_takeoff, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('出发日期', style: AppTheme.body),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context, initialDate: _departureDate,
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary)), child: child!),
                  );
                  if (picked != null) setState(() => _departureDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('MM月dd日').format(_departureDate), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                      const SizedBox(width: 4),
                      Text(DateFormat('E').format(_departureDate), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 偏好季节
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('偏好季节', style: AppTheme.body),
              const Spacer(),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _preferredSeason.isEmpty ? null : _preferredSeason,
                  hint: const Text('不限', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
                  items: const [
                    DropdownMenuItem(value: '春季', child: Text('春季 3-5月', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '夏季', child: Text('夏季 6-8月', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '秋季', child: Text('秋季 9-11月', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: '冬季', child: Text('冬季 12-2月', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _preferredSeason = v ?? ''),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 特殊需求
          TextField(
            controller: _specialNeedsController,
            decoration: InputDecoration(
              hintText: '特殊需求（如：不想爬山、带老人、轮椅友好...）',
              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              prefixIcon: const Icon(Icons.edit_note, size: 18, color: AppTheme.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: (v) { if (v != null) setState(() => onChanged(v)); },
    );
  }

  Widget _buildDestInputCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.compare_arrows, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('选择对比目的地', style: AppTheme.headingMedium),
            ],
          ),
          const SizedBox(height: 16),
          ..._destControllers.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28, alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                    child: Text('${entry.key + 1}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        hintText: '输入目的地名称',
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.primary.withAlpha(120), size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.divider)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  if (_destControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: AppTheme.error, size: 22),
                      onPressed: () { setState(() { entry.value.dispose(); _destControllers.removeAt(entry.key); }); },
                    ),
                ],
              ),
            );
          }),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addDestination,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加目的地'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _comparing ? null : _doCompare,
                child: _comparing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('开始深度对比'),
              ),
            ],
          ),
          if (_compareStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(_compareStatus, style: AppTheme.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 评分卡片 + 雷达图
        if (_compareResult!.scores.isNotEmpty) _buildScoreSection(),
        const SizedBox(height: 16),
        // 操作按钮
        _buildResultActions(),
        const SizedBox(height: 16),
        // 最终结论
        if (_compareResult!.verdict.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF7A45), Color(0xFFFF5A4F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('AI 最终结论', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_compareResult!.verdict, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(_compareResult!.recommendation, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        // 实时天气
        if (_compareResult!.weather.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('实时天气', style: AppTheme.headingMedium),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _compareResult!.weather.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final w = _compareResult!.weather[i];
                final icon = w.weather.contains('雨') ? Icons.water_drop : w.weather.contains('云') ? Icons.cloud : Icons.wb_sunny;
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider.withAlpha(50)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(w.city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${w.temperature}°C', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    Text(w.weather, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('详细对比', style: AppTheme.headingMedium),
        const SizedBox(height: 10),
        CompareTableWidget(table: _compareResult!.table),
      ],
    );
  }

  Widget _buildResultActions() {
    final bestDest = _findBestDestination();
    return Row(
      children: [
        if (bestDest != null)
          Expanded(
            child: _actionBtn(
              icon: Icons.route,
              label: '合并到「$bestDest」行程',
              color: const Color(0xFF4CAF50),
              onTap: _mergeToItinerary,
            ),
          ),
        if (bestDest != null) const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            icon: Icons.description_outlined,
            label: '导出对比报告',
            color: AppTheme.primary,
            onTap: _exportCompareReport,
          ),
        ),
      ],
    );
  }

  String? _findBestDestination() {
    if (_compareResult == null || _compareResult!.scores.isEmpty) return null;
    final best = _compareResult!.scores
        .reduce((a, b) => a.overall >= b.overall ? a : b);
    return best.destination;
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }

  void _mergeToItinerary() {
    final best = _findBestDestination();
    if (best == null) return;
    _itineraryDestController.text = best;
    _tabController.animateTo(1);
    _showSnack('已填入「$best」，点击生成行程');
  }

  void _exportCompareReport() {
    if (_compareResult == null) return;
    final r = _compareResult!;

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">');
    buf.writeln('<title>目的地对比报告</title>');
    buf.writeln('''
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: "PingFang SC","Microsoft YaHei",sans-serif; color:#2C2416; padding:40px; max-width:900px; margin:0 auto; line-height:1.8; }
  h1 { font-size:26px; border-bottom:3px solid #C66B3D; padding-bottom:12px; margin-bottom:24px; }
  h2 { font-size:18px; margin:20px 0 10px; color:#C66B3D; }
  .scores { display:flex; gap:16px; margin:12px 0; }
  .score-card { flex:1; padding:16px; border-radius:12px; border:1px solid #E8DDD0; text-align:center; }
  .score-card h3 { font-size:16px; }
  .score-num { font-size:32px; font-weight:800; color:#C66B3D; }
  .conclusion { background:linear-gradient(135deg,#FF7A45,#FF5A4F); color:#fff; padding:20px; border-radius:14px; margin:16px 0; }
  .conclusion h2 { color:#fff; }
  .weather { display:flex; gap:12px; margin:12px 0; }
  .weather-item { padding:12px; border-radius:10px; border:1px solid #E8DDD0; text-align:center; min-width:100px; }
  .temp { font-size:24px; font-weight:700; color:#C66B3D; }
  table { width:100%; border-collapse:collapse; margin:12px 0; }
  th { background:#C66B3D; color:#fff; padding:10px 14px; text-align:left; font-size:13px; }
  td { padding:10px 14px; border-bottom:1px solid #E8DDD0; font-size:13px; }
  tr:nth-child(even) { background:#FAF6F0; }
  .detail { font-size:12px; color:#888; margin-top:4px; font-style:italic; }
  .footer { margin-top:32px; padding-top:16px; border-top:1px solid #D6C9B8; font-size:11px; color:#B08B6E; text-align:center; }
</style></head><body>
''');
    buf.writeln('<h1>✈️ 目的地对比报告</h1>');

    // 评分
    if (r.scores.isNotEmpty) {
      buf.writeln('<h2>综合评分</h2><div class="scores">');
      for (final s in r.scores) {
        buf.writeln('<div class="score-card">');
        buf.writeln('<h3>${s.destination}</h3>');
        buf.writeln('<div class="score-num">${s.overall.toStringAsFixed(1)}</div>');
        buf.writeln('<div style="font-size:12px;color:#888;">');
        for (final e in s.details.entries) {
          buf.writeln('${e.key}: ${e.value.toStringAsFixed(1)}/5');
        }
        buf.writeln('</div></div>');
      }
      buf.writeln('</div>');
    }

    // 结论
    if (r.verdict.isNotEmpty) {
      buf.writeln('<div class="conclusion">');
      buf.writeln('<h2>AI 结论</h2>');
      buf.writeln('<p>${r.verdict}</p>');
      if (r.recommendation.isNotEmpty) {
        buf.writeln('<p style="opacity:0.8;font-size:13px;">${r.recommendation}</p>');
      }
      buf.writeln('</div>');
    }

    // 天气
    if (r.weather.isNotEmpty) {
      buf.writeln('<h2>实时天气</h2><div class="weather">');
      for (final w in r.weather) {
        buf.writeln('<div class="weather-item">');
        buf.writeln('<div>${w.city}</div>');
        buf.writeln('<div class="temp">${w.temperature}°C</div>');
        buf.writeln('<div style="font-size:12px;">${w.weather}</div>');
        buf.writeln('</div>');
      }
      buf.writeln('</div>');
    }

    // 对比表格
    if (r.table.rows.isNotEmpty) {
      buf.writeln('<h2>详细对比</h2>');
      buf.writeln('<table><thead><tr>');
      for (final h in r.table.headers) {
        buf.writeln('<th>$h</th>');
      }
      buf.writeln('</tr></thead><tbody>');
      for (final row in r.table.rows) {
        buf.writeln('<tr>');
        buf.writeln('<td><strong>${row.dimension}</strong></td>');
        for (final v in row.values) {
          buf.writeln('<td>$v</td>');
        }
        buf.writeln('</tr>');
        if (row.detail.isNotEmpty) {
          buf.writeln('<tr><td colspan="${r.table.headers.length}" class="detail">${row.detail}</td></tr>');
        }
      }
      buf.writeln('</tbody></table>');
    }

    buf.writeln('<div class="footer">由 旅程小助手 AI 生成 · ${DateTime.now().year}</div>');
    buf.writeln('</body></html>');

    final blob = html.Blob([buf.toString()], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '对比报告_${DateTime.now().millisecondsSinceEpoch}.html')
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    _showSnack('对比报告已下载');
  }

  Widget _buildScoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('综合评分', style: AppTheme.headingMedium),
        const SizedBox(height: 10),
        // 评分卡片 + 雷达图并排
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // 左侧：评分卡片
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _compareResult!.scores.map((score) {
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.softShadow,
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        children: [
                          Text(score.destination, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 56, height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: score.overall / 5.0,
                                  strokeWidth: 5,
                                  backgroundColor: AppTheme.divider,
                                  color: score.overall >= 4.0 ? AppTheme.primary : score.overall >= 3.0 ? AppTheme.accent : AppTheme.error,
                                ),
                                Text(score.overall.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...score.details.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    i < e.value.round() ? Icons.star : Icons.star_border,
                                    size: 8, color: AppTheme.accent,
                                  )),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              // 右侧：雷达图
              _buildRadarChart(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadarChart() {
    if (_compareResult!.scores.isEmpty) return const SizedBox.shrink();
    // 收集所有维度名
    final allDims = <String>{};
    for (final s in _compareResult!.scores) {
      allDims.addAll(s.details.keys);
    }
    final dimList = allDims.toList();

    final chartColors = [
      AppTheme.primary,
      AppTheme.accent,
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
      const Color(0xFF2196F3),
    ];

    final series = _compareResult!.scores.asMap().entries.map((entry) {
      final s = entry.value;
      final values = dimList.map((d) => s.details[d] ?? 0.0).toList();
      return RadarSeries(
        name: s.destination,
        values: values,
        color: chartColors[entry.key % chartColors.length],
      );
    }).toList();

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('维度雷达', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          RadarChartWidget(labels: dimList, series: series, size: 160),
          // 图例
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: series.map((s) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 3),
                    Text(s.name, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ 行程 Tab ═══════════════════
  Widget _buildItineraryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softShadow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.route, color: Color(0xFF4CAF50), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('生成行程', style: AppTheme.headingMedium),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _itineraryDestController,
                  decoration: const InputDecoration(labelText: '目的地', prefixIcon: Icon(Icons.location_on, color: AppTheme.primary)),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _selectedDate,
                      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary)), child: child!),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Text(DateFormat('yyyy年MM月dd日').format(_selectedDate), style: AppTheme.body),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text('旅行天数', style: AppTheme.body),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1天')), ButtonSegment(value: 2, label: Text('2天')),
                          ButtonSegment(value: 3, label: Text('3天')), ButtonSegment(value: 5, label: Text('5天')),
                        ],
                        selected: {_itineraryDays},
                        onSelectionChanged: (v) => setState(() => _itineraryDays = v.first),
                        style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _generating ? null : _generateItinerary,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _generating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('生成${_itineraryDays}日行程', style: const TextStyle(fontSize: 16)),
                ),
                if (_itineraryStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(_itineraryStatus, style: AppTheme.caption),
                      ],
                    ),
                  ),
                // 流式中间状态：已收到的天
                if (_generating && _streamingDayPlans.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _streamingDayPlans.map((day) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('第${day['day']}天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(day['title'] ?? '', style: AppTheme.bodySmall)),
                              ],
                            ),
                            if (day['summary']?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(day['summary'], style: AppTheme.caption),
                              ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_itinerary != null) ...[
            if (_itinerary!.hasMultiDay)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _itinerary!.dayPlans.length,
                  itemBuilder: (context, index) {
                    final dayPlan = _itinerary!.dayPlans[index];
                    final isSelected = index == _activeDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('第${dayPlan.day}天', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _activeDay = index),
                        selectedColor: AppTheme.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
            ItineraryCard(
              itinerary: _itinerary!,
              activeDay: _itinerary!.hasMultiDay ? _activeDay : 0,
              onCopy: _copyItinerary,
              onDownload: _downloadItinerary,
              onViewMap: _viewOnMap,
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: _toggleSaveItinerary,
                icon: Icon(_itinerarySaved ? Icons.favorite : Icons.favorite_border, color: AppTheme.pink),
                label: Text(_itinerarySaved ? '取消收藏' : '收藏此行程'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: BorderSide(color: AppTheme.pink), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════ 历史 Tab ═══════════════════
  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.history, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('暂无对比历史', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('在「表格对比」中进行目的地对比后\n历史记录将显示在这里', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final h = _history[index];
        return InkWell(
          onTap: () => _showHistoryDetail(h.id, h.destinations.join(' vs ')),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.compare_arrows, color: AppTheme.primary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h.destinations.join(' vs '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _deleteHistoryItem(h.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppTheme.error.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(h.createdAt.length >= 10 ? h.createdAt.substring(0, 10) : h.createdAt, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                if (h.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(h.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 14, color: AppTheme.primary.withAlpha(180)),
                      const SizedBox(width: 4),
                      Text('查看明细', style: TextStyle(fontSize: 12, color: AppTheme.primary.withAlpha(180))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _destControllers) c.dispose();
    _itineraryDestController.dispose();
    _specialNeedsController.dispose();
    super.dispose();
  }
}
