import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio.dart';

const phaseSeconds = 11.0;
const phaseNames = ['Sabah', 'Öğlen', 'Akşam', 'Gece'];
const maxFloor = 4;
const slotsPerFloor = 2;
const saveKey = 'siginak_save';

int asInt(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

double asDouble(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

bool asBool(dynamic v, [bool d = false]) {
  if (v is bool) return v;
  return d;
}

class Survivor {
  Survivor({
    required this.id,
    required this.name,
    required this.portrait,
    required this.trait,
    required this.skills,
    this.health = 100,
    this.hunger = 78,
    this.thirst = 74,
    this.morale = 70,
    this.alive = true,
    this.away = false,
    this.room = '',
  });

  String id;
  String name;
  int portrait;
  String trait;
  Map<String, int> skills;
  double health;
  double hunger;
  double thirst;
  double morale;
  bool alive;
  bool away;
  String room;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'portrait': portrait,
        'trait': trait,
        'skills': skills,
        'health': health,
        'hunger': hunger,
        'thirst': thirst,
        'morale': morale,
        'alive': alive,
        'away': away,
        'room': room,
      };

  factory Survivor.fromJson(Map<String, dynamic> j) {
    final rawSkills = j['skills'];
    final skills = <String, int>{};
    if (rawSkills is Map) {
      rawSkills.forEach((k, v) => skills['$k'] = asInt(v));
    }
    return Survivor(
      id: '${j['id']}',
      name: '${j['name']}',
      portrait: asInt(j['portrait']),
      trait: '${j['trait'] ?? ''}',
      skills: skills,
      health: asDouble(j['health'], 100),
      hunger: asDouble(j['hunger'], 70),
      thirst: asDouble(j['thirst'], 70),
      morale: asDouble(j['morale'], 70),
      alive: asBool(j['alive'], true),
      away: asBool(j['away']),
      room: '${j['room'] ?? ''}',
    );
  }
}

class Room {
  Room({
    required this.id,
    required this.type,
    required this.floor,
    required this.slot,
    this.level = 1,
    this.built = true,
  });

  String id;
  String type;
  int floor;
  int slot;
  int level;
  bool built;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'floor': floor,
        'slot': slot,
        'level': level,
        'built': built,
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: '${j['id']}',
        type: '${j['type']}',
        floor: asInt(j['floor']),
        slot: asInt(j['slot']),
        level: asInt(j['level'], 1),
        built: asBool(j['built'], true),
      );
}

class GameState extends ChangeNotifier {
  GameState();

  final Random rng = Random();
  Map<String, dynamic> defsRooms = {};
  Map<String, dynamic> defsEvents = {};
  Map<String, dynamic> defsExp = {};
  Map<String, dynamic> defsNames = {};

  int day = 1;
  int phase = 0;
  int speed = 1;
  double phaseClock = 0;
  double radioProgress = 0;
  int lowMoraleDays = 0;
  bool ended = false;
  bool won = false;
  String endReason = '';
  int tutorialStep = 0;
  bool tutorialDone = false;
  String selectedSurvivor = '';
  String selectedRoom = '';
  int lastSaveUnix = 0;
  int score = 0;
  List<String> logLines = [];

  Map<String, int> resources = {
    'food': 42,
    'water': 40,
    'power': 18,
    'medicine': 8,
    'scrap': 28,
    'ammo': 7,
  };
  Map<String, int> caps = {
    'food': 60,
    'water': 60,
    'power': 40,
    'medicine': 24,
    'scrap': 80,
    'ammo': 24,
  };

  List<Survivor> survivors = [];
  List<Room> rooms = [];
  Map<String, dynamic> expedition = {};
  Map<String, dynamic>? pendingEvent;
  int survivorSeq = 1;
  int roomSeq = 1;

  bool get hasActiveExpedition => expedition['active'] == true;
  Map<String, dynamic>? get expeditionCard {
    final c = expedition['card'];
    if (c is Map && c.isNotEmpty) return Map<String, dynamic>.from(c);
    return null;
  }

  Future<void> loadDefs() async {
    defsRooms = json.decode(await rootBundle.loadString('data/rooms.json'))
        as Map<String, dynamic>;
    defsEvents = json.decode(await rootBundle.loadString('data/events.json'))
        as Map<String, dynamic>;
    defsExp = json.decode(await rootBundle.loadString('data/expeditions.json'))
        as Map<String, dynamic>;
    defsNames = json.decode(await rootBundle.loadString('data/names.json'))
        as Map<String, dynamic>;
  }

  void tick(double dt) {
    if (ended || speed <= 0) return;
    if (pendingEvent != null || expeditionCard != null) return;
    phaseClock += dt * speed;
    if (phaseClock >= phaseSeconds) {
      phaseClock = 0;
      advancePhase();
    }
  }

  void newGame() {
    ended = false;
    won = false;
    endReason = '';
    day = 1;
    phase = 0;
    speed = 1;
    phaseClock = 0;
    radioProgress = 0;
    lowMoraleDays = 0;
    tutorialStep = 0;
    tutorialDone = false;
    selectedSurvivor = '';
    selectedRoom = '';
    score = 0;
    logLines = [];
    survivorSeq = 1;
    roomSeq = 1;
    resources = {
      'food': 42,
      'water': 40,
      'power': 18,
      'medicine': 8,
      'scrap': 28,
      'ammo': 7,
    };
    caps = {
      'food': 60,
      'water': 60,
      'power': 40,
      'medicine': 24,
      'scrap': 80,
      'ammo': 24,
    };
    expedition = {};
    pendingEvent = null;
    rooms = [];
    survivors = [];
    _addRoom('living', 0, 0);
    _addRoom('generator', 0, 1);
    _addRoom('water', 1, 0);
    _addRoom('hydroponics', 1, 1);
    _addRoom('storage', 2, 0);
    _addEmpty(2, 1);
    _addEmpty(3, 0);
    _addEmpty(3, 1);
    final starters = [
      {
        'portrait': 0,
        'trait': 'usta',
        'skills': {'tech': 3, 'combat': 1, 'scavenge': 1, 'medical': 0, 'cook': 1},
      },
      {
        'portrait': 1,
        'trait': 'sefkatli',
        'skills': {'tech': 0, 'combat': 0, 'scavenge': 1, 'medical': 3, 'cook': 2},
      },
      {
        'portrait': 2,
        'trait': 'gezgin',
        'skills': {'tech': 1, 'combat': 2, 'scavenge': 3, 'medical': 0, 'cook': 0},
      },
      {
        'portrait': 3,
        'trait': 'caliskan',
        'skills': {'tech': 1, 'combat': 0, 'scavenge': 1, 'medical': 1, 'cook': 3},
      },
    ];
    final used = <String>[];
    for (final spec in starters) {
      survivors.add(_makeSurvivor(
        spec['portrait'] as int,
        spec['trait'] as String,
        Map<String, int>.from(spec['skills'] as Map),
        used,
      ));
    }
    _assign(survivors[0].id, rooms[1].id);
    _assign(survivors[1].id, rooms[2].id);
    _assign(survivors[2].id, rooms[3].id);
    _assign(survivors[3].id, rooms[0].id);
    _log('Sığınak kapısı kilitlendi. Dışarıda dünya bitti. İçeride dört kişi kaldı.');
    saveGame();
    notifyListeners();
  }

  Future<bool> hasSave() async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(saveKey);
  }

  Future<void> saveGame() async {
    lastSaveUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final blob = {
      'day': day,
      'phase': phase,
      'radio': radioProgress,
      'low_morale_days': lowMoraleDays,
      'ended': ended,
      'won': won,
      'end_reason': endReason,
      'tutorial_step': tutorialStep,
      'tutorial_done': tutorialDone,
      'resources': resources,
      'caps': caps,
      'survivors': survivors.map((s) => s.toJson()).toList(),
      'rooms': rooms.map((r) => r.toJson()).toList(),
      'expedition': expedition,
      'survivor_seq': survivorSeq,
      'room_seq': roomSeq,
      'log': logLines.length > 40 ? logLines.sublist(logLines.length - 40) : logLines,
      'last_save_unix': lastSaveUnix,
      'score': score,
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(saveKey, json.encode(blob));
  }

  Future<bool> loadGame() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(saveKey);
    if (raw == null) return false;
    final d = json.decode(raw);
    if (d is! Map) return false;
    day = asInt(d['day'], 1);
    phase = asInt(d['phase']);
    radioProgress = asDouble(d['radio']);
    lowMoraleDays = asInt(d['low_morale_days']);
    ended = asBool(d['ended']);
    won = asBool(d['won']);
    endReason = '${d['end_reason'] ?? ''}';
    tutorialStep = asInt(d['tutorial_step']);
    tutorialDone = asBool(d['tutorial_done']);
    resources = _intMap(d['resources'], resources);
    caps = _intMap(d['caps'], caps);
    survivors = [];
    for (final s in (d['survivors'] as List? ?? [])) {
      if (s is Map) survivors.add(Survivor.fromJson(Map<String, dynamic>.from(s)));
    }
    rooms = [];
    for (final r in (d['rooms'] as List? ?? [])) {
      if (r is Map) rooms.add(Room.fromJson(Map<String, dynamic>.from(r)));
    }
    expedition = d['expedition'] is Map
        ? Map<String, dynamic>.from(d['expedition'] as Map)
        : {};
    survivorSeq = asInt(d['survivor_seq'], 8);
    roomSeq = asInt(d['room_seq'], 8);
    logLines = [
      for (final l in (d['log'] as List? ?? [])) '$l',
    ];
    score = asInt(d['score']);
    pendingEvent = null;
    speed = 0;
    phaseClock = 0;
    final savedUnix = asInt(d['last_save_unix']);
    if (savedUnix > 0 && !ended) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final hours = ((now - savedUnix) / 3600).floor().clamp(0, 8);
      final ticks = hours * 2;
      for (var i = 0; i < ticks; i++) {
        _simulatePhase(true);
      }
    }
    await saveGame();
    notifyListeners();
    return true;
  }

  void setSpeed(int v) {
    speed = v;
    notifyListeners();
  }

  List<Survivor> livingSurvivors() => [
        for (final s in survivors)
          if (s.alive && !s.away) s,
      ];

  Survivor? survivorById(String id) {
    for (final s in survivors) {
      if (s.id == id) return s;
    }
    return null;
  }

  Room? roomById(String id) {
    for (final r in rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  Room? roomAt(int floor, int slot) {
    for (final r in rooms) {
      if (r.floor == floor && r.slot == slot) return r;
    }
    return null;
  }

  void assignSelectedToRoom(String roomId) {
    if (selectedSurvivor.isEmpty) {
      selectedRoom = roomId;
      notifyListeners();
      return;
    }
    _assign(selectedSurvivor, roomId);
    if (tutorialStep == 1) advanceTutorial();
    saveGame();
    notifyListeners();
  }

  void selectSurvivor(String id) {
    selectedSurvivor = id;
    notifyListeners();
  }

  void selectRoom(String id) {
    selectedRoom = id;
    notifyListeners();
  }

  bool buildRoom(int floor, int slot, String type) {
    final def = defsRooms[type];
    if (def is! Map) return false;
    if (day < asInt(def['unlock_day'], 1)) return false;
    final cost = asInt(def['build_scrap'], 12);
    if (resources['scrap']! < cost) return false;
    final existing = roomAt(floor, slot);
    if (existing == null || existing.type != 'empty') return false;
    resources['scrap'] = resources['scrap']! - cost;
    existing.type = type;
    existing.level = 1;
    existing.built = true;
    if (type == 'storage') _recomputeCaps();
    _log('${def['title'] ?? type} kuruldu.');
    if (tutorialStep == 3) advanceTutorial();
    saveGame();
    notifyListeners();
    Sfx.play('confirm');
    return true;
  }

  bool upgradeRoom(String roomId) {
    final r = roomById(roomId);
    if (r == null || r.type == 'empty') return false;
    final def = defsRooms[r.type];
    if (def is! Map) return false;
    final cost = asInt(def['upgrade_scrap'], 18) + r.level * 6;
    if (r.level >= 3) return false;
    if (resources['scrap']! < cost) return false;
    resources['scrap'] = resources['scrap']! - cost;
    r.level += 1;
    if (r.type == 'storage') _recomputeCaps();
    _log('${def['title'] ?? r.type} yükseltildi (svi ${r.level}).');
    saveGame();
    notifyListeners();
    Sfx.play('confirm');
    return true;
  }

  bool startExpedition(String destId, List<String> survivorIds, int spendAmmo) {
    if (hasActiveExpedition) return false;
    if (survivorIds.isEmpty) return false;
    Map<String, dynamic>? dest;
    for (final d in (defsExp['destinations'] as List? ?? [])) {
      if (d is Map && d['id'] == destId) {
        dest = Map<String, dynamic>.from(d);
        break;
      }
    }
    if (dest == null) return false;
    spendAmmo = spendAmmo.clamp(0, resources['ammo']!);
    resources['ammo'] = resources['ammo']! - spendAmmo;
    for (final sid in survivorIds) {
      final s = survivorById(sid);
      if (s == null) continue;
      s.away = true;
      s.room = '';
    }
    expedition = {
      'active': true,
      'dest': destId,
      'title': dest['title'] ?? destId,
      'left': asInt(dest['phases'], 3),
      'people': List<String>.from(survivorIds),
      'ammo': spendAmmo,
      'danger': asInt(dest['danger'], 30),
      'loot': dest['loot'] ?? {},
      'log': [],
      'card': {},
    };
    _log('Sefer yola çıktı: ${dest['title']} (${survivorIds.length} kişi).');
    if (tutorialStep == 2) advanceTutorial();
    saveGame();
    notifyListeners();
    Sfx.play('door');
    return true;
  }

  void resolveEvent(String choiceId) {
    if (pendingEvent == null && expeditionCard == null) return;
    if (pendingEvent != null) {
      _applyShelterChoice(pendingEvent!, choiceId);
      pendingEvent = null;
    } else if (expeditionCard != null) {
      _applyExpChoice(expeditionCard!, choiceId);
      expedition['card'] = {};
    }
    saveGame();
    notifyListeners();
    Sfx.play('click');
  }

  void advanceTutorial() {
    if (tutorialDone) return;
    tutorialStep += 1;
    if (tutorialStep >= 5) {
      tutorialDone = true;
      tutorialStep = 5;
      _log('İlk gün bitti sayılır. Bundan sonrası size kalmış.');
    }
    notifyListeners();
  }

  void skipTutorial() {
    tutorialDone = true;
    tutorialStep = 5;
    notifyListeners();
  }

  String tutorialText() {
    switch (tutorialStep) {
      case 0:
        return 'Kapı kilitlendi. Bu bir sığınak kesiti — odalara dokun, insanları yerleştir. Kaynaklar her vakit diliminde akar.';
      case 1:
        return 'Bir kişi seç, sonra bir odaya dokun. Jeneratör, su ve hidroponik dolu olmalı; yoksa gece uzun sürer.';
      case 2:
        return 'Dışarı çıkmak gerekir. Alttaki SEFER ile yağmaya gönder. Geri dönmeyebilirler.';
      case 3:
        return 'Hurda biriktikçe boş oyuklara oda inşa et. Telsiz odası kurtuluşun anahtarı.';
      case 4:
        return 'Duraklat / 1x / 2x ile zamanı yönet. Hedef: telsizi onarıp kurtarma çağrısı yapmak, ya da 21 gün dayanmak.';
      default:
        return '';
    }
  }

  void forceEvent([String id = 'stranger']) {
    for (final ev in (defsEvents['shelter'] as List? ?? [])) {
      if (ev is Map && ev['id'] == id) {
        pendingEvent = Map<String, dynamic>.from(ev);
        notifyListeners();
        return;
      }
    }
  }

  void forceExpeditionCard([String id = 'alley']) {
    for (final ev in (defsEvents['expedition'] as List? ?? [])) {
      if (ev is Map && ev['id'] == id) {
        expedition['active'] = true;
        expedition['card'] = Map<String, dynamic>.from(ev);
        expedition['title'] ??= 'Market';
        notifyListeners();
        return;
      }
    }
  }

  void advancePhase() {
    _simulatePhase(false);
    saveGame();
    notifyListeners();
  }

  void _simulatePhase(bool offline) {
    if (ended) return;
    _tickNeeds();
    _tickPowerAndRooms();
    _tickMoraleHealth();
    _tickExpedition(offline);
    if (!offline) _maybeEvent();
    _checkEndings();
    phase += 1;
    if (phase >= 4) {
      phase = 0;
      day += 1;
      _dailyRoll();
    }
  }

  void _tickNeeds() {
    for (final s in livingSurvivors()) {
      if (resources['food']! > 0) {
        resources['food'] = resources['food']! - 1;
        s.hunger = min(100, s.hunger + 10);
      } else {
        s.hunger = max(0, s.hunger - 14);
      }
      if (resources['water']! > 0) {
        resources['water'] = resources['water']! - 1;
        s.thirst = min(100, s.thirst + 12);
      } else {
        s.thirst = max(0, s.thirst - 16);
      }
      if (s.hunger < 20) {
        s.health = max(0, s.health - 8);
        s.morale = max(0, s.morale - 6);
      }
      if (s.thirst < 20) {
        s.health = max(0, s.health - 10);
      }
      if (phase == 3) {
        final r = roomById(s.room);
        if (r?.type == 'living') {
          s.morale = min(100, s.morale + 7);
        } else {
          s.morale = max(0, s.morale - 5);
        }
      }
      if (s.trait == 'iyimser') {
        s.morale = min(100, s.morale + 2);
      }
    }
  }

  void _tickPowerAndRooms() {
    var producedPower = 0;
    var drain = 0;
    for (final r in rooms) {
      if (!r.built || r.type == 'empty' || r.type.isEmpty) continue;
      final def = defsRooms[r.type];
      final workers = workersOf(r);
      final lvl = r.level;
      if (r.type == 'generator') {
        var p = 0;
        for (final s in workers) {
          p += 5 + (s.skills['tech'] ?? 0);
          if (s.trait == 'caliskan') p += 1;
        }
        producedPower += p * lvl;
      } else if (def is Map) {
        drain += asInt(def['power']) + (lvl - 1);
      }
    }
    resources['power'] = producedPower.clamp(0, caps['power']!);
    final blackout = producedPower < drain && drain > 0;
    if (blackout) {
      _log('Karartma: jeneratör yetişemedi.');
      for (final s in livingSurvivors()) {
        s.morale = max(0, s.morale - 4);
      }
      return;
    }
    resources['power'] = (producedPower - drain).clamp(0, caps['power']!);
    for (final r in rooms) {
      if (r.type == 'empty' || r.type.isEmpty) continue;
      final workers = workersOf(r);
      final lvl = r.level;
      switch (r.type) {
        case 'hydroponics':
          var food = 0;
          for (final s in workers) {
            food += 2 + (s.skills['cook'] ?? 0);
            if (s.trait == 'caliskan') food += 1;
          }
          _addRes('food', food * lvl);
        case 'water':
          var wat = 0;
          for (final s in workers) {
            wat += 2 + ((s.skills['tech'] ?? 0) ~/ 2);
          }
          _addRes('water', wat * lvl);
        case 'workshop':
          var scrap = 0;
          var ammo = 0;
          for (final s in workers) {
            scrap += 1 + (s.trait == 'usta' ? 1 : 0);
            if ((s.skills['tech'] ?? 0) >= 2) ammo += 1;
          }
          _addRes('scrap', scrap * lvl);
          _addRes('ammo', ammo);
        case 'infirmary':
          for (final s in workers) {
            var heal = 10 + (s.skills['medical'] ?? 0) * 3;
            if (s.trait == 'sefkatli') heal += 6;
            if (resources['medicine']! > 0) {
              resources['medicine'] = resources['medicine']! - 1;
              heal += 8;
            }
            _healLowest(heal);
          }
        case 'radio':
          var add = 0.0;
          for (final s in workers) {
            add += 3.5 + (s.skills['tech'] ?? 0);
          }
          radioProgress = min(100, radioProgress + add * lvl);
        case 'living':
          for (final s in workers) {
            s.morale = min(100, s.morale + 2);
          }
      }
    }
  }

  void _tickMoraleHealth() {
    final huysuz = livingSurvivors().any((s) => s.trait == 'huysuz');
    for (final s in livingSurvivors()) {
      if (huysuz && s.trait != 'huysuz') {
        s.morale = max(0, s.morale - 1.5);
      }
      if (s.health <= 0) {
        s.alive = false;
        s.away = false;
        s.room = '';
        _log('${s.name} hayatını kaybetti.');
        Sfx.play('fail');
      }
    }
  }

  void _tickExpedition(bool offline) {
    if (!hasActiveExpedition) return;
    expedition['left'] = asInt(expedition['left'], 1) - 1;
    final cards = defsEvents['expedition'];
    if (!offline && rng.nextDouble() < 0.42 && cards is List && cards.isNotEmpty) {
      expedition['card'] = Map<String, dynamic>.from(cards[rng.nextInt(cards.length)] as Map);
      return;
    }
    if (asInt(expedition['left']) <= 0) {
      _resolveExpeditionReturn();
    }
  }

  void _resolveExpeditionReturn() {
    final destLoot = expedition['loot'] is Map
        ? Map<String, dynamic>.from(expedition['loot'] as Map)
        : <String, dynamic>{};
    final people = [
      for (final p in (expedition['people'] as List? ?? [])) '$p',
    ];
    var danger = asInt(expedition['danger'], 30) - asInt(expedition['ammo']) * 4;
    final lootTxt = <String>[];
    for (final sid in people) {
      final s = survivorById(sid);
      if (s == null) continue;
      s.away = false;
      var skill = (s.skills['scavenge'] ?? 0) + (s.skills['combat'] ?? 0);
      if (s.trait == 'cesur') danger -= 8;
      if (s.trait == 'gezgin') skill += 2;
      final hit = rng.nextInt(101);
      final chance = (danger - skill * 6).clamp(6, 75);
      if (hit < chance) {
        final dmg = 12 + rng.nextInt(29);
        s.health = max(0, s.health - dmg);
        s.morale = max(0, s.morale - 10);
        _log('${s.name} seferde yaralandı (−$dmg sağlık).');
        if (s.health <= 0) {
          s.alive = false;
          _log('${s.name} geri dönemedi.');
        }
      }
    }
    destLoot.forEach((resName, pair) {
      if (pair is List && pair.length >= 2) {
        final lo = asInt(pair[0]);
        final hi = asInt(pair[1]);
        final amt = lo + rng.nextInt(max(1, hi - lo + 1));
        if (amt > 0) {
          _addRes(resName, amt);
          lootTxt.add('${resLabel(resName)} +$amt');
        }
      }
    });
    _log(
      'Sefer döndü: ${expedition['title'] ?? ''}. ${lootTxt.isEmpty ? 'Boş eller.' : lootTxt.join(', ')}',
    );
    expedition = {};
    Sfx.play('door');
  }

  void _maybeEvent() {
    if (pendingEvent != null) return;
    if (day == 1 && phase < 1) return;
    if (!tutorialDone && tutorialStep < 4) return;
    var chance = 0.22;
    if (phase == 3) chance += 0.08;
    if (rng.nextDouble() > chance) return;
    final list = defsEvents['shelter'];
    if (list is! List || list.isEmpty) return;
    pendingEvent = Map<String, dynamic>.from(list[rng.nextInt(list.length)] as Map);
    Sfx.play('question');
  }

  void _dailyRoll() {
    final avg = _avgMorale();
    if (avg < 18) {
      lowMoraleDays += 1;
    } else {
      lowMoraleDays = 0;
    }
    if (rng.nextDouble() < 0.12) _maybeJoin();
    _log('$day. gün başladı. Moral ort. ${avg.round()}.');
  }

  void _maybeJoin() {
    if (livingSurvivors().length >= 8) return;
    if (rng.nextDouble() < 0.45) {
      final used = [for (final s in survivors) s.name];
      final s = _makeSurvivor(rng.nextInt(6), '', {}, used);
      s.health = (45 + rng.nextInt(36)).toDouble();
      s.morale = (35 + rng.nextInt(36)).toDouble();
      survivors.add(s);
      _log('Kapıya biri vurdu: ${s.name} sığınağa katıldı.');
    }
  }

  void _checkEndings() {
    final alive = survivors.where((s) => s.alive).length;
    if (alive == 0) {
      _end(false, 'Sığınakta kimse kalmadı.');
      return;
    }
    if (lowMoraleDays >= 3) {
      _end(false, 'Umut bitti. Kapılar içeriden açılmadı.');
      return;
    }
    if (radioProgress >= 100) {
      _end(true, 'Telsiz cevap verdi. Kuzey barajından bir konvoy yola çıktı.');
      return;
    }
    if (day > 21) {
      _end(true, 'Yirmi bir gün. Dışarı hâlâ zehir, ama siz durdunuz.');
    }
  }

  void _end(bool win, String reason) {
    if (ended) return;
    ended = true;
    won = win;
    endReason = reason;
    speed = 0;
    score = day * 12 + radioProgress.round() + livingSurvivors().length * 40;
    for (final v in resources.values) {
      score += v;
    }
    _log(reason);
    saveGame();
    Sfx.play(win ? 'jingle_win' : 'jingle_lose');
  }

  void _applyShelterChoice(Map<String, dynamic> ev, String choiceId) {
    final ch = _choice(ev, choiceId);
    if (!_canAfford(ch)) {
      Sfx.play('error');
      return;
    }
    _pay(ch);
    switch ('${ev['id']}:$choiceId') {
      case 'raiders:fight':
        _hurtRandom(18);
        _log('Yağmacılar püskürtüldü. Biri kanadı.');
      case 'raiders:bribe':
        _log('Kapıya bir sandık bırakıldı. Ayak sesleri uzaklaştı.');
      case 'raiders:hide':
        if (rng.nextDouble() < 0.45) {
          _addRes('food', -6);
          _hurtRandom(10);
          _log('Kapıyı zorladılar. Bir şeyler eksik.');
        } else {
          _log('Nefesler tutuldu. Geçtiler.');
        }
      case 'stranger:accept':
        _maybeJoin();
        _log('Yabancı içeri alındı.');
      case 'stranger:refuse':
        for (final s in livingSurvivors()) {
          s.morale = max(0, s.morale - 4);
        }
        _log('Kapı kapanırken dışarıda bir küfür.');
      case 'stranger:share':
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 3);
        }
      case 'blackout:fix':
        _addRes('power', 8);
        _log('Jeneratör yeniden öksürerek çalıştı.');
      case 'blackout:ration':
        _log('Sadece revir ışığı yandı.');
      case 'blackout:ignore':
        _hurtRandom(6);
        _log('Karanlık uzadı.');
      case 'sickness:meds':
        _healAll(18);
      case 'sickness:quarantine':
        _hurtRandom(8);
      case 'sickness:work':
        _hurtRandom(16);
        _hurtRandom(10);
      case 'radio_ping:focus':
        radioProgress = min(100, radioProgress + 8);
      case 'radio_ping:hope':
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 6);
        }
      case 'leak:patch':
        _addRes('water', 4);
      case 'leak:bucket':
        _addRes('water', 2);
      case 'leak:cut':
        _addRes('water', -3);
      case 'dream:sing':
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 8);
        }
      case 'dream:record':
        radioProgress = min(100, radioProgress + 4);
      case 'fight:mediate':
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 2);
        }
      case 'fight:punish':
        _hurtRandom(4);
        for (final s in livingSurvivors()) {
          s.morale = max(0, s.morale - 3);
        }
      case 'cavein:brace':
        _log('Kiriş yerine oturdu. Toz durdu.');
      case 'cavein:move':
        _hurtRandom(6);
      case 'cavein:pray':
        if (rng.nextDouble() < 0.4) {
          _hurtRandom(22);
          _log('Tavan bir köşeden çöktü.');
        }
      case 'garden:cheer':
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 5);
        }
        _addRes('food', 2);
      case 'ammo_cache:take':
        _addRes('ammo', 4 + rng.nextInt(6));
      case 'ammo_cache:share':
        _addRes('ammo', 5);
        for (final s in livingSurvivors()) {
          s.morale = min(100, s.morale + 3);
        }
      case 'night_noise:listen':
        radioProgress = min(100, radioProgress + 3);
      case 'night_noise:patrol':
        if (resources['ammo']! >= 1) {
          resources['ammo'] = resources['ammo']! - 1;
        }
    }
    _log('Karar: ${ch['label'] ?? choiceId}');
  }

  void _applyExpChoice(Map<String, dynamic> ev, String choiceId) {
    final ch = _choice(ev, choiceId);
    if (!_canAfford(ch)) {
      Sfx.play('error');
      return;
    }
    _pay(ch);
    switch (choiceId) {
      case 'grab':
      case 'search':
        _addRes('food', 1 + rng.nextInt(4));
        _addRes('scrap', rng.nextInt(4));
      case 'ambush':
        _addRes('ammo', 1 + rng.nextInt(3));
        _hurtAway(10);
      case 'descend':
      case 'sample':
        _addRes('water', 2 + rng.nextInt(5));
      case 'trade':
        radioProgress = min(100, radioProgress + 10);
      case 'rob':
        if (rng.nextDouble() < 0.5) {
          _addRes('medicine', 2);
        } else {
          _hurtAway(20);
        }
    }
    _log('Sefer kararı: ${ch['label'] ?? choiceId}');
  }

  Map<String, dynamic> _choice(Map<String, dynamic> ev, String id) {
    for (final c in (ev['choices'] as List? ?? [])) {
      if (c is Map && c['id'] == id) return Map<String, dynamic>.from(c);
    }
    return {};
  }

  bool _canAfford(Map<String, dynamic> ch) {
    for (final k in ['need_ammo', 'need_food', 'need_water', 'need_scrap', 'need_medicine']) {
      final res = k.replaceFirst('need_', '');
      if (asInt(ch[k]) > (resources[res] ?? 0)) return false;
    }
    return true;
  }

  void _pay(Map<String, dynamic> ch) {
    for (final k in ['need_ammo', 'need_food', 'need_water', 'need_scrap', 'need_medicine']) {
      final res = k.replaceFirst('need_', '');
      final n = asInt(ch[k]);
      if (n > 0) resources[res] = resources[res]! - n;
    }
  }

  void _addRes(String name, int amt) {
    if (!resources.containsKey(name)) return;
    resources[name] = (resources[name]! + amt).clamp(0, caps[name] ?? 99);
  }

  void _healLowest(int amount) {
    Survivor? best;
    var hp = 999.0;
    for (final s in livingSurvivors()) {
      if (s.health < hp) {
        hp = s.health;
        best = s;
      }
    }
    if (best != null) best.health = min(100, best.health + amount);
  }

  void _healAll(int amount) {
    for (final s in livingSurvivors()) {
      s.health = min(100, s.health + amount);
    }
  }

  void _hurtRandom(int amount) {
    final live = livingSurvivors();
    if (live.isEmpty) return;
    final s = live[rng.nextInt(live.length)];
    s.health = max(0, s.health - amount);
  }

  void _hurtAway(int amount) {
    for (final sid in (expedition['people'] as List? ?? [])) {
      final s = survivorById('$sid');
      if (s != null) s.health = max(0, s.health - amount);
    }
  }

  List<Survivor> workersOf(Room room) => [
        for (final s in survivors)
          if (s.alive && !s.away && s.room == room.id) s,
      ];

  void _assign(String sid, String roomId) {
    final s = survivorById(sid);
    final r = roomById(roomId);
    if (s == null || r == null) return;
    if (r.type == 'empty' || r.type.isEmpty) return;
    final def = defsRooms[r.type];
    final cap = asInt(def is Map ? def['workers'] : 2, 2) + r.level - 1;
    if (workersOf(r).length >= cap && s.room != roomId) {
      Sfx.play('error');
      return;
    }
    s.room = roomId;
    selectedSurvivor = '';
    Sfx.play('switch');
  }

  void _addRoom(String type, int floor, int slot) {
    rooms.add(Room(id: 'r$roomSeq', type: type, floor: floor, slot: slot, level: 1, built: true));
    roomSeq += 1;
  }

  void _addEmpty(int floor, int slot) {
    rooms.add(Room(id: 'r$roomSeq', type: 'empty', floor: floor, slot: slot, level: 0, built: false));
    roomSeq += 1;
  }

  Survivor _makeSurvivor(
    int portrait,
    String traitId,
    Map<String, int> skills,
    List<String> usedNames,
  ) {
    final names = (defsNames['first'] as List?)?.map((e) => '$e').toList() ?? ['Ada', 'Ege'];
    var n = 'Kişi $survivorSeq';
    for (var i = 0; i < 12; i++) {
      final cand = names[rng.nextInt(names.length)];
      if (!usedNames.contains(cand)) {
        n = cand;
        break;
      }
    }
    usedNames.add(n);
    var trait = traitId;
    if (trait.isEmpty) {
      final traits = defsNames['traits'] as List? ?? [];
      if (traits.isNotEmpty) {
        trait = '${(traits[rng.nextInt(traits.length)] as Map)['id'] ?? 'caliskan'}';
      }
    }
    var sk = skills;
    if (sk.isEmpty) {
      sk = {
        'tech': rng.nextInt(4),
        'combat': rng.nextInt(4),
        'scavenge': rng.nextInt(4),
        'medical': rng.nextInt(4),
        'cook': rng.nextInt(4),
      };
    }
    final s = Survivor(
      id: 's$survivorSeq',
      name: n,
      portrait: portrait % 6,
      trait: trait,
      skills: sk,
    );
    survivorSeq += 1;
    return s;
  }

  void _recomputeCaps() {
    var bonus = 0;
    for (final r in rooms) {
      if (r.type == 'storage') bonus += 18 * r.level;
    }
    caps = {
      'food': 60 + bonus,
      'water': 60 + bonus,
      'power': 40 + bonus ~/ 2,
      'medicine': 24 + bonus ~/ 3,
      'scrap': 80 + bonus,
      'ammo': 24 + bonus ~/ 3,
    };
  }

  double _avgMorale() {
    final live = livingSurvivors();
    if (live.isEmpty) return 0;
    return live.fold<double>(0, (a, s) => a + s.morale) / live.length;
  }

  void _log(String msg) {
    logLines.add('G$day ${phaseNames[phase]} — $msg');
    if (logLines.length > 80) {
      logLines = logLines.sublist(logLines.length - 80);
    }
  }

  String resLabel(String id) {
    switch (id) {
      case 'food':
        return 'Yiyecek';
      case 'water':
        return 'Su';
      case 'power':
        return 'Elektrik';
      case 'medicine':
        return 'İlaç';
      case 'scrap':
        return 'Hurda';
      case 'ammo':
        return 'Cephane';
      default:
        return id;
    }
  }

  String traitTitle(String id) {
    for (final t in (defsNames['traits'] as List? ?? [])) {
      if (t is Map && t['id'] == id) return '${t['title'] ?? id}';
    }
    return id;
  }

  String roomTitle(String type) {
    if (type == 'empty') return 'Boş Oyuk';
    final def = defsRooms[type];
    if (def is Map) return '${def['title'] ?? type}';
    return type;
  }

  List<String> resourceSummary() => ['food', 'water', 'power', 'medicine', 'scrap', 'ammo'];

  Map<String, int> _intMap(dynamic raw, Map<String, int> fallback) {
    if (raw is! Map) return Map<String, int>.from(fallback);
    final out = <String, int>{};
    raw.forEach((k, v) => out['$k'] = asInt(v));
    return out;
  }
}
