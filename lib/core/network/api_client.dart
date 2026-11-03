import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../error/app_exception.dart';
import '../storage/token_storage.dart';
import 'api_paths.dart';

/// 로그인이 풀렸을 때(401) 세션에 알리는 통로.
/// Dio 와 세션이 서로를 직접 참조하지 않도록 이벤트로 분리했다.
class AuthEvents {
  final _controller = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _controller.stream;
  void emitUnauthorized() => _controller.add(null);
  void dispose() => _controller.close();
}

/// 다닷 서버(https://api.dadot.store) 공통 클라이언트. 계약: 기능별 API 명세 "공통 요청·응답 계약"
/// - 경로는 `/v1` 아래 (baseUrl 에 붙여 둔다). ApiPaths 에는 `/v1` 뒤 부분만 적는다.
/// - 인증: `Authorization: Bearer {accessToken}` (로그인 응답 data.accessToken, 1시간 만료)
/// - 토큰 재발급 API 가 없다 → 401 이면 바로 로그아웃(AuthEvents) 하고 다시 로그인하게 한다
/// - 응답 봉투: 성공 {success:true, data, error:null} → data 만 돌려준다 / 실패 {success:false, data:null, error:{code,message}}
/// - 204 는 본문이 없다 → null
/// - Idempotency-Key 가 필요한 API 는 [post] 의 idempotencyKey 로 논리 요청마다 UUID 를 넣는다
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required AuthEvents authEvents,
    Dio? dio,
  })  : _tokens = tokenStorage,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}${ApiPaths.basePath}',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            )) {
    // 디버그 실행 때만: 서버 응답을 터미널에 찍는다 (토큰 헤더는 찍지 않음). 응답 모양 확인용.
    if (kDebugMode) {
      _dio.interceptors.add(InterceptorsWrapper(
        onResponse: (res, handler) {
          debugPrint('[API] ${res.requestOptions.method} ${res.requestOptions.uri} → ${res.statusCode}\n${_short(res.data)}');
          handler.next(res);
        },
        onError: (e, handler) {
          debugPrint('[API] ${e.requestOptions.method} ${e.requestOptions.uri} → ${e.response?.statusCode ?? e.type.name}\n${_short(e.response?.data)}');
          handler.next(e);
        },
      ));
    }
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // bearer 를 직접 넘긴 요청 (로그인 직후 내 정보 조회)은 저장된 토큰을 쓰지 않는다
        final token = options.extra['bearer'] as String? ?? await _tokens.readAccessToken();
        if (token != null && options.extra['skipAuth'] != true) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // 재발급 API 없음: 인증이 필요한 요청이 401 이면 세션을 끝낸다
        if (error.response?.statusCode == 401 && error.requestOptions.extra['skipAuth'] != true) {
          authEvents.emitUnauthorized();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// 로그용 응답 (accessToken · registrationToken · verificationToken 은 가린다)
  static String _short(Object? data) {
    var text = data is String ? data : jsonEncode(data);
    text = text.replaceAllMapped(RegExp(r'"(accessToken|registrationToken|verificationToken|identityToken)"\s*:\s*"[^"]*"'), (m) => '"${m[1]}":"***"');
    return text.length > 4000 ? '${text.substring(0, 4000)}…' : text;
  }

  /// [bearer] 를 주면 저장된 토큰 대신 그 토큰으로 보낸다 (아직 저장 전인 로그인 직후)
  Future<dynamic> get(String path, {Map<String, dynamic>? query, String? bearer}) => _send(
        () => _dio.get<dynamic>(path, queryParameters: _clean(query), options: Options(extra: {if (bearer != null) 'bearer': bearer})),
      );

  /// 논리 요청 하나에 쓰는 Idempotency-Key (UUID v4). 같은 요청을 다시 보낼 때는 같은 키를 쓴다.
  static String newIdempotencyKey() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true, String? idempotencyKey, Map<String, dynamic>? query}) => _send(
        () => _dio.post<dynamic>(
          path,
          data: body,
          queryParameters: _clean(query),
          options: Options(
            extra: {'skipAuth': !auth},
            headers: {if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey},
          ),
        ),
      );

  Future<dynamic> put(String path, {Object? body, String? idempotencyKey, Map<String, dynamic>? query}) => _send(
        () => _dio.put<dynamic>(
          path,
          data: body,
          queryParameters: _clean(query),
          options: Options(headers: {if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey}),
        ),
      );

  Future<dynamic> patch(String path, {Object? body, String? idempotencyKey}) => _send(
        () => _dio.patch<dynamic>(path, data: body, options: Options(headers: {if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey})),
      );

  Future<dynamic> delete(String path, {Object? body, String? idempotencyKey}) => _send(
        () => _dio.delete<dynamic>(path, data: body, options: Options(headers: {if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey})),
      );

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return Map.of(query)..removeWhere((_, v) => v == null);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return unwrap(res.statusCode, res.data);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// 응답 봉투에서 data 를 꺼낸다. success=false 면 error 를 AppException 으로.
  static dynamic unwrap(int? status, dynamic body) {
    if (status == 204 || body == null || (body is String && body.isEmpty)) return null;
    if (body is Map && body.containsKey('success')) {
      if (body['success'] == true) return body['data'];
      throw _fromErrorBody(status, body);
    }
    return body;
  }

  static AppException _fromErrorBody(int? status, Object? body) {
    String? code;
    String? message;
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        code = err['code']?.toString();
        message = err['message']?.toString();
      } else {
        // 봉투가 아닌 오류 (게이트웨이 등)
        code = body['code']?.toString();
        message = body['message']?.toString();
      }
    }
    return AppException(AppException.kindFromCode(code, status), message: message, statusCode: status, code: code);
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
        return _fromErrorBody(e.response?.statusCode, e.response?.data);
      default:
        return AppException(AppErrorKind.unknown, message: null, code: e.type.name);
    }
  }
}
