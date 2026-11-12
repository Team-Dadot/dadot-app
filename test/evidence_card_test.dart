import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/data/models/quiz.dart';
import 'package:swipe/features/interview/interview_widgets.dart';

Widget _host(List<Evidence> e) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: EvidenceFolderCard(evidence: e))));

void main() {
  const a = Evidence(title: '기아 2025 사업보고서', excerpt: '근거 하나', publishedAt: '2026.03.12', period: '2025.01.01 – 2025.12.31');
  const b = Evidence(title: '기아 2025 사업보고서', excerpt: '근거 둘');
  const c = Evidence(title: '기아 2025 사업보고서', excerpt: '근거 둘', publishedAt: '2026.03.12', period: '2025.01.01 – 2025.12.31');

  testWidgets('근거 2개: 구분선 1개 + 공시 정보 칸은 맨 아래 하나', (t) async {
    await t.pumpWidget(_host([a, a]));
    expect(find.byType(Divider), findsOneWidget);
    expect(find.textContaining('공시일'), findsOneWidget);
    expect(find.textContaining('대상 기간'), findsOneWidget);
  });

  testWidgets('근거 1개: 구분선 없음, 공시 정보는 있다', (t) async {
    await t.pumpWidget(_host([a]));
    expect(find.byType(Divider), findsNothing);
    expect(find.textContaining('공시일'), findsOneWidget);
  });

  testWidgets('첫 근거에 날짜가 없어도 다음 근거의 공시 정보를 보여 준다', (t) async {
    await t.pumpWidget(_host([b, c]));
    expect(find.textContaining('공시일'), findsOneWidget);
    expect(find.textContaining('대상 기간'), findsOneWidget);
  });
}
