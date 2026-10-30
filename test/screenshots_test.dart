import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siginak/audio.dart';
import 'package:siginak/game_state.dart';
import 'package:siginak/screens/game_screen.dart';
import 'package:siginak/screens/menu_screen.dart';
import 'package:siginak/theme.dart';

Future<void> _loadFonts() async {
  Future<void> one(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await one('Barlow', [
    'assets/fonts/Barlow-Regular.ttf',
    'assets/fonts/Barlow-Medium.ttf',
    'assets/fonts/Barlow-SemiBold.ttf',
    'assets/fonts/Barlow-Bold.ttf',
  ]);
  await one('BarlowCondensed', [
    'assets/fonts/BarlowCondensed-Regular.ttf',
    'assets/fonts/BarlowCondensed-SemiBold.ttf',
    'assets/fonts/BarlowCondensed-Bold.ttf',
  ]);
}

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = await boundary.toImage(pixelRatio: 1).timeout(
          const Duration(seconds: 15),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('/tmp/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: bunkerTheme(),
    home: RepaintBoundary(
      key: const ValueKey('shot'),
      child: child,
    ),
  );
}

Widget _sheet(List<Widget> children) {
  return ColoredBox(
    color: const Color(0x6612100E),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        decoration: const BoxDecoration(
          color: Color(0xF21A1612),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: C.amber, width: 2),
            left: BorderSide(color: C.amber, width: 2),
            right: BorderSide(color: C.amber, width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sfx.muted = true;
    GameScreen.clockEnabled = false;
  });

  Future<GameState> prep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = GameState();
    await game.loadDefs();
    return game;
  }

  testWidgets('menu screenshot', (tester) async {
    final game = await prep(tester);
    await tester.pumpWidget(_wrap(MenuScreen(game: game)));
    await _save(tester, 'shot_menu');
  });

  testWidgets('shelter screenshot', (tester) async {
    final game = await prep(tester);
    game.newGame();
    game.skipTutorial();
    await tester.pumpWidget(_wrap(GameScreen(game: game)));
    await _save(tester, 'shot_shelter');
  });

  testWidgets('expedition screenshot', (tester) async {
    final game = await prep(tester);
    game.newGame();
    game.skipTutorial();
    await tester.pumpWidget(
      _wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            GameScreen(game: game),
            _sheet([
              const TitleText('Sefer', size: 28),
              const SizedBox(height: 8),
              const BodyText(
                'Kimleri dışarı yollayacağını ve hedefi seç. Cephane pusu riskini azaltır.',
                size: 14,
                color: C.muted,
              ),
              const SizedBox(height: 12),
              for (final d in (game.defsExp['destinations'] as List).take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BunkerButton(
                    label:
                        '${d['title']}  ·  ${d['phases']} vakit  ·  tehlike ${d['danger']}',
                    selected: d['id'] == 'market',
                    onTap: () {},
                    height: 52,
                  ),
                ),
              const BodyText('Kadro (dokun)', size: 14, color: C.muted),
              const SizedBox(height: 10),
              BunkerButton(label: 'Yola çık', onTap: () {}),
            ]),
          ],
        ),
      ),
    );
    await _save(tester, 'shot_expedition');
  });

  testWidgets('event screenshot', (tester) async {
    final game = await prep(tester);
    game.newGame();
    game.skipTutorial();
    final ev = (game.defsEvents['shelter'] as List).firstWhere(
      (e) => e['id'] == 'stranger',
    ) as Map;
    await tester.pumpWidget(
      _wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            GameScreen(game: game),
            _sheet([
              const BodyText('Sığınak olayı', size: 13, color: C.danger),
              const SizedBox(height: 6),
              TitleText('${ev['title']}', size: 26),
              const SizedBox(height: 10),
              BodyText('${ev['body']}', size: 15),
              const SizedBox(height: 16),
              for (final ch in (ev['choices'] as List))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BunkerButton(
                    label: '${ch['label']}',
                    onTap: () {},
                    height: 58,
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
    await _save(tester, 'shot_event');
  });
}
