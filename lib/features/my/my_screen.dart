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

/// 6-1 마이
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
      appBar: const AppHeader(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
        children: [
          const PageTitle('나의 준비를\n차곡차곡 모아요.', large: false),
          const SizedBox(height: AppSpacing.xxs),
          // 프로필 (누르면 회원정보 수정)
          Semantics(
            button: true,
            label: '회원정보 수정, ${user?.nickname ?? ''}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => context.push(Routes.myProfile),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.card),
                child: Row(
                  children: [
                    const LogoBox(size: AppSizes.profile, label: '프로필'),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.nickname ?? '', style: AppTypography.subheading),
                          const SizedBox(height: 2),
                          Text(
                            [user?.loginMethod.label ?? '', if ((user?.email ?? '').isNotEmpty) user!.email!].join(' '),
                            style: AppTypography.caption,
                          ),
                          Text('${user?.loginMethod.detailLabel ?? ''}${isEmailUser ? '로' : '으로'} 로그인 중', style: AppTypography.micro),
                        ],
                      ),
                    ),
                    const Chevron(),
                  ],
                ),
              ),
            ),
          ),
          const LineDivider(),
          const _GroupLabel('학습'),
          MenuRow(
            title: '준비 기업 관리',
            subtitle: '준비 기업 ${preps?.length ?? '-'} / ${AppPolicy.maxCompanies}',
            onTap: () => context.push(Routes.myCompanies),
          ),
          MenuRow(title: '지원 정보·면접 일정', subtitle: '기업별 직무·면접일', onTap: () => context.push(Routes.myApplications)),
          MenuRow(
            title: '내 경험·자소서',
            subtitle: '저장한 경험 ${experiences?.length ?? '-'} / ${AppPolicy.maxExperiences}개',
            onTap: () => context.push(Routes.myExperiences),
          ),
          MenuRow(title: '학습 알림', subtitle: notification?.summary, onTap: () => context.push(Routes.myNotifications)),
          const _GroupLabel('고객 지원'),
          MenuRow(title: '서비스 문의·오류 제보', onTap: () => context.push(Routes.myInquiry)),
          const _GroupLabel('계정'),
          MenuRow(title: '회원정보 수정', subtitle: '닉네임 · 프로필 이미지', onTap: () => context.push(Routes.myProfile)),
          if (isEmailUser) MenuRow(title: '비밀번호 변경', onTap: () => context.push(Routes.myPassword)),
          MenuRow(title: '로그아웃', onTap: () => _signOut(context, ref)),
          MenuRow(title: '회원 탈퇴', onTap: () => _delete(context, ref)),
          const SizedBox(height: AppSpacing.sm),
          Text('비밀번호 변경은 이메일로 가입한 경우에만 보여요.', style: AppTypography.micro),
          if (ref.watch(appConfigProvider).useMock) ...[
            const SizedBox(height: AppSpacing.lg),
            TextLink(label: '[개발] Mock 데이터 초기화', onTap: () => _resetMock(ref)),
          ],
        ],
      ),
    );
  }
}

/// 마이 목록 묶음 이름 (학습 · 고객 지원 · 계정)
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xxs),
      child: Text(text, style: AppTypography.captionStrong.copyWith(color: AppColors.textSecondary)),
    );
  }
}
