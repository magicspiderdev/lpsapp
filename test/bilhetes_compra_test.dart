/// Comprar bilhetes (guia §4.18): quem pode levar o quê, e o que a app faz
/// com o que o servidor responde.
///
/// O que estes testes fixam é o contrato, não o desenho: uma encomenda é de
/// uma zona, um `201` não significa pago, e as regras de quem compra não se
/// deduzem do preço.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/bilheteira/compra.dart';

void main() {
  const anonimo = SessaoAnonima();
  final comConta = SessaoConta(const ContaSessao(nome: 'Quem não é sócio'));
  final comSocio = sessaoDeSocio(const SocioSessao(nrSocio: 1234, nomeCompleto: 'Sócio', estado: 1));

  Zona zona({double preco = 5, bool exigeSocio = false, String venda = 'app', bool disponivel = true, int? max}) =>
      Zona.fromJson({
        'id': 3,
        'nome': 'Bancada',
        'preco': preco,
        'disponivel': disponivel,
        'exige_socio': exigeSocio,
        'venda': venda,
        'url_compra': venda == 'externa' ? 'https://www.bol.pt/x' : null,
        'max_por_conta': max,
      });

  group('quem pode comprar', () {
    test('sem sessão nenhuma, o caminho é entrar — não é um erro', () {
      expect(quemPodeComprar(anonimo, zona(), sessaoAVenda: true), QuemPode.precisaDeConta);
      expect(quemPodeComprar(anonimo, zona(preco: 0), sessaoAVenda: true), QuemPode.precisaDeConta);
    });

    test('uma zona gratuita chega a qualquer conta, com ficha ou sem ela', () {
      expect(quemPodeComprar(comConta, zona(preco: 0), sessaoAVenda: true), QuemPode.podeComprar);
      expect(quemPodeComprar(comSocio, zona(preco: 0), sessaoAVenda: true), QuemPode.podeComprar);
    });

    test('uma zona só de sócios pede a ficha a quem só tem conta', () {
      expect(quemPodeComprar(comConta, zona(exigeSocio: true), sessaoAVenda: true), QuemPode.precisaDeSocio);
      expect(quemPodeComprar(comSocio, zona(exigeSocio: true), sessaoAVenda: true), QuemPode.podeComprar);
    });

    test('uma zona gratuita mas só de sócios continua a ser só de sócios', () {
      // É o caso real da sessão em produção: preço 0 e `exige_socio: true`.
      expect(
        quemPodeComprar(comConta, zona(preco: 0, exigeSocio: true), sessaoAVenda: true),
        QuemPode.precisaDeSocio,
      );
      expect(quemPodeComprar(comSocio, zona(preco: 0, exigeSocio: true), sessaoAVenda: true), QuemPode.podeComprar);
    });

    test('o preço não decide nada: uma zona paga não exige ficha por ser paga', () {
      // Desde 2026-09-22 `exige_socio` vem só nas zonas que o clube marcar.
      // Se o servidor ainda recusar, responde `403 conta_sem_socio` e é aí
      // que a app explica — nunca a adivinhar a partir do preço.
      expect(quemPodeComprar(comConta, zona(preco: 7.5), sessaoAVenda: true), QuemPode.podeComprar);
    });

    test('venda externa não se compra na app, nem com sessão de sócio', () {
      expect(quemPodeComprar(comSocio, zona(venda: 'externa'), sessaoAVenda: true), QuemPode.foraDaApp);
    });

    test('um modo de venda que a app não conhece trata-se como fora da app', () {
      expect(quemPodeComprar(comSocio, zona(venda: 'quiosque'), sessaoAVenda: true), QuemPode.foraDaApp);
    });

    test('zona esgotada ou sessão fechada não deixam escolher nada', () {
      expect(quemPodeComprar(comSocio, zona(disponivel: false), sessaoAVenda: true), QuemPode.indisponivel);
      expect(quemPodeComprar(comSocio, zona(), sessaoAVenda: false), QuemPode.indisponivel);
      // A venda fechada manda sobre tudo o resto, até sobre a venda externa.
      expect(quemPodeComprar(comSocio, zona(venda: 'externa'), sessaoAVenda: false), QuemPode.indisponivel);
    });
  });

  group('o máximo por zona', () {
    test('é o que o servidor disser, não o limite do seletor', () {
      expect(zona(max: 2).maximo, 2);
      expect(zona(max: 10).maximo, 10);
    });

    test('sem `max_por_conta`, fica o limite do seletor', () {
      expect(zona().maximo, maxBilhetesPorZona);
    });
  });

  group('a encomenda que o servidor devolve', () {
    test('uma zona gratuita nasce paga e já com os bilhetes', () {
      final c = Compra.fromJson({
        'encomenda': {
          'id': '01J9',
          'estado': 'paga',
          'sessao': {'id': '01J8', 'titulo': 'Leões x Portimonense', 'inicio': '2026-09-26 20:30:00'},
          'zona': {'id': 3, 'nome': 'Sócios'},
          'quantidade': 2,
          'preco': 0,
          'total': 0,
          'metodo': 'gratis',
          'bilhetes': [
            {'id': 'B1', 'codigo': 'LPS-7K3M-9QXA-2FHD', 'titulo': 'Leões x Portimonense', 'zona': 'Sócios'},
            {'id': 'B2', 'codigo': 'LPS-7K3M-9QXA-2FHE', 'titulo': 'Leões x Portimonense', 'zona': 'Sócios'},
          ],
        },
        'pagamento': null,
      });

      expect(c.encomenda.paga, isTrue);
      expect(c.encomenda.gratis, isTrue);
      expect(c.encomenda.bilhetes, hasLength(2));
      expect(c.pagamento, isNull);
      expect(c.encomenda.titulo, 'Leões x Portimonense');
      expect(c.encomenda.zona, 'Sócios');
    });

    test('uma zona paga nasce pendente, sem bilhetes, e com o pagamento', () {
      final c = Compra.fromJson({
        'encomenda': {
          'id': '01J9',
          'estado': 'pendente',
          'zona': {'id': 4, 'nome': 'Não sócios'},
          'quantidade': 2,
          'preco': 5,
          'total': 10,
          'expira_em': '2026-09-19T18:10:00+01:00',
          'bilhetes': [],
        },
        'pagamento': {
          'metodo': 'mbway',
          'referencia': 48213,
          'total': 10,
          'request_id': 'abc',
          'url_pagamento': null,
          'expira_em': '2026-09-19T18:05:00+01:00',
        },
      });

      // Um 201 não é um pagamento: há bilhetes só quando ficar paga.
      expect(c.encomenda.pendente, isTrue);
      expect(c.encomenda.bilhetes, isEmpty);
      expect(c.encomenda.total, 10);
      expect(c.pagamento!.mbway, isTrue);
      expect(c.pagamento!.temLink, isFalse);
      expect(c.pagamento!.expiraEm, isNotNull);
    });

    test('o método que vale é o da resposta: um MB WAY pode cair para link', () {
      final c = Compra.fromJson({
        'encomenda': {'id': '01J9', 'estado': 'pendente', 'total': 10},
        'pagamento': {'metodo': 'paybylink', 'total': 10, 'url_pagamento': 'https://ifthenpay.com/x'},
      });
      expect(c.pagamento!.mbway, isFalse);
      expect(c.pagamento!.temLink, isTrue);
    });

    test('uma encomenda expirada não é uma compra perdida', () {
      // Por pagar e sem lugares guardados — mas um pagamento que chegue
      // depois é aceite e emite os bilhetes (§4.18).
      final c = Compra.fromJson({
        'encomenda': {'id': '01J9', 'estado': 'expirada', 'total': 10, 'bilhetes': []},
      });
      expect(c.encomenda.expirada, isTrue);
      expect(c.encomenda.paga, isFalse);
      expect(c.encomenda.cancelada, isFalse);
    });

    test('um estado que a app não conhece não passa por pago nem por perdido', () {
      final c = Compra.fromJson({
        'encomenda': {'id': '01J9', 'estado': 'em_conferencia', 'total': 10},
      });
      expect(c.encomenda.paga, isFalse);
      expect(c.encomenda.expirada, isFalse);
      expect(c.encomenda.cancelada, isFalse);
      expect(c.encomenda.estado, 'em_conferencia');
    });

    test('uma resposta sem encomenda não rebenta a leitura', () {
      final c = Compra.fromJson(const {});
      expect(c.encomenda.quantidade, 0);
      expect(c.encomenda.bilhetes, isEmpty);
      expect(c.pagamento, isNull);
    });
  });

  group('a escolha que sobrevive ao login', () {
    test('vai e volta no link, uma zona e uma quantidade', () {
      final link = quantidadesParaLink({'3': 2});
      expect(quantidadesDoLink(link), {'3': 2});
    });

    test('um link estragado não escolhe nada', () {
      expect(quantidadesDoLink('lixo'), isEmpty);
      expect(quantidadesDoLink('3-0'), isEmpty);
      expect(quantidadesDoLink(null), isEmpty);
    });
  });
}
