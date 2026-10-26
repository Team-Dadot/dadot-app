import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/session/session_controller.dart';
import '../../data/mock/mock_backend.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 최종 6-1 마이: 내 계정 · 학습 현황 · 고객 지원 · 계정 흰 카드 묶음 (줄마다 제목 + 설명 + ›)
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: '로그아웃할까요?', message: '다시 로그인하면 기록을 그대로 볼 수 있어요.', confirmLabel: '로그아웃');
    if (ok) await ref.read(sessionProvider.notifier).signOut();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '정말 탈퇴할까요?',
      message: '준비 기업, 경험, 퀴즈·면접 기록이 모두 지워지고 되돌릴 수 없어요.',
      confirmLabel: '탈퇴하기',
    );
    if (!ok) return;
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  Future<void> _resetMock(WidgetRef ref) async {
    await ref.read(localStoreProvider).remove(MockBackend.storageKey);
    ref.invalidate(mockBackendProvider);
    await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    final preps = ref.watch(preparationsProvider).asData?.value;
    final experiences = ref.watch(experiencesProvider).asData?.value;
    final notification = ref.watch(notificationSettingsProvider).asData?.value;
    final isEmailUser = user?.loginMethod == LoginMethod.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          children: [
            const _GroupLabel('내 계정', first: true),
            // 프로필 카드 (누르면 내 정보)
            MenuGroup(children: [
              Semantics(
                button: true,
                label: '내 정보, ${user?.nickname ?? ''}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => context.push(Routes.myProfile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.nickname ?? '', style: AppTypography.subheading.copyWith(color: AppColors.textStrong)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (user?.email ?? '').isNotEmpty ? user!.email! : '${user?.loginMethod.detailLabel ?? ''} 로그인',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  if (user != null) LoginBadge(method: user.loginMethod),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Chevron(),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
            const _GroupLabel('학습 현황'),
            MenuGroup(children: [
              MenuRow(
                title: '준비 기업 관리',
                subtitle: '준비 기업 ${preps?.length ?? '-'}/${AppPolicy.maxCompanies}',
                onTap: () => context.push(Routes.myCompanies),
              ),
              MenuRow(title: '지원 정보·면접 일정', subtitle: '기업별 직무 · 면접일', onTap: () => context.push(Routes.myApplications)),
              MenuRow(
                title: '내 경험 정보',
                subtitle: '저장한 경험 ${experiences?.length ?? '-'}/${AppPolicy.maxExperiences}',
                onTap: () => context.push(Routes.myExperiences),
              ),
              MenuRow(
                title: '알림',
                subtitle: notification == null ? null : (notification.enabled ? notification.summary.split(' · ').first : '꺼짐'),
                onTap: () => context.push(Routes.myNotifications),
              ),
            ]),
            const _GroupLabel('고객 지원'),
            MenuGroup(children: [
              MenuRow(title: '서비스 문의 및 오류제보', onTap: () => context.push(Routes.myInquiry)),
            ]),
            const SizedBox(height: AppSpacing.md),
            MenuGroup(children: [
              MenuRow(title: '회원 정보 수정', onTap: () => context.push(Routes.myProfile)),
              if (isEmailUser) MenuRow(title: '비밀번호 변경', onTap: () => context.push(Routes.myPassword)),
              MenuRow(title: '로그아웃', onTap: () => _signOut(context, ref)),
              MenuRow(title: '회원 탈퇴', onTap: () => _delete(context, ref)),
            ]),
            if (ref.watch(appConfigProvider).useMock) ...[
              const SizedBox(height: AppSpacing.lg),
              TextLink(label: '[개발] Mock 데이터 초기화', onTap: () => _resetMock(ref)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로그인 방법 표시 (카카오는 노란 말풍선, 나머지는 글자)
class LoginBadge extends StatelessWidget {
  const LoginBadge({super.key, required this.method});

  final LoginMethod method;

  @override
  Widget build(BuildContext context) {
    final kakao = method == LoginMethod.kakao;
    return Semantics(
      label: '${method.label} 계정',
      excludeSemantics: true,
      child: Container(
        width: kakao ? 16 : null,
        height: 16,
        padding: kakao ? null : const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kakao ? AppColors.kakao : AppColors.fillSecondary,
          borderRadius: BorderRadius.circular(kakao ? 4 : AppRadius.pill),
        ),
        child: kakao
            ? const Icon(Icons.chat_bubble_rounded, size: 10, color: Color(0xFF191919))
            : Text(method.label, style: AppTypography.micro.copyWith(fontSize: 10, height: 1)),
      ),
    );
  }
}

/// 마이 목록 묶음 이름 (학습 · 고객 지원 · 계정)
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? AppSpacing.sm : 28, bottom: AppSpacing.sm, left: AppSpacing.xxs),
      child: Text(text, style: AppTypography.body2Medium.copyWith(color: AppColors.textTertiary)),
    );
  }
}
