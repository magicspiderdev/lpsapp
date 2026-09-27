import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lpsapp/core/links.dart';
import 'package:lpsapp/core/router.dart';
import 'package:lpsapp/features/auth/entrar_page.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';

/// Um pedido de rota com a app já arrancada, sem sessão.
String? ir(String rota, {bool socio = false, bool bloqueada = false, bool aArrancar = false}) => destinoDoRedirect(
  Uri.parse(rota),
  versaoACarregar: aArrancar,
  bloquearVersao: false,
  socio: socio,
  bloqueada: bloqueada,
);

void main() {
  group('links partilhados', () {
    test('notícia e sessão apontam para a mesma página no site oficial, com a barra canónica', () {
      expect(
        Links.noticia('empate-na-liga').toString(),
        'https://www.leoesdeportosalvo.pt/noticias/empate-na-liga/',
      );
      expect(
        Links.sessao('01M2X7Y601VARR4JF5NPXYFGFS').toString(),
        'https://www.leoesdeportosalvo.pt/bilhetes/01M2X7Y601VARR4JF5NPXYFGFS/',
      );
    });

    test('um link do site perde a barra do fim e vira rota', () {
      expect(ir('https://leoesdeportosalvo.pt/noticias/x/'), '/noticias/x');
      expect(ir('https://new.leoesdeportosalvo.pt/noticias/x/'), '/noticias/x');
      expect(ir('/bilhetes/ABC/?z=1-2'), '/bilhetes/ABC?z=1-2');
    });

    test('um link inteiro já sem a barra (como o go_router o entrega) também vira rota', () {
      expect(ir('https://www.leoesdeportosalvo.pt/noticias/x'), '/noticias/x');
      expect(ir('https://www.leoesdeportosalvo.pt/bilhetes/ABC?z=1-2'), '/bilhetes/ABC?z=1-2');
    });

    test('link aberto com a app fechada: chega à notícia depois do arranque', () {
      final rota = ir('https://www.leoesdeportosalvo.pt/noticias/x', aArrancar: true)!;
      expect(rota, '/noticias/x');
      final arranque = ir(rota, aArrancar: true)!;
      expect(ir(arranque), '/noticias/x');
    });

    test('os links antigos, no CISOC, continuam a abrir', () {
      expect(ir('https://mylps.leoesdeportosalvo.pt/lps/noticias/x'), '/noticias/x');
      expect(ir('/lps/bilhetes/ABC?z=1-2'), '/bilhetes/ABC?z=1-2');
      expect(ir('/lps'), '/');
    });

    test('as rotas da app passam sem mexer', () {
      expect(ir('/noticias/x'), isNull);
      expect(ir('/bilhetes/ABC'), isNull);
      expect(ir('/lpsx/noticias'), isNull); // não é o prefixo, é outra coisa
    });
  });

  group('o destino não se perde', () {
    test('link aberto durante o arranque: guardado e retomado', () {
      final arranque = ir('/noticias/x', aArrancar: true)!;
      expect(arranque, startsWith('/arranque?para='));
      expect(ir(arranque), '/noticias/x');
      expect(ir('/arranque'), '/noticias');
    });

    test('zona do sócio sem sessão: entrar e voltar ao mesmo sítio', () {
      final entrar = ir('/socio/faturas/12')!;
      expect(Uri.parse(entrar).path, '/entrar');
      expect(ir(entrar, socio: true), '/socio/faturas/12');
    });

    test('comprar bilhetes sem sessão: volta à sessão com a escolha', () {
      const voltar = '/bilhetes/ABC?z=1-2';
      final entrar = Uri(path: '/entrar', queryParameters: {'voltar': voltar, 'motivo': 'bilhetes'}).toString();
      expect(ir(entrar), isNull); // mostra o ecrã de entrar
      expect(ir(entrar, socio: true), voltar);
      expect(ir('/entrar', socio: true), '/socio');
    });

    test('sessão bloqueada pela biometria: desbloquear e seguir', () {
      final desbloquear = ir('/socio/cartao', socio: true, bloqueada: true)!;
      expect(Uri.parse(desbloquear).path, '/desbloquear');
      expect(ir(desbloquear, socio: true), '/socio/cartao');
    });

    test('"voltar" para fora da app é ignorado', () {
      expect(ir('/entrar?voltar=https://mau.site', socio: true), '/socio');
      expect(ir('/entrar?voltar=//mau.site', socio: true), '/socio');
      expect(ir('/arranque?para=https://mau.site'), '/noticias');
    });
  });

  group('onde vive o login', () {
    bool temEntrar(RouteBase r) =>
        (r is GoRoute && r.path.startsWith('/entrar')) || r.routes.any(temEntrar);

    test('o login não vive dentro de um separador da navegação', () {
      // Se vivesse, o separador guardava-o como o seu último sítio; e como
      // `/entrar` com sessão reenvia para o `?voltar=`, tocar em "Sócio"
      // depois de entrar para comprar bilhetes levava outra vez aos bilhetes.
      final shell = rotasDaApp.whereType<StatefulShellRoute>().single;
      expect(
        shell.branches.any((b) => b.routes.any(temEntrar)),
        isFalse,
        reason: 'O ecrã de entrar só existe até se entrar: nenhum ramo o pode guardar.',
      );
    });

    test('o login existe como rota de topo', () {
      expect(rotasDaApp.any(temEntrar), isTrue);
    });

    test('fechar o login volta ao que se estava a fazer, se isso não exigir sessão', () {
      expect(saidaDoLogin('/bilhetes/01M2T9?z=1-2'), '/bilhetes/01M2T9?z=1-2');
      expect(saidaDoLogin('/noticias/empate-na-liga'), '/noticias/empate-na-liga');
    });

    test('fechar o login não devolve a um sítio que exija sessão nem para fora da app', () {
      // Voltar para `/socio` só mandava de novo para o login.
      expect(saidaDoLogin('/socio/quotas'), '/noticias');
      expect(saidaDoLogin(null), '/noticias');
      expect(saidaDoLogin('https://mau.site'), '/noticias');
      expect(saidaDoLogin('//mau.site'), '/noticias');
    });
  });

  group('escolha de bilhetes no link', () {
    test('ida e volta', () {
      final q = {'1': 2, '2': 1};
      expect(quantidadesDoLink(quantidadesParaLink(q)), q);
    });

    test('valores estranhos ignoram-se e o máximo é respeitado', () {
      expect(quantidadesDoLink(null), isEmpty);
      expect(quantidadesDoLink('1-x,,2-0,-3,4-99'), {'4': maxBilhetesPorZona});
    });
  });
}
