import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/session/session_controller.dart';
import '../../data/mock/mock_backend.dart';
import '../../data/models/auth.dart';
import '../../design_system/design_system.dart';
import '../common/data_providers.dart';

/// 피그마 최종 6-1 마이: 내 계정 · 학습 현황 · 고객 지원 · 계정 흰 카드 묶음 (줄마다 제목 + 설명 + ›)
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    // 피그마 6-E7 로그아웃 확인
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '로그아웃을 진행할까요?',
      message: '재로그인을 통해 앱을 사용할 수 있어요',
      cancelLabel: '나가기',
      confirmLabel: '진행하기',
    );
    if (ok) await ref.read(sessionProvider.notifier).signOut();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // 피그마 6-E6 회원 탈퇴 확인
    final ok = await showConfirmDialog(
      context,
      warning: true,
      title: '탈퇴를 진행할까요?',
      message: '계정 및 이용 기록은 모두 삭제되며,\n복구는 불가능해요',
      cancelLabel: '나가기',
      confirmLabel: '진행하기',
    );
    if (!ok || !context.mounted) return;
    // 서버가 탈퇴 요청 안에서 본인 확인: 이메일 회원은 비밀번호, 소셜 회원은 소셜 로그인 다시 한 번
    String? password;
    if (ref.read(sessionProvider).user?.loginMethod == LoginMethod.email) {
      password = await showAppSheet<String>(
        context,
        title: '비밀번호 확인',
        heightFactor: SheetHeights.view,
        expand: true,
        builder: (_) => const _PasswordConfirm(),
      );
      if (password == null) return;
    }
    try {
      await ref.read(sessionProvider.notifier).deleteAccount(password: password);
    } on SocialAuthCancelled {
      // 재인증 창을 닫음
    } catch (e) {
      if (context.mounted) showErrorToast(context, e);
    }
  }

  /// 문의는 서버 설정의 구글폼으로 연다 (Mock 은 앱 안 문의 화면)
  Future<void> _openInquiry(BuildContext context, WidgetRef ref) async {
    String? url;
    try {
      url = (await ref.read(serverAppConfigProvider.future)).inquiryFormUrl;
    } catch (_) {}
    if (!context.mounted) return;
    // .invalid 는 예시용 주소 (서버 설정 전) → 앱 안 문의 화면
    final host = Uri.tryParse(url ?? '')?.host ?? '';
    if (url != null && host.isNotEmpty && !host.endsWith('.invalid')) {
      await ref.read(linkServiceProvider).open(url);
    } else {
      await context.push(Routes.myInquiry);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // 피그마 6-1 (1520:9847): 좌우 20 (카드 너비 362), 상태 바 아래 33 에서 시작
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 33, AppSpacing.screenH, AppSpacing.xl),
          children: [
            const _GroupLabel('내 계정', first: true),
            // 프로필 카드 (누르면 내 정보): 카드 위아래 8 + 줄 위아래 12, 이름 16 · 4 · 메일 12
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
                              Text(user?.nickname ?? '', style: AppTypography.rowTitle.copyWith(color: AppColors.ink)),
                              const SizedBox(height: AppSpacing.xxs),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (user?.email ?? '').isNotEmpty ? user!.email! : '${user?.loginMethod.detailLabel ?? ''} 로그인',
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(color: AppColors.textGuide, height: 1.4),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
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
            // QA 1520:9624: "학습 현황" → "학습 관리", "지원 정보·면접 일정" 은 준비 기업 관리와 같은 내용이라 뺐다
            const _GroupLabel('학습 관리'),
            // 두 줄 메뉴 카드: 카드 위아래 12, 줄 사이 16 · 0.5 선 · 16 (첫 줄 위 · 끝 줄 아래는 12)
            MenuGroup(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              children: [
                MenuRow(
                  title: '준비 기업 관리',
                  subtitle: '준비 기업 ${preps?.length ?? '-'}/${AppPolicy.maxCompanies}',
                  padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
                  onTap: () => context.push(Routes.myCompanies),
                ),
                MenuRow(
                  title: '내 경험 정보',
                  subtitle: '저장한 경험 ${experiences?.length ?? '-'}/${AppPolicy.maxExperiences}',
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  onTap: () => context.push(Routes.myExperiences),
                ),
                MenuRow(
                  title: '알림',
                  subtitle: notification == null ? null : (notification.enabled ? notification.summary.split(' · ').first : '꺼짐'),
                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                  onTap: () => context.push(Routes.myNotifications),
                ),
              ],
            ),
            const _GroupLabel('고객 지원'),
            MenuGroup(children: [
              MenuRow(title: '서비스 문의 및 오류제보', verticalPadding: AppSpacing.sm, onTap: () => _openInquiry(context, ref)),
            ]),
            const SizedBox(height: AppSpacing.lg),
            MenuGroup(children: [
              // 피그마 1520:9902: 계정 묶음 줄 여백 16 · 20 · 16 (카드 위아래 8)
              MenuRow(title: '회원 정보 수정', verticalPadding: AppSpacing.md, onTap: () => context.push(Routes.myProfile)),
              MenuRow(title: '로그아웃', verticalPadding: AppSpacing.lg, onTap: () => _signOut(context, ref)),
              MenuRow(title: '회원 탈퇴', verticalPadding: AppSpacing.md, onTap: () => _delete(context, ref)),
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
    // 피그마 1520:9861 · 1393:11078: 15×15 원 안 로고 (카카오 노란 원 + 말풍선 · Apple 검은 원 + 사과)
    final asset = switch (method) {
      LoginMethod.kakao => 'assets/images/icons/login_kakao.png',
      LoginMethod.apple => 'assets/images/icons/login_apple.png',
      _ => null,
    };
    return Semantics(
      label: '${method.label} 계정',
      excludeSemantics: true,
      child: Container(
        width: asset != null ? 15 : null,
        height: asset != null ? 15 : 16,
        padding: asset != null ? null : const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: switch (method) {
            LoginMethod.kakao => AppColors.kakao,
            LoginMethod.apple => AppColors.ink,
            _ => AppColors.fillSecondary,
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: asset != null
            ? Padding(
                padding: EdgeInsets.all(method == LoginMethod.apple ? 3 : 2.5),
                child: Image.asset(asset, excludeFromSemantics: true),
              )
            : Text(method.label, style: AppTypography.micro.copyWith(fontSize: 10, height: 1)),
      ),
    );
  }
}

/// 마이 목록 묶음 이름 (내 계정 · 학습 현황 · 고객 지원) — 피그마: 16 Medium #9A9DA4, 카드까지 10, 묶음 사이 32
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : AppSpacing.xxl, bottom: 10),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTypography.rowTitle.copyWith(color: AppColors.textGuide)),
      ),
    );
  }
}

/// 탈퇴 전 비밀번호 확인 (이메일 회원)
class _PasswordConfirm extends StatefulWidget {
  const _PasswordConfirm();

  @override
  State<_PasswordConfirm> createState() => _PasswordConfirmState();
}

class _PasswordConfirmState extends State<_PasswordConfirm> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.md),
            children: [
              Text('본인 확인을 위해 비밀번호를 입력해 주세요', style: AppTypography.body2Medium.copyWith(color: AppColors.textSub)),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                hint: '비밀번호',
                obscureText: true,
                // QA: 키보드는 칸을 눌렀을 때만 (자동으로 올리지 않는다)
                onChanged: (_) => setState(() {}),
                semanticLabel: '비밀번호',
              ),
            ],
          ),
        ),
        BottomCta(color: AppColors.sheet, children: [
          AppButton(
            label: '탈퇴하기',
            onPressed: _password.text.isEmpty ? null : () => Navigator.of(context).pop(_password.text),
          ),
        ]),
      ],
    );
  }
}
