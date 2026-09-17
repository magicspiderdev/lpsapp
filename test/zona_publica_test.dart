import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/features/publico/agenda/agenda.dart';
import 'package:lpsapp/features/publico/bilheteira/bilheteira.dart';
import 'package:lpsapp/features/publico/clube/clube.dart';

/// Os ecrãs da agenda, bilheteira e clube já existem; a API ainda não. Os
/// modelos seguem o contrato pedido ao CISOC.
void main() {
  group('bilhetes comprados', _bilhetesComprados);

  group('agenda', () {
    test('jogo com resultado, equipa do clube e bilhetes', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'jogo',
        'id': 812,
        'titulo': 'Benfica x Leões',
        'inicio': '2026-09-15 19:00:00',
        'estado': 'terminado',
        'modalidade': {'nome': 'Hóquei em patins'},
        'prova': {'nome': 'Nacional'},
        'recinto': 'Pavilhão da Luz',
        'equipa_casa': {'nome': 'SL Benfica'},
        'equipa_fora': {'nome': 'Leões Porto Salvo', 'do_clube': true},
        'resultado': {'casa': 2, 'fora': 3},
        'bilhetes': {'sessao': 'S9'},
      });
      expect(i.tipo, TipoItem.jogo);
      expect(i.terminado, isTrue);
      expect(i.temResultado, isTrue);
      expect(i.fora?.doClube, isTrue);
      expect(i.local, 'Pavilhão da Luz');
      expect(i.sessaoBilhetes, 'S9');
    });

    test('hora por confirmar e tipo desconhecido não rebentam', () {
      final i = ItemAgenda.fromJson({
        'tipo': 'gala',
        'id': 5,
        'titulo': 'Gala do clube',
        'inicio': '2026-10-01 00:00:00',
        'hora_confirmada': false,
      });
      expect(i.tipo, TipoItem.desconhecido);
      expect(i.horaConfirmada, isFalse);
      expect(i.estado, 'agendado');
      expect(i.temBilhetes, isFalse);
    });

    test('exemplos da demonstração cobrem jogo, evento e resultado', () {
      expect(agendaExemplo.any((i) => i.tipo == TipoItem.jogo), isTrue);
      expect(agendaExemplo.any((i) => i.tipo == TipoItem.evento), isTrue);
      expect(agendaExemplo.any((i) => i.temResultado), isTrue);
    });
  });

  group('bilheteira', () {
    test('sessão com zonas, preço desde e esgotado', () {
      final s = Sessao.fromJson({
        'id': 'S1',
        'titulo': 'Jogo',
        'inicio': '2026-09-20 21:00:00',
        'preco_desde': 5,
        'esgotado': false,
        'zonas': [
          {'id': 'Z1', 'nome': 'Central', 'preco': 10},
          {'id': 'Z2', 'nome': 'Criança', 'preco': 0, 'disponivel': false},
        ],
      });
      expect(s.precoDesde, 5.0);
      expect(s.zonas.first.disponivel, isTrue);
      expect(s.zonas.last.preco, 0.0);
      expect(s.zonas.last.disponivel, isFalse);
    });
  });

  group('clube', () {
    test('lê contactos, horário, modalidades e redes', () {
      final c = clubeExemplo;
      expect(c.fundadoEm, 1972);
      expect(c.contactos.any((x) => x.tipo == 'telefone'), isTrue);
      expect(c.horario, isNotEmpty);
      expect(c.modalidades.first.nome, isNotEmpty);
      expect(c.redes.keys, contains('facebook'));
    });

    test('campos em falta ficam nulos, sem rebentar', () {
      final c = Clube.fromJson({'nome': 'Clube'});
      expect(c.fundadoEm, isNull);
      expect(c.contactos, isEmpty);
      expect(c.redes, isEmpty);
    });
  });
}

/// Bilhetes comprados (a carteira): o código é a credencial que a portaria lê.
void _bilhetesComprados() {
  test('bilhete válido e bilhete usado', () {
    final b = BilheteComprado.fromJson({
      'id': 'B1',
      'codigo': 'LPS-2026-0001-8F3A',
      'titulo': 'Jogo',
      'zona': 'Sócio',
      'inicio': '2026-09-18 21:00:00',
      'preco': 5,
      'estado': 'VALIDO',
      'titular': 'João',
    });
    expect(b.valido, isTrue);
    expect(b.usado, isFalse);
    expect(b.codigo, 'LPS-2026-0001-8F3A');

    final usado = BilheteComprado.fromJson({'id': 'B3', 'titulo': 'x', 'zona': 'y', 'estado': 'usado'});
    expect(usado.usado, isTrue);
    expect(usado.valido, isFalse);
  });

  test('estado desconhecido não conta como válido', () {
    final b = BilheteComprado.fromJson({'id': 'B4', 'titulo': 'x', 'zona': 'y', 'estado': 'reembolsado'});
    expect(b.valido, isFalse);
  });

  test('exemplos têm bilhetes por usar e um já usado', () {
    expect(bilhetesExemplo.where((b) => b.valido).length, greaterThan(1));
    expect(bilhetesExemplo.any((b) => b.usado), isTrue);
    expect(bilhetesExemplo.every((b) => b.codigo.isNotEmpty), isTrue);
  });
}
