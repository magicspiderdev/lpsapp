import 'package:flutter_test/flutter_test.dart';
import 'package:lpsapp/core/api/api_exception.dart';
import 'package:lpsapp/core/cache/cache_local.dart';
import 'package:lpsapp/core/cache/com_cache.dart';

const _semRede = ApiException(erro: 'sem_ligacao', message: 'Sem ligação');

Stream<Dados<int>> _correr(CacheLocal cache, Future<Map<String, dynamic>> Function() pedido,
        {Ambito ambito = Ambito.publico}) =>
    comCache(cache: cache, ambito: ambito, chave: 'x', pedido: pedido, ler: (j) => j['v'] as int);

void main() {
  test('sem cache e com rede: só os dados do servidor, e ficam guardados', () async {
    final cache = CacheEmMemoria();
    final r = await _correr(cache, () async => {'v': 1}).toList();

    expect(r.map((d) => (d.valor, d.actuais)), [(1, true)]);
    expect((await cache.ler(Ambito.publico, 'x'))?.dados, {'v': 1});
  });

  test('com cache e com rede: primeiro a cache, depois o servidor', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'v': 1});
    final r = await _correr(cache, () async => {'v': 2}).toList();

    expect(r.map((d) => (d.valor, d.actuais, d.desactualizados)), [(1, false, false), (2, true, false)]);
  });

  test('com cache e sem rede: mostra a cache marcada como desactualizada', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'v': 1});
    final r = await _correr(cache, () async => throw _semRede).toList();

    expect(r.last.valor, 1);
    expect(r.last.desactualizados, isTrue);
    expect(r.last.falhaAoActualizar?.erro, 'sem_ligacao');
  });

  test('sem cache e sem rede: o erro sobe', () {
    expect(_correr(CacheEmMemoria(), () async => throw _semRede).toList(), throwsA(isA<ApiException>()));
  });

  test('erro de sessão ou de negócio não se esconde atrás da cache', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'v': 1});
    const expirado = ApiException(erro: 'token_invalido', message: '', httpStatus: 401);

    expect(_correr(cache, () async => throw expirado).toList(), throwsA(isA<ApiException>()));
  });

  test('servidor em baixo (5xx) conta como falha de serviço', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'v': 1});
    const caiu = ApiException(erro: 'erro_interno', message: '', httpStatus: 502);
    final r = await _correr(cache, () async => throw caiu).toList();

    expect(r.last.desactualizados, isTrue);
  });

  test('cache em formato antigo é ignorada', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'outro': 'formato'});
    final r = await _correr(cache, () async => {'v': 3}).toList();

    expect(r.map((d) => d.valor), [3]);
  });

  test('limpar a sessão apaga dados do sócio e credenciais, não a zona pública', () async {
    final cache = CacheEmMemoria();
    await cache.guardar(Ambito.publico, 'x', {'v': 1});
    await cache.guardar(Ambito.sessao, 'x', {'v': 2});
    await cache.guardar(Ambito.seguro, 'x', {'v': 3});
    await cache.limparSessao();

    expect(await cache.ler(Ambito.publico, 'x'), isNotNull);
    expect(await cache.ler(Ambito.sessao, 'x'), isNull);
    expect(await cache.ler(Ambito.seguro, 'x'), isNull);
  });
}
