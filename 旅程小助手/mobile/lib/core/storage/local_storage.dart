import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../../models/itinerary.dart';

/// SharedPreferences 本地存储 - 行程收藏、设备ID、收藏回复
class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 获取或生成设备 ID
  Future<String> getDeviceId() async {
    await init();
    var id = _prefs!.getString(AppConfig.keyDeviceId);
    if (id == null) {
      id = const Uuid().v4();
      await _prefs!.setString(AppConfig.keyDeviceId, id);
    }
    return id;
  }

  /// 保存行程到收藏
  Future<void> saveTrip(SavedTrip trip) async {
    await init();
    final trips = await getSavedTrips();
    trips.insert(0, trip);
    final jsonList = trips.map((t) => t.toJson()).toList();
    await _prefs!.setString(AppConfig.keySavedTrips, jsonEncode(jsonList));
  }

  /// 获取所有收藏行程
  Future<List<SavedTrip>> getSavedTrips() async {
    await init();
    final raw = _prefs!.getString(AppConfig.keySavedTrips);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => SavedTrip.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 删除收藏行程
  Future<void> deleteTrip(String id) async {
    await init();
    final trips = await getSavedTrips();
    trips.removeWhere((t) => t.id == id);
    final jsonList = trips.map((t) => t.toJson()).toList();
    await _prefs!.setString(AppConfig.keySavedTrips, jsonEncode(jsonList));
  }

  /// 聊天历史
  Future<void> saveChatHistory(List<Map<String, String>> messages) async {
    await init();
    await _prefs!.setString(AppConfig.keyChatHistory, jsonEncode(messages));
  }

  Future<List<Map<String, String>>> getChatHistory() async {
    await init();
    final raw = _prefs!.getString(AppConfig.keyChatHistory);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  // ── AI 回复收藏 ──

  static const _keySavedReplies = 'saved_ai_replies';

  Future<List<Map<String, String>>> getSavedReplies() async {
    await init();
    final raw = _prefs!.getString(_keySavedReplies);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  Future<void> saveReply(String content) async {
    final items = await getSavedReplies();
    // 去重：相同内容不重复收藏
    if (items.any((i) => i['content'] == content)) return;
    items.insert(0, {
      'content': content,
      'saved_at': DateTime.now().toIso8601String(),
    });
    await _prefs!.setString(_keySavedReplies, jsonEncode(items));
  }

  Future<void> deleteReply(int index) async {
    final items = await getSavedReplies();
    if (index < items.length) {
      items.removeAt(index);
      await _prefs!.setString(_keySavedReplies, jsonEncode(items));
    }
  }
}
