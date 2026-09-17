import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/clientes.dart';
import '../../../core/api/envelope.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/cache_local.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/formatos.dart';
import '../../../core/rede/ligacao.dart';

/// A ficha do sócio da sessão (`GET /me`, guia §4.2).
///
/// É sempre a do próprio: `PUT /me` e `POST /me/foto` não aceitam `X-Socio`.
class Perfil {
  final int nrSocio;
  final String nomeCompleto, estadoLabel;
  final String? email, telefone1, telefone2, endereco, cp1, cp2, localidade, pais, nif, fotoUrl, modalidade;
  final DateTime? dataNascimento, dataSocio;
  final bool recebeNewsletter;

  const Perfil({
    required this.nrSocio,
    required this.nomeCompleto,
    required this.estadoLabel,
    required this.recebeNewsletter,
    this.email,
    this.telefone1,
    this.telefone2,
    this.endereco,
    this.cp1,
    this.cp2,
    this.localidade,
    this.pais,
    this.nif,
    this.fotoUrl,
    this.modalidade,
    this.dataNascimento,
    this.dataSocio,
  });

  factory Perfil.fromJson(Map<String, dynamic> s) => Perfil(
    nrSocio: s['nr_socio'] as int,
    nomeCompleto: (s['nome_completo'] ?? '') as String,
    estadoLabel: (s['estado_label'] ?? '') as String,
    recebeNewsletter: s['recebe_newsletter'] == true,
    email: s['email'] as String?,
    telefone1: s['telefone_1'] as String?,
    telefone2: s['telefone_2'] as String?,
    endereco: s['endereco'] as String?,
    cp1: s['cp_1'] as String?,
    cp2: s['cp_2'] as String?,
    localidade: s['localidade'] as String?,
    pais: s['pais'] as String?,
    nif: s['nif'] as String?,
    fotoUrl: s['foto_url'] as String?,
    modalidade: s['modalidade'] as String?,
    dataNascimento: dataApi(s['data_nascimento']),
    dataSocio: dataApi(s['data_socio']),
  );
}

/// Só estes campos são aceites por `PUT /me`; o resto é da secretaria (guia §6).
const camposEditaveis = [
  'email',
  'telefone_1',
  'telefone_2',
  'endereco',
  'cp_1',
  'cp_2',
  'localidade',
  'pais',
  'recebe_newsletter',
];

final perfilProvider = StreamProvider.autoDispose<Dados<Perfil>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioSocioProvider);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'perfil.${sessao.socio.nrSocio}',
    pedido: () => dadosDe(dio.get('/me')),
    ler: (j) => Perfil.fromJson((j['socio'] as Map).cast<String, dynamic>()),
  );
});

/// Resultado de guardar: a ficha como ficou e os campos que o servidor gravou.
typedef Gravado = ({Perfil perfil, List<String> atualizado});

Future<Gravado> guardarPerfil(Dio dio, Map<String, Object?> alteracoes) async {
  final data = await dadosDe(
    dio.put(
      '/me',
      data: {
        for (final e in alteracoes.entries)
          if (camposEditaveis.contains(e.key)) e.key: e.value,
      },
    ),
  );
  return (
    perfil: Perfil.fromJson((data['socio'] as Map).cast<String, dynamic>()),
    atualizado: [for (final c in (data['atualizado'] as List?) ?? const []) c.toString()],
  );
}

/// `POST /me/foto` (multipart, campo `foto`). Devolve o novo `foto_url`.
Future<String?> enviarFoto(Dio dio, String caminho, {String? nome}) async {
  final data = await dadosDe(
    dio.post('/me/foto', data: FormData.fromMap({'foto': await MultipartFile.fromFile(caminho, filename: nome)})),
  );
  return data['foto_url'] as String?;
}
