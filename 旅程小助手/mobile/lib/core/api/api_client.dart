import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// Dio 网络请求封装 - 统一拦截器与错误处理
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.baseUrl}${AppConfig.apiPrefix}',
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.next(options);
      },
      onError: (error, handler) {
        final msg = _parseError(error);
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            message: msg,
            type: error.type,
          ),
        );
      },
    ));
  }

  String _parseError(DioException error) {
    if (error.response?.data is Map) {
      final data = error.response!.data as Map;
      return data['detail']?.toString() ?? data['message']?.toString() ?? '网络请求失败';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '响应超时，AI 正在思考中...';
      default:
        return error.message ?? '未知网络错误';
    }
  }

  Future<T> post<T>(String path, {dynamic data, required T Function(dynamic) fromJson}) async {
    final resp = await dio.post(path, data: data);
    final body = resp.data as Map<String, dynamic>;
    if (body['code'] != 0) {
      throw Exception(body['message'] ?? '请求失败');
    }
    return fromJson(body['data']);
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? params, required T Function(dynamic) fromJson}) async {
    final resp = await dio.get(path, queryParameters: params);
    final body = resp.data as Map<String, dynamic>;
    if (body['code'] != 0) {
      throw Exception(body['message'] ?? '请求失败');
    }
    return fromJson(body['data']);
  }

  Future<T> delete<T>(String path, {Map<String, dynamic>? params, required T Function(dynamic) fromJson}) async {
    final resp = await dio.delete(path, queryParameters: params);
    final body = resp.data as Map<String, dynamic>;
    if (body['code'] != 0) {
      throw Exception(body['message'] ?? '请求失败');
    }
    return fromJson(body['data']);
  }
}
