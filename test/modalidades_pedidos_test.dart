import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/features/modalidades_pedidos/modalidades_pedidos.dart';

/// Pedidos de inscrição e de baixa em modalidades (guia §4.22). O que estes
/// testes protegem: um valor por saber nunca vira "0 €", estados e tipos
/// desconhecidos não rebentam, e o `409 ja_existe` traz o `id` para abrir.
class _Servidor implements HttpClientAdapter {
  final respostas = <String, (int, Map<String, dynamic>)>{};
  final pedidos = <RequestOptions>[];

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

Map<String, dynamic> _pedido({
  String id = '01M1',
  String tipo = 'inscricao',
  String estado = 'submetido',
  String? estadoLabel = 'Por decidir',
  bool aberto = true,
  bool cancelavel = true,
  Object? valor = 25,
  String? motivo,
  String criado = '2026-09-22 18:40:00',
}) => {
  'id': id,
  'tipo': tipo,
  'tipo_label': tipo == 'baixa' ? 'Baixa' : 'Inscrição',
  'estado': estado,
  'estado_label': estadoLabel,
  'aberto': aberto,
  'cancelavel': cancelavel,
  'modalidade': {'slug': 'patinagem', 'nome': 'Patinagem'},
  'atleta': {'nr_socio': 9302, 'nome_completo': 'CARMINHO EXEMPLO'},
  'observacoes': 'Só pode depois das 18h.',
  'valor_estimado': valor,
  'motivo': motivo,
  'criado_em': criado,
  'decidido_em': null,
};

void main() {
  group('PedidoModalidade', () {
    test('lê a resposta do guia', () {
      final p = PedidoModalidade.fromJson(_pedido());
      expect(p.id, '01M1');
      expect(p.tipoLabel, 'Inscrição');
      expect(p.estadoLabel, 'Por decidir');
      expect(p.aberto, isTrue);
      expect(p.cancelavel, isTrue);
      expect(p.modalidadeSlug, 'patinagem');
      expect(p.modalidadeNome, 'Patinagem');
      expect(p.atletaNrSocio, 9302);
      expect(p.atletaNome, 'CARMINHO EXEMPLO');
      expect(p.valorEstimado, 25);
      expect(p.criadoEm, DateTime(2026, 9, 22, 18, 40));
      expect(p.decididoEm, isNull);
    });

    test('valor estimado null: diz que a secretaria confirma, nunca "0 €"', () {
      final p = PedidoModalidade.fromJson(_pedido(valor: null));
      expect(p.valorEstimado, isNull);
      final texto = textoValorEstimado(p)!;
      expect(texto, 'O valor é confirmado pela secretaria.');
      expect(texto, isNot(contains('0')));
    });

    test('com valor, mostra-o como estimativa em euros', () {
      final texto = textoValorEstimado(PedidoModalidade.fromJson(_pedido(valor: 25)))!;
      expect(texto, contains('25,00'));
      expect(texto, contains('estimativa'));
    });

    test('numa baixa não há linha de valor', () {
      final p = PedidoModalidade.fromJson(_pedido(tipo: 'baixa', valor: null));
      expect(p.baixa, isTrue);
      expect(textoValorEstimado(p), isNull);
    });

    test('um estado desconhecido não rebenta e mostra o que o servidor diz', () {
      final p = PedidoModalidade.fromJson(
        _pedido(estado: 'em_revisao', estadoLabel: 'Em revisão', aberto: true, cancelavel: false),
      );
      expect(p.estado, 'em_revisao');
      expect(p.estadoLabel, 'Em revisão');
      expect(p.cancelavel, isFalse);
    });

    test('sem estado_label, usa o estado legível; sem campos, não rebenta', () {
      final p = PedidoModalidade.fromJson(_pedido(estado: 'em_espera', estadoLabel: null));
      expect(p.estadoLabel, 'Em espera');

      final vazio = PedidoModalidade.fromJson(const {'id': 'X', 'tipo': 'transferencia'});
      expect(vazio.tipoLabel, 'Transferencia');
      expect(vazio.aberto, isFalse);
      expect(vazio.cancelavel, isFalse);
      expect(vazio.baixa, isFalse);
      expect(vazio.modalidadeNome, 'Modalidade');
      expect(vazio.valorEstimado, isNull);
    });

    test('um valor que não é número conta como por saber', () {
      expect(PedidoModalidade.fromJson(_pedido(valor: '25')).valorEstimado, isNull);
      expect(PedidoModalidade.fromJson(_pedido(valor: 25.5)).valorEstimado, 25.5);
    });

    test('baixa recusada com motivo: pede o caminho para a secretaria', () {
      final p = PedidoModalidade.fromJson(
        _pedido(
          tipo: 'baixa',
          estado: 'recusado',
          estadoLabel: 'Recusado',
          aberto: false,
          cancelavel: false,
          motivo: 'Falta devolver o equipamento.',
        ),
      );
      expect(p.temMotivo, isTrue);
      expect(p.baixaPorResolver, isTrue);

      final inscricao = PedidoModalidade.fromJson(
        _pedido(estado: 'recusado', aberto: false, cancelavel: false, motivo: 'Sem vaga.'),
      );
      expect(inscricao.temMotivo, isTrue);
      expect(inscricao.baixaPorResolver, isFalse);
    });
  });

  group('atletas', () {
    final d = PedidosModalidades.fromJson({
      'pedidos': [
        _pedido(id: 'A', aberto: false, cancelavel: false, estado: 'aprovado', criado: '2026-09-20 10:00:00'),
        _pedido(id: 'B', criado: '2026-09-01 10:00:00'),
        _pedido(id: 'C', aberto: false, cancelavel: false, estado: 'cancelado', criado: '2026-09-21 10:00:00'),
        'lixo',
      ],
      'atletas': [
        {
          'nr_socio': 9301,
          'nome_completo': 'JOÃO EXEMPLO',
          'idade': 41,
          'relacao': 'proprio',
          'pode_inscrever': true,
          'porque_nao': null,
        },
        {
          'nr_socio': 9303,
          'nome_completo': 'RUI EXEMPLO',
          'idade': null,
          'relacao': 'pai',
          'pode_inscrever': false,
          'porque_nao': 'A ficha deste sócio não está activa. Fale com a secretaria.',
        },
        {'nome_completo': 'SEM NÚMERO'},
      ],
    });

    test('ignora o que não é um pedido ou não tem número', () {
      expect(d.pedidos, hasLength(3));
      expect(d.atletas, hasLength(2));
    });

    test('os por decidir primeiro, depois os mais recentes', () {
      expect(d.ordenados.map((p) => p.id), ['B', 'C', 'A']);
    });

    test('quem não pode inscrever-se vem com a razão, e pode pedir a baixa', () {
      final rui = d.atletas[1];
      expect(rui.podeInscrever, isFalse);
      expect(rui.porqueNao, contains('não está activa'));
      expect(rui.podePara(TipoPedido.inscricao), isFalse);
      expect(rui.podePara(TipoPedido.baixa), isTrue, reason: 'a baixa não exige ficha activa (§4.22.3)');
      expect(rui.descricao, 'A cargo (pai)');
      expect(d.atletas.first.proprio, isTrue);
      expect(d.atletas.first.descricao, 'Eu · 41 anos');
    });
  });

  group('API', () {
    late _Servidor servidor;
    late AccoesModalidades accoes;

    setUp(() {
      servidor = _Servidor();
      accoes = AccoesModalidades(Dio(BaseOptions(baseUrl: 'https://x/api/v2'))..httpClientAdapter = servidor);
    });

    test('pedir envia modalidade, tipo e atleta; observações só se houver', () async {
      servidor.respostas['POST /me/modalidades'] = (
        201,
        {
          'status': 'success',
          'data': {'pedido': _pedido()},
        },
      );

      final p = await accoes.pedir(modalidade: 'patinagem', tipo: 'inscricao', nrSocio: 9302, observacoes: '  ');
      expect(p.id, '01M1');
      expect(servidor.pedidos.single.data, {'modalidade': 'patinagem', 'tipo': 'inscricao', 'nr_socio': 9302});

      await accoes.pedir(modalidade: 'patinagem', tipo: 'baixa', nrSocio: 9302, observacoes: ' Até ao fim do mês ');
      expect((servidor.pedidos.last.data as Map)['observacoes'], 'Até ao fim do mês');
    });

    test('409 ja_existe traz o id do pedido que está por decidir', () async {
      servidor.respostas['POST /me/modalidades'] = (
        409,
        {
          'status': 'error',
          'erro': 'ja_existe',
          'message': 'Já há um pedido para Patinagem à espera de decisão.',
          'id': '01MABERTO',
        },
      );

      await expectLater(
        accoes.pedir(modalidade: 'patinagem', tipo: 'inscricao', nrSocio: 9302),
        throwsA(
          isA<ApiException>()
              .having((e) => e.erro, 'erro', 'ja_existe')
              .having((e) => e.dados['id'], 'id', '01MABERTO'),
        ),
      );
    });

    test('cancelar é um DELETE ao pedido e devolve-o como ficou', () async {
      servidor.respostas['DELETE /me/modalidades/01M1'] = (
        200,
        {
          'status': 'success',
          'data': {'pedido': _pedido(estado: 'cancelado', estadoLabel: 'Cancelado', aberto: false, cancelavel: false)},
        },
      );

      final p = await accoes.cancelar('01M1');
      expect(p.aberto, isFalse);
      expect(p.estadoLabel, 'Cancelado');
    });
  });

  test('rotas', () {
    expect(RotasModalidades.pedido('01M1'), '/socio/conta/modalidades/01M1');
    expect(
      RotasModalidades.pedirCom(modalidade: 'futsal', tipo: 'baixa'),
      '/socio/conta/modalidades/pedir?modalidade=futsal&tipo=baixa',
    );
    expect(RotasModalidades.pedirCom(), '/socio/conta/modalidades/pedir');
  });
}
