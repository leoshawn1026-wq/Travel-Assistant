import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/storage/local_storage.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 初始化本地存储（Web 上可能失败，捕获异常防止白屏）
    await LocalStorage().init();
  } catch (e) {
    // Web 环境下 SharedPreferences 初始化失败不影响主流程
    debugPrint('LocalStorage init warning: $e');
  }

  try {
    // 状态栏样式（Web 上忽略即可）
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  } catch (_) {}

  runApp(const TravelApp());
}
