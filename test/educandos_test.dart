import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/api/clientes.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/auth/token_store.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/rede/ligacao.dart';
import 'package:lpsapp/features/conta/educandos/educandos.dart';

/// Encarregados por conta (§2.3.5): um pai que não é sócio pede para
/// acompanhar o filho, e a secretaria confirma. O que estes testes protegem:
/// o pedido leva o que o servidor precisa para conferir, os pendentes não
/// passam por activos, e depois de mudar a lista a sessão é renovada.
class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

  int contar(String metodo, String caminho) => pedidos.where((o) => o.method == metodo && o.path == caminho).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) = respostas['${o.method} ${o.path}'] ?? (404, {'status': 'error', 'erro': 'nao_encontrado'});
    return ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Ligado extends LigacaoController {
  @override
  bool build() => true;
}

class _Quem extends SessaoController {
  _Quem(this.inicial);
  final Sessao inicial;

  @override
  Sessao build() => inicial;
}

/// Conta as renovações em vez de ir ao servidor.
class _Store extends TokenStore {
  _Store({this.falha = false}) : super(const FlutterSecureStorage(), Dio());
  final bool falha;
  int renovacoes = 0;

  @override
  Future<void> renovar() async {
    renovacoes++;
    if (falha) throw const ApiException(erro: 'sem_ligacao', message: 'Sem ligação');
  }
}

Map<String, dynamic> _e(int nr, String estado, {String nome = 'Carminho', String relacao = 'mae'}) => {
  'nr_socio': nr,
  'nome': nome,
  'estado': estado,
  'relacao': relacao,
  'pode_pagar': estado == 'active',
  'faixa_etaria': 'child',
  'pedido_em': '2026-09-24 18:00:00',
  'verificado_em': estado == 'active' ? '2026-09-25 10:00:00' : null,
};

({ProviderContainer c, _Servidor s, _Store store}) _montar({bool renovarFalha = false}) {
  final s = _Servidor();
  final store = _Store(falha: renovarFalha);
  final dio = Dio(BaseOptions(baseUrl: 'http://teste/api/v2'))..httpClientAdapter = s;
  final c = ProviderContainer(
    overrides: [
      dioContaProvider.overrideWithValue(dio),
      cacheProvider.overrideWithValue(CacheEmMemoria()),
      ligacaoProvider.overrideWith(_Ligado.new),
      tokenStoreProvider.overrideWithValue(store),
      sessaoProvider.overrideWith(() => _Quem(SessaoConta(const ContaSessao(nome: 'Ana')))),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, s: s, store: store);
}

void main() {
  group('a lista', () {
    test('activos e pendentes; o estado é lista aberta', () {
      final l = lerEducandos({
        'dependentes': [
          _e(1, 'pending'),
          _e(2, 'active'),
          _e(3, 'por_rever'),
          {'nome': 'sem número'},
        ],
      });
      expect(l.length, 3);
      expect(l[0].pendente, isTrue);
      expect(l[1].activo, isTrue);
      expect(l[2].pendente || l[2].activo, isFalse, reason: 'um estado novo não é tratado como nenhum dos dois');
      expect(l[1].verificadoEm, DateTime(2026, 9, 25, 10));
    });

    test('ordem: activos, depois pedidos, depois o que não se conhece', () {
      final l = ordenarEducandos(
        lerEducandos({
          'dependentes': [
            _e(1, 'estranho', nome: 'Ana'),
            _e(2, 'pending', nome: 'Bruno'),
            _e(3, 'active', nome: 'Zé'),
            _e(4, 'active', nome: 'Carla'),
          ],
        }),
      );
      expect(l.map((e) => e.nrSocio), [4, 3, 2, 1]);
    });

    test('relações: as conhecidas têm nome; o resto mostra-se como vem', () {
      expect(rotuloRelacao('mae'), 'Mãe');
      expect(rotuloRelacao('pai'), 'Pai');
      expect(rotuloRelacao('encarregado'), 'Encarregado de educação');
      expect(rotuloRelacao('tutor'), 'Tutor');
      expect(rotuloRelacao(null), '');
      expect(relacoesPedido, ['mae', 'pai', 'encarregado']);
    });

    test('a sessão está atrasada quando a secretaria aprovou e ela ainda não sabe', () {
      final lista = lerEducandos({
        'dependentes': [_e(5643, 'active'), _e(9, 'pending')],
      });
      const semNada = ContaSessao(nome: 'Ana');
      const emDia = ContaSessao(
        nome: 'Ana',
        dependentes: [DependenteConta(nrSocio: 5643, nome: 'CARMINHO')],
      );
      const aMais = ContaSessao(
        nome: 'Ana',
        dependentes: [
          DependenteConta(nrSocio: 5643, nome: 'CARMINHO'),
          DependenteConta(nrSocio: 77, nome: 'REMOVIDO'),
        ],
      );
      expect(sessaoDesactualizada(lista, semNada), isTrue);
      expect(sessaoDesactualizada(lista, emDia), isFalse, reason: 'um pendente não conta');
      expect(sessaoDesactualizada(lista, aMais), isTrue, reason: 'a secretaria retirou uma ligação');
      expect(sessaoDesactualizada(lista, null), isFalse);
    });

    test('carrega pela v2', () async {
      final m = _montar();
      m.s.respostas['GET /me/dependentes'] = (
        200,
        {
          'status': 'success',
          'data': {
            'dependentes': [_e(1, 'pending')],
          },
        },
      );
      m.c.listen(educandosProvider, (_, _) {});
      final d = await m.c.read(educandosProvider.future);
      expect(d.valor.single.nome, 'Carminho');
    });
  });

  group('pedir', () {
    test('envia número, data (AAAA-MM-DD) e relação; devolve a mensagem e renova a sessão', () async {
      final m = _montar();
      m.s.respostas['GET /me/dependentes'] = (
        200,
        {
          'status': 'success',
          'data': {'dependentes': <Object>[]},
        },
      );
      m.s.respostas['POST /me/dependentes'] = (
        201,
        {
          'status': 'success',
          'data': {'dependente': _e(5643, 'pending'), 'mensagem': 'Pedido registado. A secretaria confirma.'},
        },
      );
      m.c.listen(educandosProvider, (_, _) {});
      await m.c.read(educandosProvider.future);

      final r = await m.c
          .read(educandosAccoesProvider)
          .pedir(nrSocio: 5643, dataNascimento: DateTime(2016, 3, 7), relacao: 'mae');

      expect(m.s.pedidos.singleWhere((o) => o.method == 'POST').data, {
        'nr_socio': 5643,
        'data_nascimento': '2016-03-07',
        'relacao': 'mae',
      });
      expect(r.mensagem, 'Pedido registado. A secretaria confirma.');
      expect(r.educando?.pendente, isTrue);
      expect(m.store.renovacoes, 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(m.s.contar('GET', '/me/dependentes'), 2, reason: 'a lista recarrega');
    });

    test('sem rede para renovar, o pedido não falha por isso', () async {
      final m = _montar(renovarFalha: true);
      m.s.respostas['POST /me/dependentes'] = (
        201,
        {
          'status': 'success',
          'data': {'dependente': _e(5643, 'pending'), 'mensagem': 'ok'},
        },
      );
      final r = await m.c
          .read(educandosAccoesProvider)
          .pedir(nrSocio: 5643, dataNascimento: DateTime(2016), relacao: 'pai');
      expect(r.mensagem, 'ok');
      expect(m.store.renovacoes, 1);
    });

    for (final (status, erro) in [
      (422, 'dados_nao_conferem'),
      (422, 'dependente_maior'),
      (403, 'encarregado_menor'),
      (409, 'ja_ligado'),
      (429, 'demasiados_pedidos'),
    ]) {
      test('$status $erro sobe com a message, e não renova nada', () async {
        final m = _montar();
        m.s.respostas['POST /me/dependentes'] = (
          status,
          {'status': 'error', 'erro': erro, 'message': 'Texto do servidor para $erro.'},
        );
        await expectLater(
          m.c.read(educandosAccoesProvider).pedir(nrSocio: 1, dataNascimento: DateTime(2015), relacao: 'mae'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.erro, 'erro', erro)
                .having((e) => e.message, 'message', 'Texto do servidor para $erro.'),
          ),
        );
        expect(m.store.renovacoes, 0);
      });
    }
  });

  group('remover', () {
    test('DELETE com corpo JSON, recarrega a lista e renova a sessão', () async {
      final m = _montar();
      m.s.respostas['DELETE /me/dependentes/5643'] = (
        200,
        {
          'status': 'success',
          'data': {'removido': true},
        },
      );
      await m.c.read(educandosAccoesProvider).remover(5643);

      final del = m.s.pedidos.single;
      expect(del.method, 'DELETE');
      expect(del.data, isA<Map<dynamic, dynamic>>());
      expect(m.store.renovacoes, 1);
    });
  });
}
