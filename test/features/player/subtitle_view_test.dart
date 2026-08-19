import 'package:cinema_subtitles/domain/subtitle_cue.dart';
import 'package:cinema_subtitles/features/player/subtitle_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves long cues with increased system text scaling', (
    tester,
  ) async {
    final cues = [
      for (var index = 0; index < 3; index++)
        SubtitleCue(
          id: '$index',
          start: Duration.zero,
          end: const Duration(seconds: 10),
          text: 'Long subtitle cue $index ' * 8,
          sourceIndex: index,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 320,
            height: 180,
            child: SubtitleView(cues: cues, preferredFontSize: 42),
          ),
        ),
      ),
    );

    for (final cue in cues) {
      expect(find.byKey(ValueKey(cue.id)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('fades in a new cue without reanimating the previous cue', (
    tester,
  ) async {
    final previous = SubtitleCue(
      id: 'previous',
      start: const Duration(seconds: 10),
      end: const Duration(seconds: 15),
      text: 'Previous subtitle',
      sourceIndex: 0,
    );
    final current = SubtitleCue(
      id: 'current',
      start: const Duration(seconds: 20),
      end: const Duration(seconds: 25),
      text: 'Current subtitle',
      sourceIndex: 1,
    );
    final next = SubtitleCue(
      id: 'next',
      start: const Duration(seconds: 30),
      end: const Duration(seconds: 35),
      text: 'Next subtitle',
      sourceIndex: 2,
    );

    Future<void> pumpView({
      required List<SubtitleCue> cues,
      SubtitleCue? previousCue,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 180,
            child: SubtitleView(
              cues: cues,
              previousCue: previousCue,
              preferredFontSize: 42,
            ),
          ),
        ),
      );
    }

    await pumpView(cues: [previous]);
    final previousFinder = find.byKey(const ValueKey('previous'));
    final previousElement = tester.element(previousFinder);
    final previousPosition = tester.getTopLeft(previousFinder);

    await pumpView(cues: [current], previousCue: previous);

    expect(previousFinder, findsOneWidget);
    expect(tester.element(previousFinder), same(previousElement));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 375));
    expect(tester.hasRunningAnimations, isTrue);
    expect(previousFinder, findsOneWidget);
    expect(tester.element(previousFinder), same(previousElement));
    expect(tester.getTopLeft(previousFinder), previousPosition);

    final currentFinder = find.byKey(const ValueKey('current'));
    final currentFadeValues = tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: currentFinder,
            matching: find.byType(FadeTransition),
          ),
        )
        .map((fade) => fade.opacity.value);
    expect(
      currentFadeValues,
      contains(predicate<double>((value) => value > 0 && value < 1)),
    );
    final transitioningPreviousColor = tester
        .renderObject<RenderParagraph>(previousFinder)
        .text
        .style
        ?.color;
    expect(transitioningPreviousColor?.a, 1);
    expect(transitioningPreviousColor, isNot(Colors.white));
    expect(transitioningPreviousColor, isNot(SubtitleView.previousColor));

    await tester.pumpAndSettle();

    expect(previousFinder, findsOneWidget);
    expect(currentFinder, findsOneWidget);
    expect(tester.getTopLeft(previousFinder), previousPosition);
    expect(
      tester.getTopLeft(previousFinder).dy,
      lessThan(tester.getTopLeft(currentFinder).dy),
    );
    expect(
      tester
          .widget<AnimatedDefaultTextStyle>(
            find.ancestor(
              of: previousFinder,
              matching: find.byType(AnimatedDefaultTextStyle),
            ),
          )
          .style
          .color,
      SubtitleView.previousColor,
    );

    final currentElement = tester.element(currentFinder);
    final currentPosition = tester.getTopLeft(currentFinder);
    await pumpView(cues: [next], previousCue: current);
    await tester.pump(const Duration(milliseconds: 375));

    final nextFinder = find.byKey(const ValueKey('next'));
    expect(tester.element(currentFinder), same(currentElement));
    expect(tester.getTopLeft(currentFinder), currentPosition);
    expect(
      tester.getTopLeft(nextFinder).dy,
      lessThan(tester.getTopLeft(currentFinder).dy),
    );
    final transitioningCurrentColor = tester
        .renderObject<RenderParagraph>(currentFinder)
        .text
        .style
        ?.color;
    expect(transitioningCurrentColor?.a, 1);
    expect(transitioningCurrentColor, isNot(Colors.white));
    expect(transitioningCurrentColor, isNot(SubtitleView.previousColor));
  });
}
