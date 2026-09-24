import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_local.dart';

/// Se este aparelho já viu as boas-vindas (os slides da primeira vez).
///
/// Fica na cache pública, que não se apaga ao sair da sessão: as boas-vindas
/// são do aparelho, não da conta. Se não se conseguir ler, conta como vistas —
/// uma falha no disco não pode prender ninguém nos slides.
final boasVindasProvider = AsyncNotifierProvider<BoasVindasController, bool>(BoasVindasController.new);

class BoasVindasController extends AsyncNotifier<bool> {
  static const _chave = 'app.boas-vindas';

  @override
  Future<bool> build() async {
    try {
      return await ref.read(cacheProvider).ler(Ambito.publico, _chave) != null;
    } catch (_) {
      return true;
    }
  }

  /// Chegou ao fim ou saltou: não voltam a aparecer.
  Future<void> marcarVistas() async {
    state = const AsyncData(true);
    try {
      await ref.read(cacheProvider).guardar(Ambito.publico, _chave, {'vistas': true});
    } catch (_) {
      // Na pior das hipóteses aparecem outra vez no próximo arranque.
    }
  }
}
