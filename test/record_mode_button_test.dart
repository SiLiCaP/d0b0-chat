import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat/video_message/record_mode_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.init(loadWebConfigFile: false);
  });

  setUp(() => AppSettings.recordButtonMode.setItem(RecordMode.voice.name));

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: RecordModeButton(
              size: 48,
              onVoiceMessage: () {},
              onVideoMessage: () {},
            ),
          ),
        ),
      ),
    );
    // Wait for the translations.
    await tester.pumpAndSettle();
  }

  Future<void> swipeUp(WidgetTester tester) async {
    await tester.drag(find.byType(RecordModeButton), const Offset(0, -80));
    // Let the knob snap back; the label stays up for 1.2 s longer. The
    // snap-back starts on the next frame, the button returns on the frame
    // after it ends.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  double buttonOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byType(IconButton),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  /// How visible the lit knob of the swipe track is, if it is there.
  double knobOpacity(WidgetTester tester) {
    final knob = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle,
    );
    if (knob.evaluate().isEmpty) return 0;
    return tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(of: knob, matching: find.byType(AnimatedOpacity)),
        )
        .fold(1.0, (opacity, widget) => opacity * widget.opacity);
  }

  // #54: the label naming the mode must not hold up the next swipe.
  testWidgets('switches again while the label is still up', (tester) async {
    await pumpButton(tester);

    await swipeUp(tester);
    expect(AppSettings.recordButtonMode.value, RecordMode.video.name);
    expect(find.text('Video message'), findsWidgets);

    await swipeUp(tester);
    expect(AppSettings.recordButtonMode.value, RecordMode.voice.name);

    await tester.pump(const Duration(seconds: 2));
  });

  // #54: after a switch the resting tonal button is back, not the lit knob.
  testWidgets('rests unlit after a switch', (tester) async {
    await pumpButton(tester);
    expect(buttonOpacity(tester), 1);

    await swipeUp(tester);
    expect(find.text('Video message'), findsWidgets);
    expect(knobOpacity(tester), 0);
    expect(buttonOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 2));
  });
}
