import 'package:dio/dio.dart';

class TutorInterceptor extends Interceptor {
  static String? _token;

  static void setToken(String? token) {
    _token = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null && !options.path.contains('/token')) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    super.onRequest(options, handler);
  }
}
