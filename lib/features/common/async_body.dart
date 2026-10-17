import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/design_system.dart';

/// AsyncValue 를 로딩 · 오류 · 데이터 화면으로 나눠 그린다.
/// 이전 데이터가 있으면 새로고침 중에도 그대로 보여준다.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry, this.loadingMessage});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => LoadingView(message: loadingMessage),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
    );
  }
}
