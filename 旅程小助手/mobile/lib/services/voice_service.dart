import 'dart:async';

// 使用 dart:js 和 dart:js_util 访问浏览器 Web Speech API
import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// 浏览器语音识别服务 (Web Speech API)
class VoiceService {
  static js.JsObject? _recognizer;
  static bool _isListening = false;

  /// 浏览器是否支持语音识别
  static bool get isSupported {
    try {
      return js_util.hasProperty(js.context, 'webkitSpeechRecognition') ||
          js_util.hasProperty(js.context, 'SpeechRecognition');
    } catch (_) {
      return false;
    }
  }

  /// 开始语音识别，返回识别文本
  static Future<String> startListening() async {
    if (_isListening) return '';

    _isListening = true;
    final completer = Completer<String>();

    try {
      // 获取 SpeechRecognition 构造函数
      final jsObject = js_util.hasProperty(js.context, 'webkitSpeechRecognition')
          ? js_util.getProperty(js.context, 'webkitSpeechRecognition')
          : js_util.getProperty(js.context, 'SpeechRecognition');

      if (jsObject == null) {
        _isListening = false;
        completer.complete('');
        return completer.future;
      }

      // 创建实例 (new Constructor())
      _recognizer = js.JsObject.fromBrowserObject(
        js_util.callConstructor(jsObject as js.JsFunction, []),
      );

      // 设置属性
      js_util.setProperty(_recognizer!, 'lang', 'zh-CN');
      js_util.setProperty(_recognizer!, 'continuous', false);
      js_util.setProperty(_recognizer!, 'interimResults', false);

      // 监听结果
      js_util.setProperty(_recognizer!, 'onresult', (event) {
        final results = js_util.getProperty(event, 'results');
        final length = js_util.getProperty(results, 'length') as int;
        final lastResult = js_util.getProperty(results, length - 1);
        final result0 = js_util.getProperty(lastResult, 0);
        final transcript = js_util.getProperty(result0, 'transcript') as String? ?? '';
        _isListening = false;
        completer.complete(transcript);
      });

      js_util.setProperty(_recognizer!, 'onerror', (event) {
        _isListening = false;
        if (!completer.isCompleted) completer.complete('');
      });

      js_util.setProperty(_recognizer!, 'onend', () {
        _isListening = false;
        if (!completer.isCompleted) completer.complete('');
      });

      // 启动
      js_util.callMethod(_recognizer!, 'start', []);
    } catch (e) {
      _isListening = false;
      if (!completer.isCompleted) completer.complete('');
    }

    return completer.future;
  }

  /// 停止语音识别
  static void stopListening() {
    if (_recognizer != null && _isListening) {
      try { js_util.callMethod(_recognizer!, 'stop', []); } catch (_) {}
      _isListening = false;
    }
  }
}
