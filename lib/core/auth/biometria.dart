import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'sessao.dart';

/// Preferência "entrar com biometria", guardada neste aparelho.
///
/// A biometria não substitui a palavra-passe no servidor: só protege a sessão
/// que já está guardada. Sem sessão (logout, refresh expirado) volta a ser
/// preciso entrar com a palavra-passe.
class BiometriaStore {
  BiometriaStore(this._storage);

  static const _kActiva = 'lps.biometria_activa';

  final FlutterSecureStorage _storage;
  bool activa = false;

  Future<void> carregar() async {
    try {
      activa = await _storage.read(key: _kActiva) == '1';
    } catch (_) {
      activa = false;
    }
  }

  Future<void> definir(bool valor) async {
    activa = valor;
    await _storage.write(key: _kActiva, value: valor ? '1' : '0');
  }
}

/// Preenchido em `main()`, depois de ler o armazenamento seguro.
final biometriaStoreProvider = Provider<BiometriaStore>(
  (ref) => throw UnimplementedError('biometriaStoreProvider tem de ser sobreposto em main()'),
);

enum TipoBiometria {
  digital,
  facial;

  /// "Entrar com …"
  String get nome => switch (this) {
        TipoBiometria.facial when defaultTargetPlatform == TargetPlatform.iOS => 'Face ID',
        TipoBiometria.facial => 'reconhecimento facial',
        TipoBiometria.digital when defaultTargetPlatform == TargetPlatform.iOS => 'Touch ID',
        TipoBiometria.digital => 'impressão digital',
      };
}

final _auth = LocalAuthentication();

/// O tipo de biometria configurado no aparelho, ou `null` se não houver nenhuma.
final tipoBiometriaProvider = FutureProvider<TipoBiometria?>((ref) async {
  try {
    if (!await _auth.isDeviceSupported()) return null;
    final tipos = await _auth.getAvailableBiometrics();
    if (tipos.isEmpty) return null;
    // Só há rosto sem impressão digital em iPhones com Face ID e alguns Android.
    return tipos.contains(BiometricType.face) && !tipos.contains(BiometricType.fingerprint)
        ? TipoBiometria.facial
        : TipoBiometria.digital;
  } catch (_) {
    return null;
  }
});

/// Pede a biometria (com recurso ao PIN do aparelho). `true` se confirmou.
Future<bool> pedirBiometria(String motivo) async {
  try {
    return await _auth.authenticate(localizedReason: motivo, persistAcrossBackgrounding: true);
  } on LocalAuthException {
    return false; // cancelado, bloqueado, sem biometria: fica como está
  }
}

class EstadoBiometria {
  /// O utilizador escolheu entrar com biometria neste aparelho.
  final bool activa;

  /// A zona do sócio está à espera de desbloqueio.
  final bool bloqueada;

  /// Acabou de entrar com palavra-passe: oferecer a biometria uma vez.
  final bool oferecer;

  const EstadoBiometria({required this.activa, required this.bloqueada, this.oferecer = false});

  EstadoBiometria copyWith({bool? activa, bool? bloqueada, bool? oferecer}) => EstadoBiometria(
        activa: activa ?? this.activa,
        bloqueada: bloqueada ?? this.bloqueada,
        oferecer: oferecer ?? this.oferecer,
      );
}

final biometriaProvider = NotifierProvider<BiometriaController, EstadoBiometria>(BiometriaController.new);

class BiometriaController extends Notifier<EstadoBiometria> {
  /// Tempo fora da app a partir do qual a zona do sócio volta a bloquear.
  static const tempoAteBloquear = Duration(minutes: 2);

  DateTime? _saiuEm;

  @override
  EstadoBiometria build() {
    final store = ref.watch(biometriaStoreProvider);

    final ciclo = AppLifecycleListener(
      onHide: () => _saiuEm ??= DateTime.now(),
      onShow: _voltou,
    );
    ref.onDispose(ciclo.dispose);

    ref.listen(sessaoProvider, (antes, depois) {
      if (depois is SessaoAnonima) {
        // Sem sessão não há nada a proteger; a próxima pessoa escolhe de novo.
        if (store.activa) store.definir(false);
        state = const EstadoBiometria(activa: false, bloqueada: false);
      } else if (antes is SessaoAnonima && depois is SessaoSocio) {
        // Entrou agora com palavra-passe ou código: já está autenticado.
        state = EstadoBiometria(activa: store.activa, bloqueada: false, oferecer: !store.activa);
      }
    });

    // Ao abrir a app com sessão guardada, começa bloqueada.
    final temSessao = ref.read(sessaoProvider) is SessaoSocio;
    return EstadoBiometria(activa: store.activa, bloqueada: store.activa && temSessao);
  }

  void _voltou() {
    final saiu = _saiuEm;
    _saiuEm = null;
    if (saiu == null || !state.activa || state.bloqueada) return;
    if (ref.read(sessaoProvider) is! SessaoSocio) return;
    if (DateTime.now().difference(saiu) >= tempoAteBloquear) {
      state = state.copyWith(bloqueada: true);
    }
  }

  Future<bool> desbloquear() async {
    final ok = await pedirBiometria('Confirme que é você para abrir a área de sócio.');
    if (ok) state = state.copyWith(bloqueada: false);
    return ok;
  }

  /// Liga ou desliga. Ligar pede a biometria primeiro, para confirmar que funciona.
  Future<bool> definir(bool activa) async {
    if (activa && !await pedirBiometria('Confirme para passar a entrar com biometria.')) {
      return false;
    }
    await ref.read(biometriaStoreProvider).definir(activa);
    state = state.copyWith(activa: activa, oferecer: false);
    return true;
  }

  void dispensarOferta() => state = state.copyWith(oferecer: false);
}

