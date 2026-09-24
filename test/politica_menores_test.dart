/// Política de menores, fases 2 a 9 (guia §2.3.4, §2.10, §2.12, §4.18): as
/// capacidades da conta e dos dependentes, o encarregado sem ficha própria e
/// os bilhetes comprados para um dependente.
///
/// A app desenha com o que o servidor manda — **nunca calcula idades**.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/auth/sessao.dart';
import 'package:lpsapp/core/formatos.dart';
import 'package:lpsapp/core/router.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart' show BilheteComprado, Zona;
import 'package:lpsapp/features/publico/bilheteira/compra.dart';

Map<String, dynamic> _conta({
  List<String>? capacidades,
  List<Map<String, dynamic>> dependentes = const [],
  bool comSocio = true,
  Map<String, bool>? permissoes,
}) => {
  'email': 'ana@exemplo.pt',
  'nome': 'Ana',
  'faixa_etaria': 'adult',
  'idade_verificada': comSocio,
  'capacidades': ?capacidades,
  'permissoes': ?permissoes,
  'dependentes': dependentes,
  'socio': comSocio ? {'nr_socio': 16, 'nome_completo': 'ANA', 'estado': 1} : null,
};

Map<String, dynamic> _filho({List<String> capacidades = const ['view_member_card', 'buy_tickets']}) => {
  'nr_socio': 5643,
  'nome': 'CARMINHO EXEMPLO',
  'relacao': 'mae',
  'faixa_etaria': 'child',
  'capacidades': capacidades,
};

void main() {
  group('capacidades (§2.12)', () {
    test('lê as da conta, as dos dependentes, a faixa e a idade verificada', () {
      final c = ContaSessao.fromJson(_conta(capacidades: ['buy_tickets'], dependentes: [_filho()]));
      expect(c.faixaEtaria, 'adult');
      expect(c.idadeVerificada, isTrue);
      expect(c.tem(Capacidade.comprarBilhetes), isTrue);
      expect(c.tem(Capacidade.editarFicha), isFalse);

      final d = c.dependente(5643)!;
      expect(d.relacao, 'mae');
      expect(d.faixaEtaria, 'child');
      expect(d.tem(Capacidade.comprarBilhetes), isTrue);
      expect(d.tem(Capacidade.pagar), isFalse);
    });

    test('com a lista presente, só vale o que lá está — mesmo o que não se conhece', () {
      final c = ContaSessao.fromJson(_conta(capacidades: ['uma_nova']));
      expect(c.tem(Capacidade.pagar), isFalse);
      expect(c.tem('uma_nova'), isTrue);
    });

    test('sessão guardada antes das capacidades: valem as permissões', () {
      final menor = ContaSessao.fromJson(_conta(permissoes: {'pagar': false, 'comprar': false}));
      expect(menor.capacidades, isNull);
      expect(menor.tem(Capacidade.pagar), isFalse);
      expect(menor.tem(Capacidade.comprarBilhetes), isFalse);
      // O que não tinha permissão antiga não se fecha por falta de lista.
      expect(menor.tem(Capacidade.editarFicha), isTrue);
    });

    test('um dependente mal formado não entra na lista', () {
      final c = ContaSessao.fromJson(
        _conta(
          dependentes: [
            {'nome': 'sem número'},
            _filho(),
          ],
        ),
      );
      expect(c.dependentes.map((d) => d.nrSocio), [5643]);
    });
  });

  group('encarregado sem ficha (§2.3.4)', () {
    final encarregado = sessaoDaConta(_conta(comSocio: false, dependentes: [_filho()]));
    final soConta = sessaoDaConta(_conta(comSocio: false));
    final socio = sessaoDaConta(_conta());

    test('só uma conta sem ficha e com dependentes', () {
      expect(eEncarregadoSemFicha(encarregado), isTrue);
      expect(eEncarregadoSemFicha(soConta), isFalse);
      expect(eEncarregadoSemFicha(socio), isFalse);
      expect(temZonaPrivada(encarregado), isTrue);
      expect(temZonaPrivada(soConta), isFalse);
    });

    test('as caches da zona privada têm dono mesmo sem ficha', () {
      expect(chaveDaSessao(socio), '16');
      expect(chaveDaSessao(encarregado), 'conta.ana@exemplo.pt');
    });

    String? ir(String rota, {bool encarregado = true}) => destinoDoRedirect(
      Uri.parse(rota),
      versaoACarregar: false,
      bloquearVersao: false,
      socio: false,
      bloqueada: false,
      temConta: true,
      encarregado: encarregado,
    );

    test('vê a conta dos educandos: quotas, faturas, cartão, documentos', () {
      for (final r in ['/socio/educando', '/socio/quotas', '/socio/faturas/3', '/socio/cartao', '/socio/documentos']) {
        expect(ir(r), isNull, reason: r);
      }
    });

    test('o que é só da ficha própria manda associar a ficha', () {
      for (final r in ['/socio/perfil', '/socio/suporte', '/socio/notificacoes']) {
        expect(Uri.parse(ir(r)!).path, '/associar-socio', reason: r);
      }
    });

    test('sem educandos, a conta sem ficha continua sem a zona do sócio', () {
      expect(Uri.parse(ir('/socio/quotas', encarregado: false)!).path, '/associar-socio');
    });

    test('pedir para acompanhar um educando abre para qualquer conta', () {
      expect(ir('/socio/dependentes', encarregado: false), isNull);
    });
  });

  group('bilhetes para um dependente (§4.18)', () {
    Zona zona({bool exigeSocio = false}) =>
        Zona.fromJson({'id': 3, 'nome': 'Sócios', 'preco': 0, 'disponivel': true, 'exige_socio': exigeSocio});

    test('um encarregado sem ficha compra numa zona de sócios, para o filho', () {
      final quem = sessaoDaConta(_conta(comSocio: false, capacidades: ['buy_tickets'], dependentes: [_filho()]));
      expect(quemPodeComprar(quem, zona(exigeSocio: true), sessaoAVenda: true), QuemPode.podeComprar);

      final para = paraQuem(quem, zona(exigeSocio: true));
      expect(para.propria, isFalse, reason: 'a zona é de sócios e ele não é');
      expect(para.dependentes.single.nrSocio, 5643);
    });

    test('sem dependentes por quem possa comprar, continua a pedir a ficha', () {
      final quem = sessaoDaConta(
        _conta(
          comSocio: false,
          capacidades: ['buy_tickets'],
          dependentes: [_filho(capacidades: const [])],
        ),
      );
      expect(quemPodeComprar(quem, zona(exigeSocio: true), sessaoAVenda: true), QuemPode.precisaDeSocio);
    });

    test('numa zona aberta, compra para si e para o filho', () {
      final quem = sessaoDaConta(_conta(capacidades: ['buy_tickets'], dependentes: [_filho()]));
      final para = paraQuem(quem, zona());
      expect(para.propria, isTrue);
      expect(para.dependentes, hasLength(1));
    });

    test('a carteira diz para quem é e quem comprou', () {
      final b = BilheteComprado.fromJson({
        'id': 'B1',
        'codigo': 'LPS-1',
        'titulo': 'Jogo',
        'zona': 'Sócios',
        'titular': 'CARMINHO EXEMPLO',
        'para': {'nr_socio': 5643, 'nome': 'CARMINHO EXEMPLO'},
        'comprado_por_outro': true,
      });
      expect(b.paraNome, 'CARMINHO EXEMPLO');
      expect(b.compradoPorOutro, isTrue);

      final meu = BilheteComprado.fromJson({'id': 'B2', 'codigo': 'LPS-2', 'titulo': '', 'zona': '', 'para': null});
      expect(meu.paraNome, isNull);
      expect(meu.compradoPorOutro, isFalse);
    });
  });

  test('primeiro nome legível a partir da ficha em maiúsculas', () {
    expect(primeiroNome('CARMINHO EXEMPLO'), 'Carminho');
    expect(primeiroNome('  joão  '), 'João');
    expect(primeiroNome(''), '');
  });
}
