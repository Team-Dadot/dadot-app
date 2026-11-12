import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/data/models/interview.dart';
import 'package:swipe/features/interview/interview_widgets.dart';

void main() {
  CriterionScore c(num score) => CriterionScore(key: CriterionKey.logic, score: score.toInt());

  test('10점 이하는 막대 길이 10점 분량 + 검정', () {
    expect(CriteriaList.fillRatio(c(3)), closeTo(10 / 25, 1e-9));
    expect(CriteriaList.fillRatio(c(10)), closeTo(10 / 25, 1e-9));
    expect(CriteriaList.isLow(c(3)), isTrue);
    expect(CriteriaList.isLow(c(10)), isTrue);
  });

  test('11점부터는 실제 점수만큼 + 라임', () {
    expect(CriteriaList.fillRatio(c(11)), closeTo(11 / 25, 1e-9));
    expect(CriteriaList.fillRatio(c(25)), 1.0);
    expect(CriteriaList.isLow(c(11)), isFalse);
  });
}
