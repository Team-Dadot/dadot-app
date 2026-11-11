import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/system_settings.dart';
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

class _NotificationScreenState extends ConsumerState<NotificationScreen> with WidgetsBindingObserver {
  /// 피그마 text/secondary
  static const Color _title = Color(0xFF303137);

  bool _saving = false;

  /// 시간 돌림판을 펼쳤는지
  bool _picking = false;

  /// 휴대폰(OS) 알림 권한 — 앱 설정이 켜져 있어도 이게 꺼져 있으면 알림이 안 온다 (null = 아직 모름)
  bool? _osAllowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 휴대폰 설정에서 권한을 바꾸고 돌아오면 다시 확인
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final allowed = await ref.read(reminderServiceProvider).hasPermission();
    if (mounted) setState(() => _osAllowed = allowed);
  }

  Future<void> _update(NotificationSettings next, {bool turningOn = false}) async {
    setState(() => _saving = true);
    try {
      if (turningOn) {
        // QA: 권한을 거부했는데도 켜짐으로 저장하던 것 → 허용했을 때만 켠다
        final allowed = await ref.read(pushServiceProvider).requestPermission();
        if (mounted) setState(() => _osAllowed = allowed);
        if (!allowed) {
          if (mounted) await _askOpenSettings();
          return;
        }
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

  Future<void> _askOpenSettings() async {
    final open = await showConfirmDialog(
      context,
      title: '알림 권한이 꺼져 있어요',
      message: '휴대폰 설정에서 Dadot 알림을 허용하면\n학습 알림을 받을 수 있어요.',
      confirmLabel: '설정 열기',
      cancelLabel: '닫기',
    );
    if (open) await SystemSettings.openNotificationSettings();
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
          // 피그마 6-9 (1393:10722): 라벨 y140 (헤더 아래 23) 에 "알림 설정하기"(16 Medium #767A82), 16 아래 카드(높이 80), 카드 사이 12
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 23, AppSpacing.screenH, AppSpacing.xl),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text('알림 설정하기', style: AppTypography.rowTitle.copyWith(color: AppColors.textCaption)),
            ),
            OutlinedBox(
              radius: AppRadius.button,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 19.5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('학습 알림 받기', style: AppTypography.cardTitle.copyWith(color: _title, height: 1.4)),
                        const SizedBox(height: 1),
                        Text(
                          '학습 상태에 맞는 알림을 받을 수 있어요.',
                          style: AppTypography.caption.copyWith(fontSize: 13, letterSpacing: -0.39, height: 1.4, fontWeight: AppTypography.regular, color: AppColors.textCaption),
                        ),
                      ],
                    ),
                  ),
                  SquareToggle(
                    value: s.enabled,
                    onChanged: _saving
                        ? null
                        : (v) {
                            if (!v) setState(() => _picking = false);
                            _update(s.copyWith(enabled: v), turningOn: v);
                          },
                  ),
                ],
              ),
            ),
            // 앱에서는 켜져 있는데 휴대폰 권한이 꺼져 있으면 알림이 안 온다 → 그대로 알려 주고 설정으로 보낸다
            if (s.enabled && _osAllowed == false) ...[
              const SizedBox(height: AppSpacing.sm),
              _PermissionOffBanner(onOpen: SystemSettings.openNotificationSettings),
            ],
            if (s.enabled) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedBox(
                radius: AppRadius.button,
                onTap: _saving ? null : () => setState(() => _picking = !_picking),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text('알림 시간', style: AppTypography.cardTitle.copyWith(color: _title, height: 1.4))),
                    // QA: "오전 9:00" 이 12 로 작았다 → 피그마 1393:10742 16 Medium #767A82
                    Text(s.timeLabel, style: AppTypography.rowTitle.copyWith(color: AppColors.textCaption)),
                    const SizedBox(width: AppSpacing.xxs),
                    // 접힘 ⌄ · 펼침 ⌃
                    RotatedBox(quarterTurns: _picking ? 3 : 1, child: const Chevron()),
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

  /// 돌림판 한 줄 (피그마: 줄 높이 56, 글자 20 — 고른 줄 Medium #15171B, 나머지 Regular #BCBFC5)
  static const double _row = 56;

  Widget _item(String text, bool selected) => Center(
        child: Text(
          text,
          style: AppTypography.heading.copyWith(
            fontSize: 20,
            height: 1.2,
            letterSpacing: 0,
            fontWeight: selected ? AppTypography.medium : AppTypography.regular,
            color: selected ? AppColors.ink : const Color(0xFFBCBFC5),
          ),
        ),
      );

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
    bool looping = true,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: _row,
      looping: looping,
      // 피그마처럼 평평하게 (휘어 보이는 효과 · 확대 없음), 선택 줄 선은 따로 그린다
      diameterRatio: 20,
      squeeze: 1,
      selectionOverlay: null,
      onSelectedItemChanged: (i) => setState(() => onChanged(i)),
      children: [for (var i = 0; i < count; i++) _item(label(i), i == selected)],
    );
  }

  /// 고른 줄 위아래 0.5 선 (#DCE0E7)
  Widget _lines() => const IgnorePointer(
        child: Center(
          child: SizedBox(
            height: _row,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: AppColors.fillMuted, width: 0.5)),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // 피그마 1393:10745: 흰 카드 · 안쪽 20 · 돌림판(3줄 168) · 20 · 완료(52, 모서리 16, 16 SemiBold)
    return OutlinedBox(
      radius: AppRadius.button,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(
            height: _row * 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 오전/오후 (너비 60)
                SizedBox(
                  width: 60,
                  child: Stack(
                    children: [
                      _wheel(
                        controller: _periodCtrl,
                        count: 2,
                        selected: _pm ? 1 : 0,
                        looping: false,
                        label: (i) => i == 0 ? '오전' : '오후',
                        onChanged: (i) => _pm = i == 1,
                      ),
                      Positioned.fill(child: _lines()),
                    ],
                  ),
                ),
                const SizedBox(width: 36.5),
                // 시 : 분 (너비 151)
                SizedBox(
                  width: 151,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _wheel(
                              controller: _hourCtrl,
                              count: 12,
                              selected: _h12 - 1,
                              label: (i) => (i + 1).toString().padLeft(2, '0'),
                              onChanged: (i) => _h12 = i + 1,
                            ),
                          ),
                          SizedBox(
                            width: 20,
                            child: Center(
                              child: Text(':', style: AppTypography.heading.copyWith(fontSize: 20, height: 1.2, fontWeight: AppTypography.medium, color: AppColors.ink)),
                            ),
                          ),
                          Expanded(
                            child: _wheel(
                              controller: _minuteCtrl,
                              count: 60,
                              selected: _minute,
                              label: (i) => i.toString().padLeft(2, '0'),
                              onChanged: (i) => _minute = i,
                            ),
                          ),
                        ],
                      ),
                      Positioned.fill(child: _lines()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            button: true,
            label: '완료',
            excludeSemantics: true,
            child: Material(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.button),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.saving ? null : () => widget.onDone(_hour24, _minute),
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: widget.saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.white))
                        : Text('완료', style: AppTypography.subheading.copyWith(color: AppColors.white, height: 1.4)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "휴대폰 알림 권한이 꺼져 있어요 · 설정 열기" 띠
class _PermissionOffBanner extends StatelessWidget {
  const _PermissionOffBanner({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        decoration: BoxDecoration(color: const Color(0xFFFFE3E3), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const ExcludeSemantics(child: Icon(Icons.error_rounded, size: 16, color: AppColors.destructive)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '휴대폰 알림 권한이 꺼져 있어 알림이 오지 않아요',
                style: AppTypography.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.destructive),
              ),
            ),
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(foregroundColor: AppColors.textCaption, textStyle: AppTypography.caption),
              child: const Text('설정 열기', style: TextStyle(decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }
}
