import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/settings.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 최종 6-9 학습 알림 시간 설정 (960:5542 · 968:3964 · 968:4058)
/// "알림 설정하기" · 학습 알림 받기 스위치 · 켜면 "알림 시간 오전 9:00 ⌄" → 펼쳐서 오전/오후 · 시 · 분 돌림판 + 완료
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  bool _saving = false;

  /// 시간 돌림판을 펼쳤는지
  bool _picking = false;

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
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.sm),
              child: Text('알림 설정하기', style: AppTypography.body2Medium.copyWith(color: AppColors.textCaption)),
            ),
            OutlinedBox(
              radius: AppRadius.button,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('학습 알림 받기', style: AppTypography.cardTitle.copyWith(color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('학습 상태에 맞는 알림을 받을 수 있어요.', style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
                      ],
                    ),
                  ),
                  SquareToggle(
                    value: s.enabled,
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (!v) setState(() => _picking = false);
                            _update(s.copyWith(enabled: v));
                          },
                  ),
                ],
              ),
            ),
            if (s.enabled) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedBox(
                radius: AppRadius.button,
                onTap: _saving ? null : () => setState(() => _picking = !_picking),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Text('알림 시간', style: AppTypography.cardTitle.copyWith(color: AppColors.ink))),
                    Text(s.timeLabel, style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
                    Icon(_picking ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.statusIcon),
                  ],
                ),
              ),
              if (_picking) ...[
                const SizedBox(height: AppSpacing.sm),
                _TimeWheel(
                  key: ValueKey('${s.hour}:${s.minute}'),
                  hour: s.hour,
                  minute: s.minute,
                  saving: _saving,
                  onDone: (h, m) async {
                    await _update(s.copyWith(hour: h, minute: m));
                    if (mounted) setState(() => _picking = false);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// 오전/오후 · 시(1~12) · 분(0~59) 돌림판 + 완료
class _TimeWheel extends StatefulWidget {
  const _TimeWheel({super.key, required this.hour, required this.minute, required this.onDone, required this.saving});

  final int hour;
  final int minute;
  final bool saving;
  final Future<void> Function(int hour, int minute) onDone;

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late bool _pm = widget.hour >= 12;
  late int _h12 = widget.hour % 12 == 0 ? 12 : widget.hour % 12;
  late int _minute = widget.minute;

  late final _periodCtrl = FixedExtentScrollController(initialItem: _pm ? 1 : 0);
  late final _hourCtrl = FixedExtentScrollController(initialItem: _h12 - 1);
  late final _minuteCtrl = FixedExtentScrollController(initialItem: _minute);

  @override
  void dispose() {
    _periodCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  int get _hour24 => (_h12 % 12) + (_pm ? 12 : 0);

  Widget _wheel({required FixedExtentScrollController controller, required int count, required String Function(int) label, required ValueChanged<int> onChanged}) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        looping: true,
        selectionOverlay: const _WheelOverlay(),
        onSelectedItemChanged: onChanged,
        children: [
          for (var i = 0; i < count; i++)
            Center(child: Text(label(i), style: AppTypography.number(20, weight: FontWeight.w500, color: AppColors.ink))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _periodCtrl,
                    itemExtent: 44,
                    selectionOverlay: const _WheelOverlay(),
                    onSelectedItemChanged: (i) => _pm = i == 1,
                    children: [
                      for (final p in ['오전', '오후'])
                        Center(child: Text(p, style: AppTypography.heading.copyWith(fontSize: 18, fontWeight: AppTypography.medium, color: AppColors.ink))),
                    ],
                  ),
                ),
                _wheel(controller: _hourCtrl, count: 12, label: (i) => (i + 1).toString().padLeft(2, '0'), onChanged: (i) => _h12 = i + 1),
                Text(':', style: AppTypography.number(20, color: AppColors.ink)),
                _wheel(controller: _minuteCtrl, count: 60, label: (i) => i.toString().padLeft(2, '0'), onChanged: (i) => _minute = i),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: '완료', loading: widget.saving, onPressed: () => widget.onDone(_hour24, _minute)),
        ],
      ),
    );
  }
}

/// 돌림판 가운데 선택 줄 (위아래 얇은 선)
class _WheelOverlay extends StatelessWidget {
  const _WheelOverlay();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: AppColors.divider)),
        ),
      );
}
