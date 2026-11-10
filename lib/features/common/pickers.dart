import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_policy.dart';
import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------- 직무 추가하기 (1-4 · 6-3)

/// 피그마 최종 "직무 추가하기" (1212:7788 · 1212:7994 · 1212:8111) 전체 화면:
/// 직접 입력 칸 · 자주 찾는 직무 칩 · 전체 직무(분류를 누르면 펼쳐서 직무 태그) → "‘서비스기획’ 직무로 지원해요".
/// 고르면 Job 을 돌려준다 (직접 입력은 id 가 빈 문자열). 뒤로 가면 null.
Future<Job?> showJobPicker(
  BuildContext context, {
  required String companyName,
  String? selectedName,
}) {
  return Navigator.of(context).push<Job>(
    MaterialPageRoute(
      builder: (_) => _JobPickerScreen(selectedName: selectedName),
    ),
  );
}

class _JobPickerScreen extends ConsumerStatefulWidget {
  const _JobPickerScreen({this.selectedName});

  final String? selectedName;

  @override
  ConsumerState<_JobPickerScreen> createState() => _JobPickerScreenState();
}

class _JobPickerScreenState extends ConsumerState<_JobPickerScreen> {
  final _custom = TextEditingController();
  late Job? _picked = widget.selectedName == null
      ? null
      : Job(id: '', name: widget.selectedName!);

  /// 펼친 분류 id
  String? _open;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _customName => _custom.text.trim();

  /// 직접 입력한 글자가 있으면 그게 우선
  Job? get _selection =>
      _customName.isNotEmpty ? Job(id: '', name: _customName) : _picked;

  void _select(Job job) {
    FocusScope.of(context).unfocus();
    setState(() {
      _custom.clear();
      _picked = job;
    });
  }

  void _done(List<Job> all) {
    final picked = _selection;
    if (picked == null) return;
    // 이름만 받은 직무(처음 값 · 직접 입력)는 목록에서 같은 이름을 찾아 id 를 붙인다
    final known = all.where((j) => j.name == picked.name).firstOrNull;
    Navigator.of(context)
        .pop(picked.id.isEmpty && known != null ? known : picked);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(
      text,
      style: AppTypography.body1Medium.copyWith(
        fontSize: 16,
        color: AppColors.textGuide,
      ),
    ),
  );

  /// 피그마 목록 이름을 서버 직무와 이름으로 맞춘다 (공백·가운뎃점 차이는 무시)
  static List<Job> _popularJobs(JobCatalog c) {
    String key(String s) => s.replaceAll(RegExp(r'[\s·/]'), '');
    final all = {for (final j in [...c.categories.expand((g) => g.jobs), ...c.popular]) key(j.name): j};
    return [for (final n in AppPolicy.popularJobNames) Job(id: all[key(n)]?.id ?? '', name: n)];
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(jobCatalogProvider);
    final selection = _selection;
    final selectedName = _customName.isEmpty ? _picked?.name : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '직무 추가하기'),
      body: catalog.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(jobCatalogProvider),
        ),
        data: (c) => GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl,
            ),
            children: [
              _label('직접 입력'),
              _CustomJobField(
                controller: _custom,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              _label('자주 찾는 직무'),
              Wrap(
                spacing: 13,
                runSpacing: 10,
                children: [
                  for (final j in _popularJobs(c))
                    _JobPill(
                      label: j.name,
                      selected: j.name == selectedName,
                      outlined: false,
                      onTap: () => _select(j),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _label('전체 직무'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < c.categories.length; i++)
                      _CategoryRow(
                        category: c.categories[i],
                        open: _open == c.categories[i].id,
                        last: i == c.categories.length - 1,
                        selectedName: selectedName,
                        onToggle: () => setState(
                          () => _open = _open == c.categories[i].id
                              ? null
                              : c.categories[i].id,
                        ),
                        onSelect: _select,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomCta(
        children: [
          AppButton(
            label: selection == null
                ? '직무를 선택해 주세요'
                : '‘${selection.name}’ 직무로 지원해요',
            onPressed: selection == null || catalog.asData == null
                ? null
                : () => _done(catalog.asData!.value.all.toList()),
          ),
        ],
      ),
    );
  }
}

/// 직접 입력 칸: 흰 바탕 · 회색 테두리 · 모서리 16 · 오른쪽 ✕
class _CustomJobField extends StatelessWidget {
  const _CustomJobField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 15, right: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EBED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              maxLength: AppPolicy.jobNameMaxLength,
              textInputAction: TextInputAction.done,
              style: AppTypography.body1Medium.copyWith(
                fontSize: 16,
                color: AppColors.textStrong,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: '직무를 입력하세요',
                hintStyle: AppTypography.body1Medium.copyWith(
                  fontSize: 16,
                  color: AppColors.textGuide,
                ),
              ),
            ),
          ),
          // 피그마 1212:7788: 비어 있어도 ✕ 를 보여 준다 (누르면 지우기)
          IconButton(
              tooltip: '지우기',
              onPressed: () {
                controller.clear();
                onChanged();
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 22,
                color: AppColors.textSub,
              ),
            ),
        ],
      ),
    );
  }
}

/// 전체 직무 한 줄: "경영·기획 ⌄" — 누르면 펼쳐서 직무 태그 (펼친 줄 위 16 · 태그 아래 17)
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.open,
    required this.last,
    required this.selectedName,
    required this.onToggle,
    required this.onSelect,
  });

  final JobCategory category;
  final bool open;
  final bool last;
  final String? selectedName;
  final VoidCallback onToggle;
  final ValueChanged<Job> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.fillMuted)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: AppTypography.body1Medium.copyWith(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // 접힘 ⌄ · 펼침 ⌃
                    AnimatedRotation(
                      turns: open ? -0.25 : 0.25,
                      duration: const Duration(milliseconds: 150),
                      child: const Chevron(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Wrap(
                spacing: 13,
                runSpacing: 12,
                children: [
                  for (final j in category.jobs)
                    _JobPill(
                      label: j.name,
                      selected: j.name == selectedName,
                      outlined: true,
                      onTap: () => onSelect(j),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 직무 칩. 자주 찾는 직무는 흰 알약, 전체 직무 태그는 회색 테두리. 고르면 진한 차콜 + 흰 글자.
class _JobPill extends StatelessWidget {
  const _JobPill({
    required this.label,
    required this.selected,
    required this.outlined,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // 글자 폭만큼만 (alignment 를 주면 Wrap 안에서 한 줄을 꽉 채워 버린다)
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.textStrong : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: outlined
                ? Border.all(
                    color: selected
                        ? AppColors.textStrong
                        : AppColors.fillMuted,
                  )
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.body2Medium.copyWith(
              color: selected ? AppColors.white : AppColors.textGuide,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 면접일 달력 시트 (1-5 · 6-3, 오늘 이전 날짜는 고를 수 없다)

/// 피그마 942:3771 "‹ 2026.10 ›" 달력 시트 → 선택 완료. 닫으면 null.
Future<DateTime?> pickInterviewDate(BuildContext context, {DateTime? initial}) {
  return showBareSheet<DateTime>(
    context,
    color: AppColors.surface,
    builder: (_) => _CalendarSheet(initial: initial),
  );
}

class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet({this.initial});

  final DateTime? initial;

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late final DateTime _today = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  late DateTime? _picked =
      widget.initial != null && !widget.initial!.isBefore(_today)
      ? widget.initial
      : null;
  late DateTime _month = DateTime(
    (_picked ?? _today).year,
    (_picked ?? _today).month,
  );

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _canPrev => _month.isAfter(DateTime(_today.year, _today.month));
  bool get _canNext => _month.isBefore(DateTime(_today.year + 2, 12));

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    // 월요일 시작 6주 칸
    final first = _month.subtract(Duration(days: _month.weekday - 1));
    final days = [
      for (var i = 0; i < 42; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
    final rows =
        days.last.subtract(const Duration(days: 6)).month != _month.month
        ? 5
        : 6;
    final label = '${_month.year}.${_month.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: _canPrev ? () => _shift(-1) : null,
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 28,
                  color: _canPrev ? AppColors.ink : AppColors.statusIcon,
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.number(20),
                  ),
                ),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: _canNext ? () => _shift(1) : null,
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 28,
                  color: _canNext ? AppColors.ink : AppColors.statusIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textCaption,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (final d in days.sublist(r * 7, r * 7 + 7))
                  Expanded(child: _day(d)),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppButton(
              label: '선택 완료',
              onPressed: _picked == null
                  ? null
                  : () => Navigator.of(context).pop(_picked),
            ),
          ),
        ],
      ),
    );
  }

  Widget _day(DateTime d) {
    final inMonth = d.month == _month.month;
    final enabled = inMonth && !d.isBefore(_today);
    final selected = _picked != null && DateUtils.isSameDay(d, _picked);
    final color = selected
        ? AppColors.white
        : enabled
        ? AppColors.ink
        : AppColors.statusIcon;
    return Semantics(
      button: enabled,
      selected: selected,
      label: '${d.month}월 ${d.day}일',
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled ? () => setState(() => _picked = d) : null,
        radius: 22,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: selected
                  ? const BoxDecoration(
                      color: AppColors.cardDark,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Text(
                '${d.day}',
                style: AppTypography.subheading.copyWith(
                  fontWeight: AppTypography.medium,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 공시 근거

/// 근거 카드 (기아 2025 사업보고서 / 공시일 … / 발췌)
class EvidenceCard extends StatelessWidget {
  const EvidenceCard({
    super.key,
    required this.evidence,
    this.compactTitle = false,
    this.quoted = false,
  });

  final Evidence evidence;

  /// 공시 근거 시트는 원문 인용이라 “ ” 로 감싼다
  final bool quoted;

  /// 답변 보기 화면은 제목 14
  final bool compactTitle;

  @override
  Widget build(BuildContext context) {
    // 피그마 4-2: 흰 카드 · 제목 16 · "공시일 | 2026.03.12" / "대상 기간 | …" 12 회색 · 본문 15
    final meta = [
      if (evidence.publishedAt != null) '공시일  |  ${evidence.publishedAt}',
      if (evidence.period != null) '대상 기간  |  ${evidence.period}',
    ];
    return OutlinedBox(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            evidence.title,
            style: compactTitle
                ? AppTypography.body1Strong
                : AppTypography.cardTitle,
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final m in meta)
              Text(
                m,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPlaceholder,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            quoted ? '“${evidence.excerpt}”' : evidence.excerpt,
            style: AppTypography.body1.copyWith(
              color: AppColors.textStrong,
              height: 1.6,
            ),
          ),
          if (evidence.interpretation != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '해석 · ${evidence.interpretation}',
              style: AppTypography.caption.copyWith(color: AppColors.textSub),
            ),
          ],
        ],
      ),
    );
  }
}

/// 공시 근거 시트 (3-4). [questionId] 가 있으면 "오류 제보하기" 를 보낸다.
Future<void> showEvidenceSheet(
  BuildContext context, {
  required Evidence evidence,
  String? questionId,
}) {
  return showAppSheet<void>(
    context,
    title: '공시 근거',
    builder: (_) =>
        _EvidenceSheetBody(evidence: evidence, questionId: questionId),
  );
}

class _EvidenceSheetBody extends ConsumerStatefulWidget {
  const _EvidenceSheetBody({required this.evidence, this.questionId});

  final Evidence evidence;
  final String? questionId;

  @override
  ConsumerState<_EvidenceSheetBody> createState() => _EvidenceSheetBodyState();
}

class _EvidenceSheetBodyState extends ConsumerState<_EvidenceSheetBody> {
  bool _reporting = false;

  Future<void> _report() async {
    final id = widget.questionId;
    if (id == null) return;
    setState(() => _reporting = true);
    try {
      await ref
          .read(quizRepositoryProvider)
          .reportQuestion(questionId: id, reason: '공시 근거 시트에서 오류 제보');
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, '제보해 주셔서 고마워요. 확인 후 고칠게요.');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.evidence.url;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.xxs,
        AppSpacing.screenH,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvidenceCard(evidence: widget.evidence, quoted: true),
          const SizedBox(height: AppSpacing.sm),
          if (url != null)
            AppButton(
              label: 'DART 원문 보기 ↗',
              variant: AppButtonVariant.outline,
              onPressed: () =>
                  unawaited(ref.read(linkServiceProvider).open(url)),
            ),
          if (widget.questionId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: '오류 제보하기',
              variant: AppButtonVariant.secondary,
              loading: _reporting,
              onPressed: _report,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 기업 검색 (1-2 검색 · 6-2 기업 추가하기)

/// 검색 화면에서 "추가한 기업" 줄에 보이는 기업
typedef AddedCompany = ({String id, String name});

/// 피그마 "기업 추가하기" 화면: 검색창 + (첫 설정) 추가한 기업 동그라미 줄 + 결과 카드 "추가".
/// - [onAdd] 를 주면 이 화면에 머물며 여러 곳을 추가하고, 아래 "추가 완료" 로 돌아간다 (첫 설정, 피그마 1074:12509).
/// - [onAdd] 가 없으면 고른 기업을 돌려주며 닫힌다 (마이 → 직무·면접일 시트).
class CompanySearchScreen extends ConsumerStatefulWidget {
  const CompanySearchScreen({
    super.key,
    this.watchAdded,
    this.onAdd,
    this.onRemove,
    this.exclude = const {},
  });

  final List<AddedCompany> Function(WidgetRef ref)? watchAdded;
  final void Function(BuildContext context, WidgetRef ref, Company company)?
  onAdd;
  final void Function(WidgetRef ref, String companyId)? onRemove;

  /// 결과에서 뺄 기업 (이미 준비 중)
  final Set<String> exclude;

  static Future<Company?> open(
    BuildContext context, {
    List<AddedCompany> Function(WidgetRef ref)? watchAdded,
    void Function(BuildContext context, WidgetRef ref, Company company)? onAdd,
    void Function(WidgetRef ref, String companyId)? onRemove,
    Set<String> exclude = const {},
  }) {
    return Navigator.of(context).push<Company>(
      MaterialPageRoute(
        builder: (_) => CompanySearchScreen(
          watchAdded: watchAdded,
          onAdd: onAdd,
          onRemove: onRemove,
          exclude: exclude,
        ),
      ),
    );
  }

  @override
  ConsumerState<CompanySearchScreen> createState() =>
      _CompanySearchScreenState();
}

class _CompanySearchScreenState extends ConsumerState<CompanySearchScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final added = widget.watchAdded?.call(ref) ?? const <AddedCompany>[];
    final addedIds = {for (final a in added) a.id};
    final companies = ref.watch(companiesProvider(_query));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppNavBar(title: '기업 추가하기'),
      // 검색창에 키보드가 바로 올라오므로 "추가 완료" 는 본문 아래에 붙여 키보드 위로 같이 올라오게 한다
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xl,
              ),
              children: [
                SearchField(
                  controller: _search,
                  hint: '기업 이름을 검색해보세요',
                  // QA: 키보드는 칸을 눌렀을 때만 (자동으로 올리지 않는다)
                  onChanged: _onQuery,
                ),
                if (added.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '추가한 기업',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textCaption,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: added.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (_, i) => _AddedBubble(
                        name: added[i].name,
                        onRemove: widget.onRemove == null
                            ? null
                            : () => widget.onRemove!(ref, added[i].id),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                companies.when(
                  skipLoadingOnReload: true,
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: LoadingView(),
                  ),
                  error: (e, _) => ErrorView(
                    error: e,
                    compact: true,
                    onRetry: () => ref.invalidate(companiesProvider(_query)),
                  ),
                  data: (list) {
                    final shown = list
                        .where((c) => !widget.exclude.contains(c.id))
                        .toList();
                    if (shown.isEmpty) {
                      return Padding(
                        // 피그마 1514:9656: 검색창 아래 151 에 그림, 그 아래 제목 (위 간격 16 포함)
                        padding: const EdgeInsets.only(top: 135),
                        child: _query.isEmpty
                            ? const StatusMessage(
                                title: '더 추가할 기업이 없어요',
                                icon: StatusIcon.search,
                              )
                            : StatusMessage(
                                title: '‘$_query’ 검색 결과가 없어요',
                                description: '기업명을 다시 확인해보세요',
                                icon: StatusIcon.search,
                              ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < shown.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.sm),
                          () {
                            final c = shown[i];
                            final isAdded = addedIds.contains(c.id);
                            return CompanyTile(
                              name: c.name,
                              subtitle: c.industry,
                              onTap: isAdded
                                  ? null
                                  : () {
                                      if (widget.onAdd != null) {
                                        widget.onAdd!(context, ref, c);
                                      } else {
                                        Navigator.of(context).pop(c);
                                      }
                                    },
                              trailing: Text(
                                isAdded ? '추가됨' : '추가',
                                style: AppTypography.caption.copyWith(
                                  color: isAdded
                                      ? AppColors.textStrong
                                      : AppColors.textCaption,
                                ),
                              ),
                            );
                          }(),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.onAdd != null)
            BottomCta(
              children: [
                AppButton(
                  label: '추가 완료',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 추가한 기업 동그라미 (로고 + ✕ + 이름)
class _AddedBubble extends StatelessWidget {
  const _AddedBubble({required this.name, this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CompanyLogo(name: name, size: 44, bordered: true),
              if (onRemove != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Semantics(
                    button: true,
                    label: '$name 빼기',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.fillMuted,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: AppColors.textSub,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.textStrong),
          ),
        ],
      ),
    );
  }
}
