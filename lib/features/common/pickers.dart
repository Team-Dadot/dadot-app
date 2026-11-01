import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/catalog.dart';
import '../../data/models/quiz.dart';
import '../../design_system/design_system.dart';
import 'data_providers.dart';

// ---------------------------------------------------------------- 직무 선택 시트 (1-4 · 6-3)

/// 피그마 6-3 "지원 직무" 시트: 자주 찾는 직무 칩 + 전체 직무(분류 ›) + 선택 완료.
/// 고르면 Job 을 돌려준다 (직접 입력은 id 가 빈 문자열).
Future<Job?> showJobPicker(BuildContext context, {required String companyName, String? selectedName}) {
  return showBareSheet<Job>(
    context,
    expand: true,
    builder: (_) => _JobPickerBody(selectedName: selectedName),
  );
}

class _JobPickerBody extends ConsumerStatefulWidget {
  const _JobPickerBody({this.selectedName});

  final String? selectedName;

  @override
  ConsumerState<_JobPickerBody> createState() => _JobPickerBodyState();
}

class _JobPickerBodyState extends ConsumerState<_JobPickerBody> {
  final _custom = TextEditingController();
  late Job? _picked = widget.selectedName == null ? null : Job(id: '', name: widget.selectedName!);
  JobCategory? _category;
  bool _customOpen = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _select(Job job) => setState(() => _picked = job);

  Widget _chips(List<Job> jobs) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final j in jobs) SelectChip(label: j.name, selected: j.name == _picked?.name, onTap: () => _select(j)),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: AppTypography.body2Medium.copyWith(color: AppColors.textCaption)),
      );

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(jobCatalogProvider);
    final cat = _category;
    final customName = _custom.text.trim();
    final picked = _customOpen && customName.isNotEmpty ? Job(id: '', name: customName) : _picked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: cat?.name ?? '지원 직무',
          onBack: cat == null ? () => Navigator.of(context).pop() : () => setState(() => _category = null),
        ),
        Expanded(
          child: catalog.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(jobCatalogProvider)),
            data: (c) => ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xs, AppSpacing.screenH, AppSpacing.lg),
              children: cat != null
                  ? [_chips(cat.jobs)]
                  : [
                      _label('자주 찾는 직무'),
                      _chips(c.popular),
                      const SizedBox(height: AppSpacing.xl),
                      _label('전체 직무'),
                      MenuGroup(children: [
                        for (final category in c.categories) MenuRow(title: category.name, onTap: () => setState(() => _category = category)),
                        MenuRow(
                          title: '찾는 직무가 없어요 · 직접 입력',
                          showChevron: false,
                          onTap: () => setState(() => _customOpen = !_customOpen),
                        ),
                      ]),
                      if (_customOpen) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(controller: _custom, hint: '직무 이름', autofocus: true, onChanged: (_) => setState(() {})),
                      ],
                    ],
            ),
          ),
        ),
        BottomCta(
          color: AppColors.sheet,
          children: [
            AppButton(
              label: '선택 완료',
              onPressed: picked == null
                  ? null
                  : () {
                      // 처음에 이름만 받은 직무는 목록에서 id 를 다시 찾는다
                      final known = catalog.asData?.value.all.where((j) => j.name == picked.name).firstOrNull;
                      Navigator.of(context).pop(picked.id.isEmpty && known != null ? known : picked);
                    },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 면접일 달력 시트 (1-5 · 6-3, 오늘 이전 날짜는 고를 수 없다)

/// 피그마 942:3771 "‹ 2026.10 ›" 달력 시트 → 선택 완료. 닫으면 null.
Future<DateTime?> pickInterviewDate(BuildContext context, {DateTime? initial}) {
  return showBareSheet<DateTime>(context, color: AppColors.surface, builder: (_) => _CalendarSheet(initial: initial));
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
  late DateTime? _picked = widget.initial != null && !widget.initial!.isBefore(_today) ? widget.initial : null;
  late DateTime _month = DateTime((_picked ?? _today).year, (_picked ?? _today).month);

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  bool get _canPrev => _month.isAfter(DateTime(_today.year, _today.month));
  bool get _canNext => _month.isBefore(DateTime(_today.year + 2, 12));

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    // 월요일 시작 6주 칸
    final first = _month.subtract(Duration(days: _month.weekday - 1));
    final days = [for (var i = 0; i < 42; i++) DateTime(first.year, first.month, first.day + i)];
    final rows = days.last.subtract(const Duration(days: 6)).month != _month.month ? 5 : 6;
    final label = '${_month.year}.${_month.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.lg, AppSpacing.screenH, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: _canPrev ? () => _shift(-1) : null,
                icon: Icon(Icons.chevron_left_rounded, size: 28, color: _canPrev ? AppColors.ink : AppColors.statusIcon),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(label, textAlign: TextAlign.center, style: AppTypography.number(20)),
                ),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: _canNext ? () => _shift(1) : null,
                icon: Icon(Icons.chevron_right_rounded, size: 28, color: _canNext ? AppColors.ink : AppColors.statusIcon),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(child: Text(w, textAlign: TextAlign.center, style: AppTypography.caption.copyWith(color: AppColors.textCaption))),
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
            child: AppButton(label: '선택 완료', onPressed: _picked == null ? null : () => Navigator.of(context).pop(_picked)),
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
              decoration: selected ? const BoxDecoration(color: AppColors.cardDark, shape: BoxShape.circle) : null,
              child: Text('${d.day}', style: AppTypography.subheading.copyWith(fontWeight: AppTypography.medium, color: color)),
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
  const EvidenceCard({super.key, required this.evidence, this.compactTitle = false, this.quoted = false});

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
          Text(evidence.title, style: compactTitle ? AppTypography.body1Strong : AppTypography.cardTitle),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final m in meta) Text(m, style: AppTypography.caption.copyWith(color: AppColors.textPlaceholder)),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            quoted ? '“${evidence.excerpt}”' : evidence.excerpt,
            style: AppTypography.body1.copyWith(color: AppColors.textStrong, height: 1.6),
          ),
          if (evidence.interpretation != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('해석 · ${evidence.interpretation}', style: AppTypography.caption.copyWith(color: AppColors.textSub)),
          ],
        ],
      ),
    );
  }
}

/// 공시 근거 시트 (3-4). [questionId] 가 있으면 "오류 제보하기" 를 보낸다.
Future<void> showEvidenceSheet(BuildContext context, {required Evidence evidence, String? questionId}) {
  return showAppSheet<void>(
    context,
    title: '공시 근거',
    builder: (_) => _EvidenceSheetBody(evidence: evidence, questionId: questionId),
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
      await ref.read(quizRepositoryProvider).reportQuestion(questionId: id, reason: '공시 근거 시트에서 오류 제보');
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.xxs, AppSpacing.screenH, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EvidenceCard(evidence: widget.evidence, quoted: true),
          const SizedBox(height: AppSpacing.sm),
          if (url != null)
            AppButton(
              label: 'DART 원문 보기 ↗',
              variant: AppButtonVariant.outline,
              onPressed: () => unawaited(ref.read(linkServiceProvider).open(url)),
            ),
          if (widget.questionId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(label: '오류 제보하기', variant: AppButtonVariant.secondary, loading: _reporting, onPressed: _report),
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
  const CompanySearchScreen({super.key, this.watchAdded, this.onAdd, this.onRemove, this.exclude = const {}});

  final List<AddedCompany> Function(WidgetRef ref)? watchAdded;
  final void Function(BuildContext context, WidgetRef ref, Company company)? onAdd;
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
    return Navigator.of(context).push<Company>(MaterialPageRoute(
      builder: (_) => CompanySearchScreen(watchAdded: watchAdded, onAdd: onAdd, onRemove: onRemove, exclude: exclude),
    ));
  }

  @override
  ConsumerState<CompanySearchScreen> createState() => _CompanySearchScreenState();
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
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, AppSpacing.sm, AppSpacing.screenH, AppSpacing.xl),
        children: [
          SearchField(controller: _search, hint: '기업 이름을 검색해보세요', autofocus: true, onChanged: _onQuery),
          if (added.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('추가한 기업', style: AppTypography.caption.copyWith(color: AppColors.textCaption)),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: added.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => _AddedBubble(
                  name: added[i].name,
                  onRemove: widget.onRemove == null ? null : () => widget.onRemove!(ref, added[i].id),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          companies.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView()),
            error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(companiesProvider(_query))),
            data: (list) {
              final shown = list.where((c) => !widget.exclude.contains(c.id)).toList();
              if (shown.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: _query.isEmpty
                      ? const StatusMessage(title: '더 추가할 기업이 없어요', icon: StatusIcon.search)
                      : StatusMessage(title: '‘$_query’ 검색 결과가 없어요', description: '기업명을 다시 확인해보세요', icon: StatusIcon.search),
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
                          style: AppTypography.caption.copyWith(color: isAdded ? AppColors.textStrong : AppColors.textCaption),
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
          if (widget.onAdd != null) BottomCta(children: [AppButton(label: '추가 완료', onPressed: () => Navigator.of(context).pop())]),
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
                        decoration: const BoxDecoration(color: AppColors.fillMuted, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 12, color: AppColors.textSub),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppColors.textStrong)),
        ],
      ),
    );
  }
}
