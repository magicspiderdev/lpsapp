import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/rede/ligacao.dart';
import '../../socio/conta/contas.dart' show dependentesProvider;
import '../educandos/educandos.dart' show educandosProvider;

/// Um consentimento (guia §2.11): dado ou retirado, registado com a versão da
/// política. **Quem pode alterar o quê decide o servidor** — a app lê
/// [podeAlterar] e [porqueNao], nunca calcula idades.
class Consentimento {
  /// `app_account`, `image_use`, `notifications_operational`, `marketing` —
  /// lista aberta. Um tipo que a app não conhece mostra-se na mesma, com o
  /// [rotulo] que vem.
  final String tipo;
  final String rotulo;
  final bool ativo;

  /// A versão do texto com que foi dado, e a que está em vigor.
  final String? versao, versaoActual;

  /// Dado numa versão anterior do texto: pedir outra vez.
  final bool precisaRenovar;
  final DateTime? concedidoEm;

  /// `proprio`, `encarregado`, `secretaria` ou `null` — lista aberta.
  final String? dadoPor;
  final bool podeAlterar;

  /// Quando não pode: o código do erro que o servidor daria (ver [explicacaoPorqueNao]).
  final String? porqueNao;

  const Consentimento({
    required this.tipo,
    required this.rotulo,
    required this.ativo,
    this.versao,
    this.versaoActual,
    this.precisaRenovar = false,
    this.concedidoEm,
    this.dadoPor,
    this.podeAlterar = false,
    this.porqueNao,
  });

  factory Consentimento.fromJson(Map<String, dynamic> j) {
    final tipo = j['tipo'] as String;
    final rotulo = j['rotulo'];
    return Consentimento(
      tipo: tipo,
      rotulo: rotulo is String && rotulo.trim().isNotEmpty ? rotulo : tipo,
      ativo: j['ativo'] == true,
      versao: j['versao'] as String?,
      versaoActual: j['versao_actual'] as String?,
      precisaRenovar: j['precisa_renovar'] == true,
      concedidoEm: j['concedido_em'] is String ? DateTime.tryParse(j['concedido_em'] as String) : null,
      dadoPor: j['dado_por'] as String?,
      // Na dúvida, não: é o servidor que abre o interruptor.
      podeAlterar: j['pode_alterar'] == true,
      porqueNao: j['porque_nao'] as String?,
    );
  }
}

/// A lista que **todas** as respostas trazem, já actualizada.
List<Consentimento> lerConsentimentos(Map<String, dynamic> data) => [
  for (final c in (data['consentimentos'] as List?) ?? const [])
    if (c is Map && c['tipo'] is String) Consentimento.fromJson(c.cast<String, dynamic>()),
];

/// A frase para um interruptor desactivado, a partir de `porque_nao`. São os
/// mesmos códigos dos erros do §2.11; um código desconhecido tem frase genérica.
String explicacaoPorqueNao(String? codigo) => switch (codigo) {
  'consentimento_indisponivel' => 'Não está disponível para menores de 18 anos.',
  'consentimento_do_encarregado' => 'Abaixo dos 13 anos, só o encarregado de educação o pode dar ou retirar.',
  'sem_permissao' => 'Este sócio já é maior de idade: é ele quem decide.',
  'socio_nao_associado' => 'Já não acompanha este sócio na app.',
  _ => 'Não pode ser alterado aqui. Se precisar, fale com a secretaria.',
};

/// Quem o deu, dito com discrição. `null` quando não há nada a dizer.
///
/// Com [deDependente], "o próprio" é o educando e não quem está a ver.
String? textoDadoPor(String? dadoPor, {bool deDependente = false}) => switch (dadoPor) {
  'proprio' => deDependente ? 'Dado pelo próprio' : 'Dado por si',
  'encarregado' => 'Dado pelo encarregado de educação',
  'secretaria' => 'Registado na secretaria',
  _ => null,
};

/// Erros de escrita que dizem que o estado mudou do lado do servidor: mostra-se
/// a `message` e recarrega-se a lista.
bool recarregaDepoisDe(String erro) => const {
  'consentimento_indisponivel',
  'consentimento_do_encarregado',
  'sem_permissao',
  'socio_nao_associado',
  'consentimento_invalido',
}.contains(erro);

/// O caminho na v2: os da conta, ou os de um dependente com ligação activa.
String caminhoConsentimentos(int? nrSocio) =>
    nrSocio == null ? '/me/consentimentos' : '/me/dependentes/$nrSocio/consentimentos';

/// Os consentimentos da conta (`null`) ou de um dependente (o `nr_socio`).
///
/// Mostra primeiro o que está guardado; cada escrita substitui o estado pela
/// lista que o servidor devolve.
final consentimentosProvider = StreamNotifierProvider.autoDispose
    .family<ConsentimentosController, Dados<List<Consentimento>>, int?>(ConsentimentosController.new);

class ConsentimentosController extends AutoDisposeFamilyStreamNotifier<Dados<List<Consentimento>>, int?> {
  String get _chave => 'consentimentos.${arg ?? 'proprio'}';

  @override
  Stream<Dados<List<Consentimento>>> build(int? nrSocio) {
    if (ref.watch(sessaoProvider.select((s) => s is SessaoAnonima))) {
      return Stream.error(const ApiException(erro: 'sem_sessao', message: 'Entre na sua conta para continuar.'));
    }
    ref.watch(ligacaoProvider);
    // Lido já: o pedido corre depois de um await.
    final dio = ref.read(dioContaProvider);
    return comCache(
      cache: ref.read(cacheProvider),
      ambito: Ambito.sessao,
      chave: _chave,
      pedido: () => dadosDe(dio.get(caminhoConsentimentos(nrSocio))),
      ler: lerConsentimentos,
    );
  }

  /// Dá ou retira um consentimento. [politicaVersao] vai quando a pessoa
  /// aceitou um texto concreto que a app mostrou; sem ela, fica a actual.
  ///
  /// Lança [ApiException] com a `message` pronta a mostrar. Nos erros que dizem
  /// que o estado mudou, recarrega antes de lançar.
  Future<void> alterar(String tipo, {required bool ativo, String? politicaVersao}) async {
    final dio = ref.read(dioContaProvider);
    final cache = ref.read(cacheProvider);
    try {
      final d = await dadosDe(
        dio.put(
          '${caminhoConsentimentos(arg)}/${Uri.encodeComponent(tipo)}',
          data: {'ativo': ativo, 'politica_versao': ?politicaVersao},
        ),
      );
      await cache.guardar(Ambito.sessao, _chave, d);
      state = AsyncData(Dados(lerConsentimentos(d), DateTime.now()));
    } on ApiException catch (e) {
      if (recarregaDepoisDe(e.erro)) {
        if (arg != null && e.erro == 'socio_nao_associado') {
          // A ligação acabou (secretaria, ou fez 18): as listas também mudaram.
          // Pelo container: só recarrega o que estiver aberto (ver `EducandosAccoes`).
          ref.container
            ..invalidate(educandosProvider)
            ..invalidate(dependentesProvider);
        }
        ref.invalidateSelf();
      }
      rethrow;
    }
  }

  void recarregar() => ref.invalidateSelf();
}
