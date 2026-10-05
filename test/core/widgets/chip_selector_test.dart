import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_grid/core/widgets/chip_selector.dart';

import '../../helpers/pump_themed.dart';

const _options = ['Strength', 'Cardio', 'Mobility', 'Other'];

Widget _selector({String? selected, ValueChanged<String>? onSelected}) {
  return ChipSelector<String>(
    options: _options,
    selected: selected,
    labelOf: (option) => option,
    onSelected: onSelected ?? (_) {},
  );
}

void main() {
  testWidgets('tapping a chip reports its option', (tester) async {
    String? picked;
    await pumpThemed(tester, _selector(onSelected: (o) => picked = o));

    await tester.tap(find.text('Mobility'));

    expect(picked, 'Mobility');
  });

  testWidgets('chips are announced as a single-choice group', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(tester, _selector(selected: 'Cardio'));

    expect(
      tester.getSemantics(find.text('Cardio')),
      isSemantics(
        label: 'Cardio',
        isButton: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Strength')),
      isSemantics(label: 'Strength', isSelected: false),
    );
    semantics.dispose();
  });

  Set<double> rowsOf(WidgetTester tester) => {
    for (final o in _options) tester.getRect(find.text(o)).center.dy,
  };

  Set<String> chipWidthsOf(WidgetTester tester) => {
    for (final o in _options)
      tester
          .getSize(
            find.ancestor(of: find.text(o), matching: find.byType(InkWell)),
          )
          .width
          .toStringAsFixed(1),
  };

  testWidgets('at normal text size all chips share one row equally', (
    tester,
  ) async {
    await pumpThemed(tester, _selector());

    expect(rowsOf(tester), hasLength(1));
    expect(chipWidthsOf(tester), hasLength(1));
  });

  testWidgets('at 3x text size chips fall back to an even grid', (
    tester,
  ) async {
    await pumpThemed(tester, _selector(selected: 'Strength'), textScale: 3);

    expect(tester.takeException(), isNull);
    expect(rowsOf(tester).length, greaterThan(1));
    expect(chipWidthsOf(tester), hasLength(1));
  });
}
