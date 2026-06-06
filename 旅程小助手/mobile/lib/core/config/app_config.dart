/// 应用配置 - 前端不暴露任何第三方 API 密钥
class AppConfig {
  /// 后端 Base URL
  /// Android 模拟器: http://10.0.2.2:8000
  /// Chrome / iOS 模拟器: http://127.0.0.1:8000
  /// 真机调试: 改为电脑局域网 IP
  static const String baseUrl = 'http://127.0.0.1:8000';

  static const String apiPrefix = '/api/v1';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 120);

  /// SharedPreferences 键名
  static const String keySavedTrips = 'saved_trips';
  static const String keyDeviceId = 'device_id';
  static const String keyChatHistory = 'chat_history';
}
