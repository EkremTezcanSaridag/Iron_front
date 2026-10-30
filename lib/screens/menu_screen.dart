import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../game_state.dart';
import '../theme.dart';
import 'game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.game});

  final GameState game;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    Sfx.playMusic('menu_ambient');
    widget.game.hasSave().then((v) {
      if (mounted) setState(() => _hasSave = v);
    });
  }

  Future<void> _newGame() async {
    await Sfx.play('confirm');
    await Sfx.stopMusic();
    await Sfx.playMusic('ambient');
    widget.game.newGame();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(game: widget.game)),
    );
  }

  Future<void> _continue() async {
    await Sfx.play('confirm');
    await Sfx.stopMusic();
    await Sfx.playMusic('ambient');
    await widget.game.loadGame();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(game: widget.game)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/bg/menu.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: C.bg),
          ),
          const ColoredBox(color: Color(0x6B0D0A08)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, pad.top > 0 ? 12 : 36, 28, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/icon/app_192.png',
                    width: 132,
                    height: 132,
                    filterQuality: FilterQuality.none,
                  ),
                  const SizedBox(height: 18),
                  const TitleText('SIĞINAK', size: 64, center: true),
                  const SizedBox(height: 8),
                  const BodyText(
                    'Felaketten sonra. Kapının ardında.',
                    size: 16,
                    color: C.muted,
                    center: true,
                  ),
                  const Spacer(flex: 2),
                  Semantics(
                    button: true,
                    label: 'Yeni Oyun',
                    child: BunkerButton(label: 'Yeni Oyun', onTap: _newGame, height: 62),
                  ),
                  const SizedBox(height: 12),
                  BunkerButton(
                    label: 'Devam Et',
                    onTap: _hasSave ? _continue : null,
                    height: 62,
                  ),
                  const SizedBox(height: 12),
                  BunkerButton(
                    label: 'Çıkış',
                    onTap: () => SystemNavigator.pop(),
                    height: 52,
                  ),
                  const Spacer(),
                  const BodyText(
                    'Kenney CC0  ·  Barlow (OFL)  ·  v0.3.0',
                    size: 12,
                    color: C.dim,
                    center: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
