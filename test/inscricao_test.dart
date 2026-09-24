/// Inscrição de sócio pela conta v2 (§4.21): o contrato lido tal como vem, o
/// passo que conduz o ecrã, e o que se manda — nunca valores, nunca a idade.
library;

import 'dart:convert';
import 'dart:typed_data';

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
import 'package:lpsapp/features/inscricao/inscricao.dart';

/// Uma inscrição como o CISOC a devolve, no passo pedido.
Map<String, dynamic> inscricaoJson({
  String estado = 'submetida',
  String proximo = 'aguardar',
  String para = 'propria',
  int? nrSocio,
  List<String> porAssinar = const ['ficha_socio', 'termo_responsabilidade'],
  bool firme = false,
  String? motivo,
}) => {
  'id': '01MINSC',
  'estado': estado,
  'estado_label': switch (estado) {
    'submetida' => 'Por decidir',
    'admitida' => 'Admitido — por assinar',
    'assinada' => 'Por pagar',
    'concluida' => 'Concluída',
    'recusada' => 'Recusada',
    _ => 'Noutro estado',
  },
  'para': para,
  'nome': 'Maria Silva Santos',
  'data_nascimento': '1990-05-12',
  'menor': false,
  'nr_socio': nrSocio,
  'admitida_em': nrSocio == null ? null : '2026-09-23T10:04:00+01:00',
  'documentos': [
    for (final (tipo, nome) in [
      ('ficha_socio', 'Ficha de Sócio'),
      ('termo_responsabilidade', 'Termo de Responsabilidade'),
    ])
      {
        'tipo': tipo,
        'nome': nome,
        'assinado': !porAssinar.contains(tipo),
        'assinado_em': porAssinar.contains(tipo) ? null : '2026-09-23 11:00:00',
        'assinante': porAssinar.contains(tipo) ? null : 'Maria Silva Santos',
      },
  ],
  'por_assinar': porAssinar,
  'quotas': {
    'meses': 3,
    'valor': 6,
    'valor_mes': 2,
    'firme': firme,
    'minimo_meses': 3,
    'maximo_meses': 12,
    'pago_em': null,
  },
  'proximo_passo': proximo,
  'motivo': motivo,
  'criado_em': '2026-09-22 18:00:00',
};

/// Responde como o CISOC e guarda o que lhe pedem.
class _Servidor implements HttpClientAdapter {
  final pedidos = <RequestOptions>[];
  final respostas = <String, (int, Object)>{};

  RequestOptions ultimo(String metodo) => pedidos.lastWhere((p) => p.method == metodo);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? _) async {
    pedidos.add(o);
    final (status, corpo) =
        respostas['${o.method} ${o.path}'] ??
        (404, {'status': 'error', 'erro': 'nao_encontrado', 'message': 'Inscrição não encontrada.'});
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

Map<String, dynamic> _ok(Object dados) => {'status': 'success', 'data': dados};

class _ComConta extends SessaoController {
  @override
  Sessao build() => const SessaoConta(ContaSessao(nome: 'Maria', email: 'maria@exemplo.pt'));
}

class _Online extends LigacaoController {
  @override
  bool build() => true;
}

/// O refresh corre sem ninguém esperar por ele: dá-lhe tempo de acabar.
Future<void> _assentar() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  group('contrato', () {
    test('uma inscrição submetida: à espera do clube, valor ainda estimado', () {
      final i = InscricaoSocio.fromJson(inscricaoJson());
      expect(i.id, '01MINSC');
      expect(i.passo, PassoInscricao.aguardar);
      expect(i.nrSocio, isNull);
      expect(i.quotas.firme, isFalse);
      expect(i.quotas.valorMes, 2);
      expect(i.quotas.minimoMeses, 3);
      expect(i.quotas.maximoMeses, 12);
      expect(i.documentos, hasLength(2));
      expect(i.podeDesistir, isTrue);
    });

    test('admitida: número reservado, valor firme e o primeiro documento de por_assinar', () {
      final i = InscricaoSocio.fromJson(
        inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412, firme: true),
      );
      expect(i.passo, PassoInscricao.assinar);
      expect(i.nrSocio, 7412);
      expect(i.admitidaEm, isNotNull);
      expect(i.quotas.firme, isTrue);
      expect(i.proximoDocumento?.tipo, 'ficha_socio');
      expect(i.proximoDocumento?.nome, 'Ficha de Sócio');
    });

    test('um documento de cada vez: assinada a ficha, segue-se o termo, e já não se desiste', () {
      final i = InscricaoSocio.fromJson(
        inscricaoJson(estado: 'admitida', proximo: 'assinar', nrSocio: 7412, porAssinar: ['termo_responsabilidade']),
      );
      expect(i.proximoDocumento?.tipo, 'termo_responsabilidade');
      expect(i.assinados.single.tipo, 'ficha_socio');
      expect(i.podeDesistir, isFalse, reason: 'depois de assinar há um compromisso escrito');
    });

    test('um tipo em por_assinar que não vem nos documentos continua a poder assinar-se', () {
      final j = inscricaoJson(estado: 'admitida', proximo: 'assinar', porAssinar: ['autorizacao_imagem']);
      final i = InscricaoSocio.fromJson(j);
      expect(i.proximoDocumento?.tipo, 'autorizacao_imagem');
      expect(i.proximoDocumento?.nome, 'Documento');
    });

    test('recusada traz o motivo escrito pela secretaria', () {
      final i = InscricaoSocio.fromJson(
        inscricaoJson(estado: 'recusada', proximo: 'nada', motivo: 'Já existe uma ficha com este NIF.'),
      );
      expect(i.recusada, isTrue);
      expect(i.passo, PassoInscricao.nada);
      expect(i.motivo, 'Já existe uma ficha com este NIF.');
    });

    test('um motivo vazio é o mesmo que nenhum', () {
      expect(InscricaoSocio.fromJson(inscricaoJson(motivo: '  ')).motivo, isNull);
    });

    test('um máximo abaixo do mínimo não deixa o contador sem escolha', () {
      final q = QuotasInscricao.fromJson({'minimo_meses': 6, 'maximo_meses': 3, 'valor': 12});
      expect(q.maximoMeses, 6);
      expect(q.meses, 6);
    });

    test('uma inscrição mínima (só id e estado) não rebenta', () {
      final i = InscricaoSocio.fromJson({'id': 'X', 'estado': 'submetida'});
      expect(i.passo, PassoInscricao.desconhecido);
      expect(i.documentos, isEmpty);
      expect(i.proximoDocumento, isNull);
      expect(i.quotas.minimoMeses, 3);
    });
  });

  group('o passo decide o ecrã, e as listas são abertas', () {
    test('os quatro passos conhecidos', () {
      expect(passoDe('aguardar'), PassoInscricao.aguardar);
      expect(passoDe('assinar'), PassoInscricao.assinar);
      expect(passoDe('pagar'), PassoInscricao.pagar);
      expect(passoDe('nada'), PassoInscricao.nada);
    });

    test('um passo desconhecido ou ausente não é nenhum dos conhecidos', () {
      expect(passoDe('verificar_documento'), PassoInscricao.desconhecido);
      expect(passoDe(null), PassoInscricao.desconhecido);
      expect(passoDe(3), PassoInscricao.desconhecido);
    });

    test('um estado desconhecido lê-se, fica com o rótulo do servidor e segue o proximo_passo', () {
      final i = InscricaoSocio.fromJson(inscricaoJson(estado: 'em_revisao', proximo: 'aguardar'));
      expect(i.estado, 'em_revisao');
      expect(i.estadoLabel, 'Noutro estado');
      expect(i.passo, PassoInscricao.aguardar);
      expect(i.concluida || i.recusada || i.cancelada, isFalse);
    });

    test('é o proximo_passo que manda, não o estado', () {
      // Um estado conhecido com um passo que não se conhece: nada de botões.
      final i = InscricaoSocio.fromJson(inscricaoJson(estado: 'admitida', proximo: 'confirmar_email'));
      expect(i.passo, PassoInscricao.desconhecido);
      expect(i.podeDesistir, isFalse);
    });
  });

  group('409 ja_existe', () {
    ApiException conflito(Map<String, dynamic> extra) => ApiException(
      httpStatus: 409,
      erro: 'ja_existe',
      message: 'Já tem uma inscrição a meio para esta pessoa. Continue essa.',
      dados: {'status': 'error', 'erro': 'ja_existe', ...extra},
    );

    test('com `id`, como diz o guia', () {
      expect(inscricaoExistente(conflito({'id': '01MABC'})), '01MABC');
    });

    test('com `inscricao`, como o servidor manda hoje', () {
      expect(inscricaoExistente(conflito({'inscricao': '01MXYZ', 'estado': 'admitida'})), '01MXYZ');
    });

    test('outro erro não é uma inscrição a continuar', () {
      const e = ApiException(erro: 'dados_invalidos', message: 'Escreva o nome completo.', dados: {'id': 'X'});
      expect(inscricaoExistente(e), isNull);
    });
  });

  group('o que se envia', () {
    test('para a própria pessoa: sem campos do encarregado, sem vazios', () {
      final j = DadosInscricao(
        dependente: false,
        nome: '  Maria Silva Santos ',
        dataNascimento: DateTime(1990, 5, 2),
        nif: '123456789',
        cp: '2740025',
        email: '',
        encNome: 'Não devia ir',
      ).toJson();
      expect(j, {
        'para': 'propria',
        'nome': 'Maria Silva Santos',
        'data_nascimento': '1990-05-02',
        'nif': '123456789',
        'cp': '2740025', // o servidor arruma
      });
    });

    test('para um dependente: vão os campos do encarregado', () {
      final j = DadosInscricao(
        dependente: true,
        nome: 'Tomás Silva',
        dataNascimento: DateTime(2016, 1, 10),
        encNome: 'Maria Silva Santos',
        encParentesco: 'mãe',
        encTelefone: '912345678',
        encEmail: 'maria@exemplo.pt',
      ).toJson();
      expect(j['para'], 'dependente');
      expect(j['enc_nome'], 'Maria Silva Santos');
      expect(j['enc_parentesco'], 'mãe');
      expect(j.containsKey('enc_cc'), isFalse);
    });

    test('a assinatura vai como data URI de PNG', () {
      expect(dataUriPng(Uint8List.fromList([1, 2, 3])), 'data:image/png;base64,AQID');
    });
  });

  group('pedidos', () {
    late _Servidor s;
    late Inscricoes api;

    setUp(() {
      s = _Servidor();
      api = Inscricoes(Dio(BaseOptions(baseUrl: 'http://cisoc/api/v2'))..httpClientAdapter = s);
    });

    test('submeter devolve a inscrição já à espera', () async {
      s.respostas['POST /me/inscricoes'] = (201, _ok({'inscricao': inscricaoJson()}));
      final i = await api.submeter(
        DadosInscricao(dependente: false, nome: 'Maria Silva', dataNascimento: DateTime(1990)),
      );
      expect(i.passo, PassoInscricao.aguardar);
    });

    test('um 409 ja_existe chega com o id da que está a meio', () async {
      s.respostas['POST /me/inscricoes'] = (
        409,
        {'status': 'error', 'erro': 'ja_existe', 'message': 'Continue essa.', 'inscricao': '01MOUTRA'},
      );
      try {
        await api.submeter(DadosInscricao(dependente: false, nome: 'Maria Silva', dataNascimento: DateTime(1990)));
        fail('devia lançar');
      } on ApiException catch (e) {
        expect(inscricaoExistente(e), '01MOUTRA');
      }
    });

    test('pagar não manda valor nenhum, e o que conta é o método da resposta', () async {
      s.respostas['POST /me/inscricoes/01MINSC/pagamento'] = (
        201,
        _ok({
          // Um MB WAY que falhou cai para PayByLink.
          'pagamento': {
            'referencia': 10422,
            'metodo': 'paybylink',
            'valor': 12,
            'meses': 6,
            'url_pagamento': 'https://pay.exemplo/x',
            'telefone': null,
            'limite': '2026-10-07',
          },
          'inscricao': inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, porAssinar: []),
        }),
      );
      final (p, i) = await api.pagar('01MINSC', meses: 6, metodo: 'mbway', telefone: '912345678');

      expect(s.ultimo('POST').data, {'meses': 6, 'metodo': 'mbway', 'telefone': '912345678'});
      expect(p.metodo, 'paybylink');
      expect(p.mbway, isFalse);
      expect(p.valor, 12);
      expect(p.temLink, isTrue);
      expect(p.limite, DateTime(2026, 10, 7));
      // Um 201 não é pago: a inscrição continua à espera do pagamento.
      expect(i.passo, PassoInscricao.pagar);
      expect(i.concluida, isFalse);
    });

    test('por referência não se manda telefone', () async {
      s.respostas['POST /me/inscricoes/01MINSC/pagamento'] = (
        201,
        _ok({
          'pagamento': {'metodo': 'paybylink', 'valor': 6, 'meses': 3},
          'inscricao': inscricaoJson(estado: 'assinada', proximo: 'pagar', porAssinar: []),
        }),
      );
      await api.pagar('01MINSC', meses: 3, metodo: 'paybylink', telefone: '912345678');
      expect(s.ultimo('POST').data, {'meses': 3, 'metodo': 'paybylink'});
    });

    test('assinar manda o documento e a imagem, sem nome de assinante', () async {
      s.respostas['POST /me/inscricoes/01MINSC/assinar'] = (
        200,
        _ok({
          'inscricao': inscricaoJson(estado: 'admitida', proximo: 'assinar', porAssinar: ['termo_responsabilidade']),
        }),
      );
      final i = await api.assinar('01MINSC', documento: 'ficha_socio', png: Uint8List.fromList([137, 80]));
      expect(s.ultimo('POST').data, {'documento': 'ficha_socio', 'assinatura': 'data:image/png;base64,iVA='});
      expect(i.proximoDocumento?.tipo, 'termo_responsabilidade');
    });

    test('assinar cedo demais: 409 estado_invalido com a mensagem do servidor', () async {
      s.respostas['POST /me/inscricoes/01MINSC/assinar'] = (
        409,
        {'status': 'error', 'erro': 'estado_invalido', 'message': 'O clube ainda está a ver o seu pedido.'},
      );
      expect(
        () => api.assinar('01MINSC', documento: 'ficha_socio', png: Uint8List(0)),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'O clube ainda está a ver o seu pedido.')),
      );
    });

    test('o erro de um PDF chega em bytes e sai como ApiException', () async {
      s.respostas['GET /me/inscricoes/01MINSC/documentos/ficha_socio'] = (
        404,
        {'status': 'error', 'erro': 'nao_encontrado', 'message': 'Esse documento ainda não foi assinado.'},
      );
      expect(
        () => api.pdf('01MINSC', 'ficha_socio'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Esse documento ainda não foi assinado.')),
      );
    });

    test('a lista ignora entradas sem id', () async {
      s.respostas['GET /me/inscricoes'] = (
        200,
        _ok({
          'inscricoes': [inscricaoJson(), 'lixo', <String, dynamic>{}],
        }),
      );
      expect(await api.listar(), hasLength(1));
    });
  });

  group('o fim', () {
    late _Servidor s;
    late ProviderContainer c;

    setUp(() async {
      s = _Servidor();
      final dio = Dio(BaseOptions(baseUrl: 'http://cisoc/api/v2'))..httpClientAdapter = s;
      FlutterSecureStorage.setMockInitialValues({
        'lps.access_token': 'a1',
        'lps.refresh_token': 'r1',
        'lps.conta': jsonEncode({'nome': 'Maria', 'email': 'maria@exemplo.pt', 'socio': null}),
      });
      final tokens = TokenStore(const FlutterSecureStorage(), dio);
      await tokens.carregar();
      s.respostas['POST /auth/refresh'] = (
        200,
        _ok({
          'access_token': 'a2',
          'refresh_token': 'r2',
          'conta': {
            'nome': 'Maria',
            'email': 'maria@exemplo.pt',
            'socio': {'nr_socio': 7412, 'nome_completo': 'MARIA SILVA SANTOS', 'estado': 1},
          },
        }),
      );
      // Cada escrita invalida a lista; em modo debug o Riverpod chega a criá-la.
      s.respostas['GET /me/inscricoes'] = (200, _ok({'inscricoes': <Object>[]}));
      c = ProviderContainer(
        overrides: [
          sessaoProvider.overrideWith(_ComConta.new),
          ligacaoProvider.overrideWith(_Online.new),
          cacheProvider.overrideWithValue(CacheEmMemoria()),
          dioContaProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(c.dispose);
    });

    test('quando a própria fica concluída, renova-se a sessão para trazer a ficha', () async {
      s.respostas['GET /me/inscricoes/01MINSC'] = (
        200,
        _ok({'inscricao': inscricaoJson(estado: 'assinada', proximo: 'pagar', nrSocio: 7412, porAssinar: [])}),
      );
      final sub = c.listen(inscricaoProvider('01MINSC'), (_, _) {});
      addTearDown(sub.close);
      await c.read(inscricaoProvider('01MINSC').future);
      expect(s.pedidos.where((p) => p.path == '/auth/refresh'), isEmpty);

      // O pagamento entra do lado do servidor.
      s.respostas['GET /me/inscricoes/01MINSC'] = (
        200,
        _ok({'inscricao': inscricaoJson(estado: 'concluida', proximo: 'nada', nrSocio: 7412, porAssinar: [])}),
      );
      await c.read(inscricaoProvider('01MINSC').notifier).actualizar();
      await _assentar();

      expect(s.pedidos.where((p) => p.path == '/auth/refresh'), hasLength(1));
      expect(c.read(tokenStoreProvider).socio?['nr_socio'], 7412);

      // Consultar outra vez não volta a renovar.
      await c.read(inscricaoProvider('01MINSC').notifier).actualizar();
      await _assentar();
      expect(s.pedidos.where((p) => p.path == '/auth/refresh'), hasLength(1));
    });

    test('a de um dependente concluída renova a sessão: `conta.dependentes` muda', () async {
      s.respostas['GET /me/inscricoes/01MINSC'] = (
        200,
        _ok({
          'inscricao': inscricaoJson(
            estado: 'concluida',
            proximo: 'nada',
            para: 'dependente',
            nrSocio: 9001,
            porAssinar: [],
          ),
        }),
      );
      final sub = c.listen(inscricaoProvider('01MINSC'), (_, _) {});
      addTearDown(sub.close);
      final i = await c.read(inscricaoProvider('01MINSC').future);
      await _assentar();

      expect(i.concluida, isTrue);
      expect(s.pedidos.where((p) => p.path == '/auth/refresh'), hasLength(1));
    });
  });
}
