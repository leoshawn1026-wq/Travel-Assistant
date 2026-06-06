import 'dart:convert';
import 'dart:html' as html;
import 'dart:async';
import '../core/api/api_client.dart';
import '../core/storage/local_storage.dart';
import '../core/config/app_config.dart';
import '../models/compare.dart';
import '../models/itinerary.dart';
import '../models/poi.dart';

/// 旅行 API 服务层 - 对接后端所有接口
class TravelApi {
  final _client = ApiClient();

  // ── 通用 SSE 流式请求 ──

  /// 发起 SSE POST 请求，返回事件流
  /// 每个事件是 {"type": "row"/"complete"/"status"/"day"/"items", "data": ...}
  Stream<Map<String, dynamic>> _sseStream(String path, Map<String, dynamic> body) {
    final controller = StreamController<Map<String, dynamic>>();
    try {
      final url = '${AppConfig.baseUrl}${AppConfig.apiPrefix}$path';
      final payload = jsonEncode(body);
      final request = html.HttpRequest();
      request.open('POST', url);
      request.setRequestHeader('Content-Type', 'application/json');
      request.responseType = 'text';

      int lastLength = 0;

      void parseChunk(String text) {
        for (final line in text.split('\n')) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty || jsonStr == '{}') continue;
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              if (data.containsKey('e')) {
                controller.addError(Exception(data['e']));
              } else {
                controller.add(data);
              }
            } catch (_) {}
          }
        }
      }

      request.onProgress.listen((_) {
        final current = request.responseText ?? '';
        if (current.length > lastLength) {
          parseChunk(current.substring(lastLength));
          lastLength = current.length;
        }
      });

      request.onLoadEnd.listen((_) {
        final current = request.responseText ?? '';
        if (current.length > lastLength) {
          parseChunk(current.substring(lastLength));
        }
        controller.close();
      });

      request.onError.listen((_) {
        controller.addError(Exception('流式请求失败'));
        controller.close();
      });

      request.send(payload);
    } catch (e) {
      controller.addError(e);
      controller.close();
    }
    return controller.stream;
  }

  // ── AI 对话 ──

  Future<String> chat(List<Map<String, String>> messages) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/chat',
      data: {
        'messages': _trimMessages(messages),
        'stream': false,
      },
      fromJson: (d) => d as Map<String, dynamic>,
    );
    return data['content'] as String? ?? '';
  }

  /// 流式对话 — 返回 token 流（复用 _sseStream）
  Stream<String> chatStream(List<Map<String, String>> messages) {
    return _sseStream('/chat/stream', {
      'messages': _trimMessages(messages),
      'stream': true,
    }).map((event) => event['t'] as String);
  }

  // ── 聊天历史 ──

  Future<List<Map<String, String>>?> getChatHistory() async {
    try {
      final storage = LocalStorage();
      final deviceId = await storage.getDeviceId();
      final data = await _client.get<Map<String, dynamic>>(
        '/chat/history',
        params: {'device_id': deviceId},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      final messages = (data['messages'] as List?) ?? [];
      return messages.map((m) => Map<String, String>.from(m as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveChatHistory(List<Map<String, String>> messages) async {
    try {
      final storage = LocalStorage();
      final deviceId = await storage.getDeviceId();
      await _client.post<Map<String, dynamic>>(
        '/chat/history',
        data: {'device_id': deviceId, 'messages': messages},
        fromJson: (d) => d as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  Future<void> deleteChatHistory() async {
    try {
      final storage = LocalStorage();
      final deviceId = await storage.getDeviceId();
      await _client.delete<Map<String, dynamic>>(
        '/chat/history',
        params: {'device_id': deviceId},
        fromJson: (d) => d as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  // ── 多对话管理 ──

  /// 获取对话列表
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final storage = LocalStorage();
      final deviceId = await storage.getDeviceId();
      final data = await _client.get<Map<String, dynamic>>(
        '/chat/conversations',
        params: {'device_id': deviceId},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      return ((data['conversations'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { return []; }
  }

  /// 保存对话
  Future<String?> saveConversation(String convId, List<Map<String, String>> messages) async {
    try {
      final storage = LocalStorage();
      final deviceId = await storage.getDeviceId();
      final data = await _client.post<Map<String, dynamic>>(
        '/chat/conversations',
        data: {'device_id': deviceId, 'conversation_id': convId, 'messages': messages},
        fromJson: (d) => d as Map<String, dynamic>,
      );
      return data['conversation_id'] as String?;
    } catch (_) { return null; }
  }

  /// 读取某条对话
  Future<List<Map<String, String>>?> getConversation(String convId) async {
    try {
      final data = await _client.get<Map<String, dynamic>>(
        '/chat/conversations/$convId',
        fromJson: (d) => d as Map<String, dynamic>,
      );
      final msgs = (data['messages'] as List?) ?? [];
      return msgs.map((m) => Map<String, String>.from(m as Map)).toList();
    } catch (_) { return null; }
  }

  /// 删除对话
  Future<void> deleteConversation(String convId) async {
    try {
      await _client.delete<Map<String, dynamic>>(
        '/chat/conversations/$convId',
        fromJson: (d) => d as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  // ── 消息裁剪 ──

  List<Map<String, String>> _trimMessages(List<Map<String, String>> messages) {
    const int maxRounds = 6;
    const int maxMessages = maxRounds * 2 + 1;
    if (messages.length <= maxMessages) return messages;
    final systemMsg = messages.firstWhere(
      (m) => m['role'] == 'system',
      orElse: () => <String, String>{},
    );
    final hasSystem = systemMsg.isNotEmpty;
    final recent = messages.sublist(messages.length - maxMessages + (hasSystem ? 1 : 0));
    if (hasSystem) return [systemMsg, ...recent];
    return recent;
  }

  // ── 目的地对比 ──

  Future<CompareResult> compareDestinations({
    required List<String> destinations,
    int travelDays = 3,
    String budgetLevel = 'medium',
    String purpose = 'leisure',
    String withWho = 'alone',
    bool withPet = false,
    String travelStyle = 'free',
    String preferredSeason = '',
    String specialNeeds = '',
    String departureDate = '',
  }) async {
    final storage = LocalStorage();
    final deviceId = await storage.getDeviceId();
    return await _client.post<CompareResult>(
      '/compare/destinations',
      data: {
        'destinations': destinations,
        'travel_days': travelDays,
        'budget_level': budgetLevel,
        'purpose': purpose,
        'with_who': withWho,
        'with_pet': withPet,
        'travel_style': travelStyle,
        'preferred_season': preferredSeason,
        'special_needs': specialNeeds,
        'departure_date': departureDate,
        'device_id': deviceId,
      },
      fromJson: (d) => CompareResult.fromJson(d as Map<String, dynamic>),
    );
  }

  /// 流式对比 — 返回事件流 (row/status/complete)
  Stream<Map<String, dynamic>> compareStream({
    required List<String> destinations,
    int travelDays = 3,
    String budgetLevel = 'medium',
    String purpose = 'leisure',
    String withWho = 'alone',
    bool withPet = false,
    String travelStyle = 'free',
    String preferredSeason = '',
    String specialNeeds = '',
    String departureDate = '',
  }) async* {
    final storage = LocalStorage();
    final deviceId = await storage.getDeviceId();
    yield* _sseStream('/compare/destinations/stream', {
      'destinations': destinations,
      'travel_days': travelDays,
      'budget_level': budgetLevel,
      'purpose': purpose,
      'with_who': withWho,
      'with_pet': withPet,
      'travel_style': travelStyle,
      'preferred_season': preferredSeason,
      'special_needs': specialNeeds,
      'departure_date': departureDate,
      'device_id': deviceId,
    });
  }

  Future<List<CompareHistoryItem>> getCompareHistory() async {
    final storage = LocalStorage();
    final deviceId = await storage.getDeviceId();
    return await _client.get<List<CompareHistoryItem>>(
      '/compare/history',
      params: {'device_id': deviceId, 'limit': 10},
      fromJson: (d) {
        final items = (d as Map)['items'] as List? ?? [];
        return items.map((e) => CompareHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }

  /// 获取单条对比历史明细
  Future<Map<String, dynamic>> getCompareHistoryDetail(String compId) async {
    return await _client.get<Map<String, dynamic>>(
      '/compare/history/$compId',
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  /// 删除单条对比历史
  Future<void> deleteCompareHistory(String compId) async {
    await _client.delete<Map<String, dynamic>>(
      '/compare/history/$compId',
      fromJson: (d) => d as Map<String, dynamic>,
    );
  }

  // ── 行程生成 ──

  Future<Itinerary> generateItinerary({
    required String destination,
    required String date,
    List<String> preferences = const [],
    String pace = 'moderate',
    int days = 1,
    bool withPet = false,
  }) async {
    return await _client.post<Itinerary>(
      '/itinerary/generate',
      data: {
        'destination': destination,
        'date': date,
        'preferences': preferences,
        'pace': pace,
        'days': days,
        'with_pet': withPet,
      },
      fromJson: (d) => Itinerary.fromJson(d as Map<String, dynamic>),
    );
  }

  /// 流式行程生成 — 返回事件流 (status/day/items/complete)
  Stream<Map<String, dynamic>> generateItineraryStream({
    required String destination,
    required String date,
    List<String> preferences = const [],
    String pace = 'moderate',
    int days = 1,
    bool withPet = false,
  }) {
    return _sseStream('/itinerary/generate/stream', {
      'destination': destination,
      'date': date,
      'preferences': preferences,
      'pace': pace,
      'days': days,
      'with_pet': withPet,
    });
  }

  // ── POI 搜索 ──

  Future<PoiSearchResult> searchPoi({
    required String keywords,
    String city = '',
  }) async {
    return await _client.get<PoiSearchResult>(
      '/poi/search',
      params: {'keywords': keywords, 'city': city},
      fromJson: (d) => PoiSearchResult.fromJson(d as Map<String, dynamic>),
    );
  }

  // ── 管理后台 ──

  Future<dynamic> get(String path) async {
    return await _client.get<dynamic>(path, fromJson: (d) => d);
  }
}
