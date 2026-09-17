/// Endereços do CISOC.
///
/// A raiz muda-se no build, sem tocar no código:
/// `flutter run --dart-define=LPS_API_RAIZ=http://10.0.2.2:8080` (emulador Android
/// com o CISOC local). Por omissão, produção.
abstract final class Config {
  static const apiRaiz = String.fromEnvironment('LPS_API_RAIZ', defaultValue: 'https://mylps.leoesdeportosalvo.pt/lps');

  /// Zona privada: API do Sócio (guia `api-socio-flutter.md`).
  static const socioBase = '$apiRaiz/api/v1';

  /// Zona pública: sem autenticação, sem dados pessoais (ADR-10).
  static const publicoBase = '$apiRaiz/api/v2/publico';

  static String mediaUrl(String uid) => '$apiRaiz/media/$uid';
}

/// Modo de demonstração: `flutter run --dart-define=LPS_DEMO=1`.
///
/// A agenda, a bilheteira e a informação do clube já têm ecrã mas ainda não têm
/// API (pedido `2026-09-17-zona-publica-agenda-bilhetes-clube` no CISOC). Com
/// este modo ligado, esses ecrãs mostram dados de exemplo, para se ver o
/// desenho; sem ele, mostram "em preparação".
// Aceita `1` e `true`: `bool.fromEnvironment` sozinho só reconhece `true`.
const _demo = String.fromEnvironment('LPS_DEMO');
const modoDemonstracao = _demo == '1' || _demo == 'true';
