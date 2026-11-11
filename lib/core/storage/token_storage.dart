import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_token_state.dart';

export 'auth_token_state.dart';

/// 토큰 쌍과 갱신 키를 한 레코드로 저장하고 변경을 순서대로 처리한다.
abstract class TokenStorage {
  Future<void> _tail = Future<void>.value();

  Future<String?> readRecord();
  Future<void> writeRecord(String? value);

  Future<T> _serial<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<AuthTokenState?> _read() async {
    final raw = await readRecord();
    return raw == null ? null : AuthTokenState.decode(raw);
  }

  Future<AuthTokenState?> readSession() => _serial(_read);
  Future<String?> readAccessToken() async => (await readSession())?.accessToken;
  Future<String?> readRefreshToken() async => (await readSession())?.refreshToken;

  /// 새 로그인에 이전 계정의 Refresh Token이 섞이지 않도록 쌍을 교체한다.
  Future<void> save({required String accessToken, String? refreshToken}) =>
      _serial(() => writeRecord(AuthTokenState.create(accessToken, refreshToken).encode()));

  Future<void> clear() => _serial(() => writeRecord(null));

  Future<AuthTokenState?> prepareRefresh(String sessionId, String key) => _serial(() async {
    final current = await _read();
    if (current == null || current.sessionId != sessionId || current.refreshToken == null) return null;
    if (current.refreshKey != null) return current;
    final pending = AuthTokenState(
      sessionId: current.sessionId,
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
      refreshKey: key,
    );
    // 응답 유실·앱 종료 후에도 같은 토큰과 같은 키를 재사용한다.
    await writeRecord(pending.encode());
    return pending;
  });

  Future<bool> completeRefresh(AuthTokenState expected, String access, String refresh) => _serial(() async {
    final current = await _read();
    if (!_matches(current, expected)) return false;
    await writeRecord(AuthTokenState(
      sessionId: expected.sessionId,
      accessToken: access,
      refreshToken: refresh,
    ).encode());
    return true;
  });

  Future<bool> clearIfCurrent(AuthTokenState expected) => _serial(() async {
    final current = await _read();
    if (!_matches(current, expected)) return false;
    await writeRecord(null);
    return true;
  });

  bool _matches(AuthTokenState? current, AuthTokenState expected) =>
      current != null &&
      current.sessionId == expected.sessionId &&
      current.accessToken == expected.accessToken &&
      current.refreshToken == expected.refreshToken &&
      current.refreshKey == expected.refreshKey;
}

class SecureTokenStorage extends TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _sessionKey = 'auth.session.v2';
  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';

  @override
  Future<String?> readRecord() async {
    final raw = await _storage.read(key: _sessionKey);
    // 로그아웃 표시를 남겨 구형 저장소의 토큰이 복구되지 않게 한다.
    if (raw != null) return raw == 'null' ? null : raw;
    final access = await _storage.read(key: _accessKey);
    if (access == null) return null;
    final refresh = await _storage.read(key: _refreshKey);
    final migrated = AuthTokenState.create(access, refresh).encode();
    await _storage.write(key: _sessionKey, value: migrated);
    return migrated;
  }

  @override
  Future<void> writeRecord(String? value) async {
    await _storage.write(key: _sessionKey, value: value ?? 'null');
  }
}

class InMemoryTokenStorage extends TokenStorage {
  String? _record;

  @override
  Future<String?> readRecord() async => _record;

  @override
  Future<void> writeRecord(String? value) async { _record = value; }
}
