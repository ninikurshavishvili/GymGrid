import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/features/check_in/domain/entities/rating.dart';

void main() {
  // The pickers and the chart's axis list the ratings in this order.
  test('runs from 20% to 100% in steps of 20', () {
    expect(Rating.values.map((rating) => rating.percent), [
      20,
      40,
      60,
      80,
      100,
    ]);
  });
}
