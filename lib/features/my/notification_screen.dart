import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/settings.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 6-9 알림 설정
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _saving = false;

  Future<void> _update(NotificationSettings next) async {
    setState(() => _saving = true);
    try {
      // TODO(출시 전): FCM 연결 후 권한 거부(6-E5)면 설정으로 안내
      if (next.enabled && await ref.read(pushServiceProvider).requestPermission()) {
        await ref.read(sessionProvider.notifier).registerPushToken();
      }
      await ref.read(profileRepositoryProvider).updateNotificationSettings(next);
      ref.invalidate(notificationSettingsProvider);
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(NotificationSettings s) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
      helpText: '알림 시간',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (t != null) await _update(s.copyWith(hour: t.hour, minute: t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '알림 설정'),
      body: settings.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(notificationSettingsProvider)),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            const PageTitle('나의 준비에 맞춰\n필요할 때만 알려줘요.'),
            const SizedBox(height: AppSpacing.lg),
            OutlinedBox(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('학습 알림 받기', style: AppTypography.cardTitle),
                        const SizedBox(height: 2),
                        Text('퀴즈 · 면접 학습 상태에 맞춘 제안을 받을 수 있어요.', style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
                      ],
                    ),
                  ),
                  SquareToggle(value: s.enabled, onChanged: _saving ? null : (v) => _update(s.copyWith(enabled: v))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedBox(
              onTap: s.enabled && !_saving ? () => _pickTime(s) : null,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text('알림 시간', style: AppTypography.rowTitle)),
                  Text('${s.timeLabel}  ›', style: AppTypography.body1Medium.copyWith(
                    color: s.enabled ? AppColors.textPrimary : AppColors.textDisabled,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
