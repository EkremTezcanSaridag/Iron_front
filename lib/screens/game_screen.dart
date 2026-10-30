import 'dart:async';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../game_state.dart';
import '../theme.dart';
import 'menu_screen.dart';

const _resIcons = {
  'food': 'assets/art/icons/hud_food.png',
  'water': 'assets/art/icons/hud_water.png',
  'power': 'assets/art/icons/hud_power.png',
  'medicine': 'assets/art/icons/hud_medicine.png',
  'scrap': 'assets/art/icons/hud_scrap.png',
  'ammo': 'assets/art/icons/hud_ammo.png',
};

const _needTr = {
  'need_ammo': 'cephane',
  'need_food': 'yiyecek',
  'need_water': 'su',
  'need_scrap': 'hurda',
  'need_medicine': 'ilaç',
};

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});

  final GameState game;

  /// Widget tests set this false so golden captures can idle.
  static bool clockEnabled = true;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _timer;
  bool _endingShown = false;
  bool _sheetOpen = false;

  GameState get g => widget.game;

  @override
  void initState() {
    super.initState();
    g.addListener(_onState);
    if (GameScreen.clockEnabled) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        g.tick(0.1);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTutorial());
  }

  @override
  void dispose() {
    _timer?.cancel();
    g.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    setState(() {});
    if (g.ended && !_endingShown) {
      _endingShown = true;
      _showEnding();
    }
    if (g.pendingEvent != null && !_sheetOpen) {
      _showEvent(g.pendingEvent!, expedition: false);
    } else if (g.expeditionCard != null && !_sheetOpen) {
      _showEvent(g.expeditionCard!, expedition: true);
    }
  }

  Future<void> _maybeTutorial() async {
    if (g.tutorialDone || g.pendingEvent != null) return;
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const TitleText('İlk gün', size: 28),
            const SizedBox(height: 10),
            BodyText(g.tutorialText(), size: 16),
            const SizedBox(height: 18),
            BunkerButton(
              label: 'Devam',
              onTap: () {
                Sfx.play('click');
                g.advanceTutorial();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            BunkerButton(
              label: 'Atla',
              onTap: () {
                g.skipTutorial();
                Navigator.pop(ctx);
              },
              height: 48,
            ),
          ],
        ),
      ),
    );
    _sheetOpen = false;
    if (mounted && !g.tutorialDone) {
      await _maybeTutorial();
    }
  }

  Future<void> _showEvent(Map<String, dynamic> ev, {required bool expedition}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    Sfx.play('question');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _Sheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              BodyText(
                expedition ? 'Sefer notu' : 'Sığınak olayı',
                size: 13,
                color: C.danger,
              ),
              const SizedBox(height: 6),
              TitleText('${ev['title'] ?? ''}', size: 26),
              const SizedBox(height: 10),
              BodyText('${ev['body'] ?? ''}', size: 15),
              const SizedBox(height: 16),
              for (final raw in (ev['choices'] as List? ?? []))
                if (raw is Map)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BunkerButton(
                      label: _choiceLabel(raw),
                      onTap: () {
                        g.resolveEvent('${raw['id']}');
                        Navigator.pop(ctx);
                      },
                      height: 58,
                    ),
                  ),
            ],
          ),
        );
      },
    );
    _sheetOpen = false;
  }

  String _choiceLabel(Map raw) {
    var extra = '';
    for (final k in _needTr.keys) {
      final n = asInt(raw[k]);
      if (n > 0) extra += '  ·  ${_needTr[k]} $n';
    }
    return '${raw['label'] ?? ''}$extra';
  }

  Future<void> _showEnding() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _Sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TitleText(
              g.won ? 'Kurtuluş' : 'Sessizlik',
              size: 32,
              color: g.won ? C.ok : C.danger,
            ),
            const SizedBox(height: 10),
            BodyText(g.endReason, size: 16),
            const SizedBox(height: 12),
            TitleText('Skor  ${g.score}', size: 24),
            const SizedBox(height: 18),
            BunkerButton(label: 'Ana menü', onTap: () => _backMenu()),
          ],
        ),
      ),
    );
    _sheetOpen = false;
  }

  Future<void> _openExpedition() async {
    Sfx.play('open');
    var destId = 'market';
    final people = <String>{};
    var ammo = 0;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            final dests = (g.defsExp['destinations'] as List? ?? []).whereType<Map>();
            return _Sheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TitleText('Sefer', size: 28),
                  const SizedBox(height: 8),
                  const BodyText(
                    'Kimleri dışarı yollayacağını ve hedefi seç. Cephane pusu riskini azaltır.',
                    size: 14,
                    color: C.muted,
                  ),
                  const SizedBox(height: 12),
                  for (final d in dests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BunkerButton(
                        label:
                            '${d['title']}  ·  ${d['phases']} vakit  ·  tehlike ${d['danger']}',
                        selected: destId == d['id'],
                        onTap: () {
                          Sfx.play('click');
                          setS(() => destId = '${d['id']}');
                        },
                        height: 52,
                      ),
                    ),
                  const BodyText('Kadro (dokun)', size: 14, color: C.muted),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.livingSurvivors())
                        GestureDetector(
                          onTap: () {
                            setS(() {
                              if (people.contains(s.id)) {
                                people.remove(s.id);
                              } else {
                                people.add(s.id);
                              }
                            });
                          },
                          child: _Portrait(
                            survivor: s,
                            size: 56,
                            selected: people.contains(s.id),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BunkerButton(
                    label: 'Cephane ayır: $ammo',
                    onTap: () {
                      setS(() {
                        final maxA = (g.resources['ammo']! + 1).clamp(1, 4);
                        ammo = (ammo + 1) % maxA;
                      });
                    },
                    height: 48,
                  ),
                  const SizedBox(height: 10),
                  BunkerButton(
                    label: 'Yola çık',
                    onTap: () {
                      if (g.startExpedition(destId, people.toList(), ammo)) {
                        Navigator.pop(ctx);
                      } else {
                        Sfx.play('error');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  BunkerButton(
                    label: 'Kapat',
                    onTap: () => Navigator.pop(ctx),
                    height: 48,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _sheetOpen = false;
  }

  Future<void> _openBuild() async {
    Sfx.play('open');
    String chosenRoom = '';
    String chosenType = '';
    final empties = [for (final r in g.rooms) if (r.type == 'empty') r];
    const types = [
      'living',
      'hydroponics',
      'water',
      'generator',
      'storage',
      'infirmary',
      'workshop',
      'radio',
    ];
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return _Sheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TitleText('İnşa', size: 28),
                  const SizedBox(height: 8),
                  BodyText(
                    'Boş bir oyuk seç, sonra oda tipi. Hurda: ${g.resources['scrap']}',
                    size: 14,
                    color: C.muted,
                  ),
                  const SizedBox(height: 12),
                  if (empties.isEmpty)
                    const BodyText('Boş oyuk yok.', color: C.danger)
                  else
                    for (final r in empties)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: BunkerButton(
                          label: 'Kat ${r.floor + 1} · oyuk ${r.slot + 1}',
                          selected: chosenRoom == r.id,
                          onTap: () => setS(() => chosenRoom = r.id),
                          height: 48,
                        ),
                      ),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.4,
                    children: [
                      for (final type in types)
                        Builder(
                          builder: (_) {
                            final def = g.defsRooms[type];
                            final isMap = def is Map;
                            final title = isMap ? def['title'] : type;
                            final cost = isMap ? def['build_scrap'] : 0;
                            final locked =
                                isMap && g.day < asInt(def['unlock_day'], 1);
                            return BunkerButton(
                              label: locked
                                  ? '$title\ngün ${isMap ? def['unlock_day'] : '?'}'
                                  : '$title  ($cost hurda)',
                              selected: chosenType == type,
                              onTap: locked
                                  ? null
                                  : () => setS(() => chosenType = type),
                              height: 52,
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  BunkerButton(
                    label: 'Kur',
                    onTap: () {
                      final slot = g.roomById(chosenRoom);
                      if (slot != null &&
                          g.buildRoom(slot.floor, slot.slot, chosenType)) {
                        Navigator.pop(ctx);
                      } else {
                        Sfx.play('error');
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  BunkerButton(
                    label: 'Kapat',
                    onTap: () => Navigator.pop(ctx),
                    height: 48,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _sheetOpen = false;
  }

  Future<void> _backMenu() async {
    await g.saveGame();
    await Sfx.stopMusic();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MenuScreen(game: g)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = g.survivorById(g.selectedSurvivor);
    final selectedRoom = g.roomById(g.selectedRoom);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/bg/game.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: C.bg),
          ),
          const ColoredBox(color: Color(0x6612100E)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  _TopBar(game: g),
                  const SizedBox(height: 8),
                  _ResourceGrid(game: g),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onLongPress: () {
                      g.forceEvent('stranger');
                    },
                    child: _RadioRow(game: g),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: C.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const BodyText(
                            'Yüzey — zehirli rüzgâr',
                            size: 13,
                            color: C.danger,
                          ),
                        ),
                        for (var floor = 0; floor < maxFloor; floor++) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                            child: TitleText('Kat ${floor + 1}', size: 16, color: C.dim),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var slot = 0; slot < slotsPerFloor; slot++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: slot == 0 ? 5 : 0,
                                      left: slot == 1 ? 5 : 0,
                                    ),
                                    child: _RoomCard(
                                      game: g,
                                      room: g.roomAt(floor, slot),
                                      onTap: (id) {
                                        Sfx.play('click');
                                        if (g.selectedSurvivor.isNotEmpty) {
                                          g.assignSelectedToRoom(id);
                                        } else {
                                          g.selectRoom(id);
                                        }
                                      },
                                      onPortrait: (id) {
                                        Sfx.play('click');
                                        g.selectSurvivor(id);
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ContextPanel(
                    game: g,
                    survivor: selected,
                    room: selectedRoom,
                    onUpgrade: () {
                      if (selectedRoom != null) g.upgradeRoom(selectedRoom.id);
                    },
                    onSelect: (id) {
                      Sfx.play('click');
                      g.selectSurvivor(id);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: BunkerButton(
                          label: 'Sefer',
                          onTap: _openExpedition,
                          height: 52,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BunkerButton(
                          label: 'İnşa',
                          onTap: _openBuild,
                          height: 52,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 92,
                        child: BunkerButton(
                          label: 'Menü',
                          onTap: _backMenu,
                          height: 52,
                          expand: true,
                        ),
                      ),
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: () => game.forceExpeditionCard('alley'),
            child: const TitleText('SIĞINAK', size: 26),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TitleText('${game.day}. GÜN', size: 18, color: C.cream),
            BodyText(phaseNames[game.phase], size: 12, color: C.muted, maxLines: 1),
          ],
        ),
        const SizedBox(width: 8),
        for (final e in const [(0, 'II'), (1, '1x'), (2, '2x')])
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(
              width: 52,
              child: BunkerButton(
                label: e.$2,
                selected: game.speed == e.$1,
                onTap: () {
                  Sfx.play('click');
                  game.setSpeed(e.$1);
                },
                height: 40,
                expand: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 2.8,
      children: [
        for (final id in game.resourceSummary())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: C.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Image.asset(
                  _resIcons[id]!,
                  width: 22,
                  height: 22,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => const SizedBox(width: 22, height: 22),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TitleText(
                    '${game.resources[id]}',
                    size: 18,
                    color: C.cream,
                    condensed: true,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: BodyText(
            'Telsiz  ${game.radioProgress.round()}%',
            size: 13,
            color: C.muted,
            maxLines: 1,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (game.radioProgress / 100).clamp(0, 1),
              minHeight: 14,
              backgroundColor: const Color(0xFF1A1612),
              color: C.amber,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.game,
    required this.room,
    required this.onTap,
    required this.onPortrait,
  });

  final GameState game;
  final Room? room;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onPortrait;

  @override
  Widget build(BuildContext context) {
    if (room == null) return const SizedBox.shrink();
    final selected = room!.id == game.selectedRoom;
    final type = room!.type.isEmpty ? 'empty' : room!.type;
    return GestureDetector(
      onTap: () => onTap(room!.id),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161310),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? C.amber : C.border,
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                'assets/art/rooms/$type.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, _, _) => const ColoredBox(color: C.chip),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Column(
                children: [
                  TitleText(
                    game.roomTitle(type),
                    size: 14,
                    color: C.cream,
                    center: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in game.workersOf(room!))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () => onPortrait(s.id),
                            child: _Portrait(survivor: s, size: 28, selected: s.id == game.selectedSurvivor),
                          ),
                        ),
                      if (game.workersOf(room!).isEmpty)
                        const BodyText('boş', size: 11, color: C.dim),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.survivor,
    required this.size,
    this.selected = false,
  });

  final Survivor survivor;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    Color border = C.border;
    if (selected) border = C.amberSoft;
    if (survivor.health < 35) border = C.danger;
    if (survivor.away) border = C.danger;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ColorFiltered(
        colorFilter: survivor.alive
            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Image.asset(
          'assets/art/portraits/p${survivor.portrait}.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) => ColoredBox(
            color: C.chip,
            child: Icon(Icons.person, size: size * 0.6, color: C.muted),
          ),
        ),
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.game,
    required this.survivor,
    required this.room,
    required this.onUpgrade,
    required this.onSelect,
  });

  final GameState game;
  final Survivor? survivor;
  final Room? room;
  final VoidCallback onUpgrade;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: survivor != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Portrait(
                      survivor: survivor!,
                      size: 52,
                      selected: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText(survivor!.name, size: 20, color: C.amber),
                          BodyText(
                            game.traitTitle(survivor!.trait),
                            size: 13,
                            color: C.muted,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StatBar(label: 'Sağlık', value: survivor!.health, color: C.danger),
                const SizedBox(height: 4),
                StatBar(label: 'Açlık', value: survivor!.hunger, color: C.amber),
                const SizedBox(height: 4),
                StatBar(label: 'Susuzluk', value: survivor!.thirst, color: C.water),
                const SizedBox(height: 4),
                StatBar(label: 'Moral', value: survivor!.morale, color: C.ok),
              ],
            )
          : room != null && room!.type != 'empty'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TitleText(game.roomTitle(room!.type), size: 20),
                    const SizedBox(height: 4),
                    BodyText(
                      '${game.defsRooms[room!.type] is Map ? game.defsRooms[room!.type]['blurb'] : ''}',
                      size: 13,
                      color: C.muted,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    BodyText(
                      'Seviye ${room!.level}  ·  çalışan ${game.workersOf(room!).length}',
                      size: 13,
                    ),
                    const Spacer(),
                    BunkerButton(
                      label: 'Yükselt',
                      onTap: room!.level >= 3 ? null : onUpgrade,
                      height: 42,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BodyText(
                      'Kişiler — dokun, sonra odaya yerleştir',
                      size: 13,
                      color: C.muted,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final s in game.survivors)
                            if (s.alive)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => onSelect(s.id),
                                  child: Column(
                                    children: [
                                      _Portrait(
                                        survivor: s,
                                        size: 52,
                                        selected: s.id == game.selectedSurvivor,
                                      ),
                                      const SizedBox(height: 4),
                                      BodyText(
                                        s.away ? '${s.name} · dışarı' : s.name,
                                        size: 11,
                                        color: s.away ? C.danger : C.cream,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Color(0xF21A1612),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top: BorderSide(color: C.amber, width: 2),
            left: BorderSide(color: C.amber, width: 2),
            right: BorderSide(color: C.amber, width: 2),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: child,
        ),
      ),
    );
  }
}
