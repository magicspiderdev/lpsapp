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
