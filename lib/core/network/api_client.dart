import 'dart:async';

import 'package:dio/dio.dart';

import '../error/app_exception.dart';
import '../storage/token_storage.dart';
import 'api_paths.dart';

/// 로그인이 풀렸을 때(401 + 토큰 갱신 실패) 세션에 알리는 통로.
/// Dio 와 세션이 서로를 직접 참조하지 않도록 이벤트로 분리했다.
class AuthEvents {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _controller.stream;
  void emitUnauthorized() => _controller.add(null);
  void dispose() => _controller.close();
}

/// 백엔드 호출 공통 클라이언트.
/// - 모든 요청에 Authorization: Bearer <accessToken>
/// - 401 이면 refreshToken 으로 한 번 갱신 후 재시도, 실패하면 AuthEvents 로 로그아웃
/// - 오류는 전부 [AppException] 으로 바꿔서 던진다
/// - 응답 형식: 성공은 JSON 본문 그대로, 실패는 {"code": "...", "message": "..."} (API_CONTRACT.md)
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required AuthEvents authEvents,
    Dio? dio,
  })  : _tokens = tokenStorage,
        _authEvents = authEvents,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.readAccessToken();
        if (token != null && options.extra['skipAuth'] != true) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final isRetry = error.requestOptions.extra['retried'] == true;
        final isAuthCall = error.requestOptions.path.startsWith('/auth/');
        if (status == 401 && !isRetry && !isAuthCall) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            try {
              final opts = error.requestOptions..extra['retried'] = true;
              final token = await _tokens.readAccessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch<dynamic>(opts);
              handler.resolve(response);
              return;
            } catch (_) {
              // 재시도도 실패하면 아래로 진행
            }
          }
          _authEvents.emitUnauthorized();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final AuthEvents _authEvents;
  Future<bool>? _refreshing;

  Future<bool> _tryRefresh() {
    // 동시에 여러 요청이 401 을 받아도 갱신은 한 번만
    return _refreshing ??= () async {
      try {
        final refreshToken = await _tokens.readRefreshToken();
        if (refreshToken == null) return false;
        final res = await _dio.post<dynamic>(
          ApiPaths.authRefresh,
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'skipAuth': true}),
        );
        final data = res.data as Map<String, dynamic>;
        await _tokens.save(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String?,
        );
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send(() => _dio.post<dynamic>(path, data: body, options: Options(extra: {'skipAuth': !auth})));

  Future<dynamic> put(String path, {Object? body}) => _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) => _send(() => _dio.delete<dynamic>(path, data: body));

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.of(query)..removeWhere((_, v) => v == null);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  AppException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(AppErrorKind.timeout);
      case DioExceptionType.connectionError:
        return const AppException(AppErrorKind.network);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final body = e.response?.data;
        String? code;
        String? message;
        if (body is Map) {
          code = body['code']?.toString();
          message = body['message']?.toString();
        }
        return AppException(AppException.kindFromCode(code, status), message: message, statusCode: status, code: code);
      default:
        return AppException(AppErrorKind.unknown, message: null, code: e.type.name);
    }
  }
}
