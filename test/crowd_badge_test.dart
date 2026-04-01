// Feature: festival-calendar-crowd-indicator, Property 7: CrowdBadge Content Correctness

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lib/widgets/crowd_badge.dart';
import '../lib/models/festival_event.dart';
import '../lib/providers/festival_provider.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  // 12.1 Full badge rendering for each CrowdLevel
  group('CrowdBadge full mode renders correct color and label', () {
    testWidgets('low level shows green dot and Low Crowd text', (tester) async {
      await tester.pumpWidget(_wrap(const CrowdBadge(level: CrowdLevel.low)));

      expect(find.text('Low Crowd'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.green),
        findsOneWidget,
      );
    });

    testWidgets('moderate level shows amber dot and Moderate text', (tester) async {
      await tester.pumpWidget(_wrap(const CrowdBadge(level: CrowdLevel.moderate)));

      expect(find.text('Moderate'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.amber),
        findsOneWidget,
      );
    });

    testWidgets('high level shows red dot and High Crowd text', (tester) async {
      await tester.pumpWidget(_wrap(const CrowdBadge(level: CrowdLevel.high)));

      expect(find.text('High Crowd'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.red),
        findsOneWidget,
      );
    });
  });

  // 12.2 Compact badge has no text, has tooltip
  group('CrowdBadge compact mode', () {
    testWidgets('compact: true shows no Text widget and has Tooltip', (tester) async {
      await tester.pumpWidget(_wrap(const CrowdBadge(level: CrowdLevel.low, compact: true)));

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Tooltip), findsOneWidget);
    });
  });

  // 12.3 Badge renders inside ProviderScope with overridden festivalProvider
  group('CrowdBadge with ProviderScope override', () {
    testWidgets('renders without exception when festivalProvider overridden with empty list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            festivalProvider.overrideWithValue(const []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: CrowdBadge(level: CrowdLevel.low)),
            ),
          ),
        ),
      );

      // No exception thrown; badge renders normally
      expect(find.byType(CrowdBadge), findsOneWidget);
    });
  });
}
