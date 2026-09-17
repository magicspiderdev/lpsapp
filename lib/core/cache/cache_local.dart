import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Onde vive uma entrada da cache.
enum Ambito {
  /// Zona pública: fica até ser substituída.
  publico,

  /// Dados do sócio: apagam-se quando a sessão acaba.
  sessao,

  /// Credenciais (ex.: o QR do cartão): armazenamento seguro, e apagam-se com a sessão.
  seguro,
}

/// Uma resposta guardada e quando foi obtida.
class EntradaCache {
  final Map<String, dynamic> dados;
  final DateTime obtidoEm;

  const EntradaCache(this.dados, this.obtidoEm);
}

/// Última resposta boa de cada pedido, para a app mostrar informação sem rede.
abstract class CacheLocal {
  Future<EntradaCache?> ler(Ambito ambito, String chave);
  Future<void> guardar(Ambito ambito, String chave, Map<String, dynamic> dados);

  /// Apaga tudo o que pertence à sessão (ambitos `sessao` e `seguro`).
  Future<void> limparSessao();
}

/// Ficheiros JSON na pasta privada da app; o âmbito `seguro` vai para o
/// Keychain/Keystore.
class CacheEmDisco implements CacheLocal {
  CacheEmDisco(this._storage);

  final FlutterSecureStorage _storage;
  Directory? _raiz;

  static const _prefixoSeguro = 'lps.cache.';

  Future<Directory> _pasta(Ambito ambito) async {
    _raiz ??= Directory('${(await getApplicationSupportDirectory()).path}/cache');
    return Directory('${_raiz!.path}/${ambito.name}');
  }

  static String _nome(String chave) => base64Url.encode(utf8.encode(chave)).replaceAll('=', '');

  @override
  Future<EntradaCache?> ler(Ambito ambito, String chave) async {
    try {
      final String? bruto;
      if (ambito == Ambito.seguro) {
        bruto = await _storage.read(key: '$_prefixoSeguro$chave');
      } else {
        final f = File('${(await _pasta(ambito)).path}/${_nome(chave)}.json');
        bruto = await f.exists() ? await f.readAsString() : null;
      }
      if (bruto == null) return null;
      final j = jsonDecode(bruto) as Map<String, dynamic>;
      return EntradaCache((j['dados'] as Map).cast<String, dynamic>(), DateTime.parse(j['obtido_em'] as String));
    } catch (_) {
      return null; // cache ilegível conta como inexistente
    }
  }

  @override
  Future<void> guardar(Ambito ambito, String chave, Map<String, dynamic> dados) async {
    final bruto = jsonEncode({'obtido_em': DateTime.now().toIso8601String(), 'dados': dados});
    try {
      if (ambito == Ambito.seguro) {
        await _storage.write(key: '$_prefixoSeguro$chave', value: bruto);
      } else {
        final pasta = await _pasta(ambito);
        await pasta.create(recursive: true);
        // Escreve ao lado e renomeia: um crash a meio não deixa JSON cortado.
        final tmp = File('${pasta.path}/${_nome(chave)}.tmp');
        await tmp.writeAsString(bruto, flush: true);
        await tmp.rename('${pasta.path}/${_nome(chave)}.json');
      }
    } catch (_) {
      // Sem espaço ou sem permissões: a app continua, só não fica guardado.
    }
  }

  @override
  Future<void> limparSessao() async {
    try {
      final pasta = await _pasta(Ambito.sessao);
      if (await pasta.exists()) await pasta.delete(recursive: true);
    } catch (_) {}
    try {
      final chaves = (await _storage.readAll()).keys.where((k) => k.startsWith(_prefixoSeguro));
      for (final k in chaves) {
        await _storage.delete(key: k);
      }
    } catch (_) {}
  }
}

/// Em memória, para testes.
class CacheEmMemoria implements CacheLocal {
  final _dados = <String, EntradaCache>{};

  @override
  Future<EntradaCache?> ler(Ambito ambito, String chave) async => _dados['${ambito.name}/$chave'];

  @override
  Future<void> guardar(Ambito ambito, String chave, Map<String, dynamic> dados) async =>
      _dados['${ambito.name}/$chave'] = EntradaCache(dados, DateTime.now());

  @override
  Future<void> limparSessao() async => _dados.removeWhere((k, _) => !k.startsWith('${Ambito.publico.name}/'));
}

/// Preenchido em `main()`.
final cacheProvider = Provider<CacheLocal>(
  (ref) => throw UnimplementedError('cacheProvider tem de ser sobreposto em main()'),
);
