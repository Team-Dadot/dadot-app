import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 화면 아래 토스트. QA(1435:12760): 토스트가 하단 버튼("추가 완료" · "답변 제출하기")을 가리던 문제 →
/// 지금 화면에 하단 버튼([BottomCta])이 보이면 그 버튼 바로 위(8)에, 없으면 키보드·홈 표시줄 위에 띄운다.
///
/// SnackBar 는 Scaffold 의 bottomNavigationBar 만 피하고 본문 안 버튼·키보드 위 버튼은 덮어서 직접 그린다.
class AppToast {
  AppToast._();

  static OverlayEntry? _entry;

  /// 하단 버튼 위치를 알려 주는 키들 (BottomCta 가 화면에 붙을 때 등록)
  static final Set<GlobalKey> _ctaKeys = {};

  static void registerCta(GlobalKey key) => _ctaKeys.add(key);
  static void unregisterCta(GlobalKey key) => _ctaKeys.remove(key);

  /// 지금 보이는 화면의 하단 버튼 맨 위 y (없으면 null)
  static double? _ctaTop() {
    double? top;
    for (final key in _ctaKeys) {
      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final route = ModalRoute.of(ctx);
      if (route != null && !route.isCurrent) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      top = top == null ? y : (y < top ? y : top);
    }
    return top;
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void show(BuildContext context, Widget content, {String? actionLabel, Color? background}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastView(
        content: content,
        actionLabel: actionLabel,
        background: background ?? AppColors.primary,
        bottomOf: _ctaTop,
        onDone: () {
          if (_entry == entry) hide();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.content,
    required this.background,
    required this.bottomOf,
    required this.onDone,
    this.actionLabel,
  });

  final Widget content;
  final Color background;
  final String? actionLabel;
  final double? Function() bottomOf;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  // 3초 보여 주고 사라진다 (Timer 대신 애니메이션으로 — 화면이 사라지면 같이 정리된다)
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  double? _ctaTop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final top = widget.bottomOf();
    if (top != _ctaTop) setState(() => _ctaTop = top);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 키보드가 오르내리면 버튼 위치도 바뀌므로 다시 잰다
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final keyboard = media.viewInsets.bottom;
    final bottom = _ctaTop != null
        ? (media.size.height - _ctaTop! + AppSpacing.xs)
        : (keyboard > 0 ? keyboard : media.padding.bottom) + AppSpacing.md;
    return Positioned(
      left: AppSpacing.screenH,
      right: AppSpacing.screenH,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value * 3400;
          final o = t < 180 ? t / 180 : (t > 3150 ? (3400 - t) / 250 : 1.0);
          return Opacity(opacity: o.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, (1 - o) * 8), child: child));
        },
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: widget.background,
            borderRadius: BorderRadius.circular(AppRadius.dialogButton),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, widget.actionLabel == null ? 16 : 4, 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DefaultTextStyle(
                          style: AppTypography.body2Medium.copyWith(color: AppColors.white),
                          child: widget.content,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null)
                      TextButton(
                        onPressed: widget.onDone,
                        style: TextButton.styleFrom(foregroundColor: AppColors.point),
                        child: Text(widget.actionLabel!, style: AppTypography.body2Strong.copyWith(color: AppColors.point)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
