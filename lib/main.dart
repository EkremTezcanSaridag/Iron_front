import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_state.dart';
import 'screens/menu_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final game = GameState();
  await game.loadDefs();
  runApp(SiginakApp(game: game));
}

class SiginakApp extends StatelessWidget {
  const SiginakApp({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sığınak',
      debugShowCheckedModeBanner: false,
      theme: bunkerTheme(),
      home: MenuScreen(game: game),
    );
  }
}
