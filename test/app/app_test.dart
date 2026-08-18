import 'package:cinema_subtitles/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the project-ready screen', (tester) async {
    await tester.pumpWidget(const CinemaSubtitlesApp());

    expect(find.text('Cinema Subtitles'), findsOneWidget);
    expect(find.text('Offline subtitle clock'), findsOneWidget);
    expect(find.text('Open subtitle file'), findsOneWidget);
  });
}
