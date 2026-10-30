import 'package:flutter_test/flutter_test.dart';

import 'package:siginak/game_state.dart';

void main() {
  test('resource labels', () {
    final g = GameState();
    expect(g.resLabel('food'), 'Yiyecek');
    expect(g.resLabel('ammo'), 'Cephane');
    expect(g.roomTitle('empty'), 'Boş Oyuk');
  });
}
