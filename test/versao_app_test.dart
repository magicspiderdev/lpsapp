import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/arranque/versao_app.dart';

void main() {
  test('compara versões por componentes numéricos, não como texto', () {
    expect(compararVersoes('1.10.0', '1.9.0'), greaterThan(0));
    expect(compararVersoes('2.0.0', '2.0.0'), 0);
    expect(compararVersoes('2.0', '2.0.1'), lessThan(0));
    expect(compararVersoes('2.0.0+7', '2.0.0'), 0);
    expect(compararVersoes('1.4.1', '2.0.0'), lessThan(0));
  });
}
