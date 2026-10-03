import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/bath_foam.dart';

void main() {
  test('Soap stays at contact and water removes only marks it intersects', () {
    final foam = BathFoam();
    foam.soap(const Offset(.25, .6), .4);
    foam.soap(const Offset(.75, .4), .4);
    expect(foam.patches.map((p) => p.position), [
      const Offset(.25, .6),
      const Offset(.75, .4),
    ]);
    foam.water(const Offset(.5, .1), 1);
    expect(foam.progress, 0);
    foam.water(const Offset(.25, .8), 1);
    expect(foam.progress, 0, reason: 'Water cannot clean above its source');
    foam.water(const Offset(.25, .1), .2);
    expect(foam.patches.first.strength, closeTo(.2, .001));
    expect(foam.patches.last.strength, .4);
    foam.water(const Offset(.25, .1), 1);
    expect(foam.finished, false);
    foam.water(const Offset(.75, .1), 1);
    expect(foam.finished, true);
    expect(foam.progress, closeTo(1, .001));
  });
}
