import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/clientes.dart';
import '../../core/api/envelope.dart';
import '../../core/cache/cache_local.dart';
import '../../core/cache/com_cache.dart';
import '../../core/config.dart';
import '../../core/rede/ligacao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/imagem_rede.dart';
import 'arena.dart';

/// Um avatar da Comunidade: um leão ou uma leoa da lista que o clube gere no
/// backoffice (§4.23, `GET /api/v2/publico/comunidade/avatares`).
///
/// O perfil e a classificação trazem só o `codigo`; o nome e a imagem vêm
/// daqui. Escolher de uma lista, e não carregar uma fotografia, é o que mantém
/// a Comunidade sem conteúdo livre (ADR-13) e sem caras de menores.
class AvatarComunidade {
  final String codigo, nome, grupo, url;

  const AvatarComunidade({required this.codigo, required this.nome, required this.grupo, required this.url});

  /// Pela ordem da grelha. Um avatar sem imagem não se consegue mostrar:
  /// ignora-se, como qualquer entrada que a app não saiba ler.
  static List<AvatarComunidade> listaDe(Map<String, dynamic> d) => [
    for (final a in (d['avatares'] as List?) ?? const [])
      if (a is Map && a['codigo'] is String && a['url'] is String)
        AvatarComunidade(
          codigo: a['codigo'] as String,
          nome: (a['nome'] as String?) ?? '',
          grupo: (a['grupo'] as String?) ?? '',
          url: a['url'] as String,
        ),
  ];

  /// O título da secção de um `grupo` (lista aberta: um que a app não conheça
  /// mostra-se com o próprio nome).
  static String tituloDoGrupo(String grupo) => switch (grupo) {
    'leoes' => 'Leões',
    'leoas' => 'Leoas',
    '' => 'Outros',
    _ => grupo[0].toUpperCase() + grupo.substring(1),
  };
}

/// A lista dos avatares. Pública e em cache (o servidor dá uma hora): a
/// classificação resolve cada código por ela, sem um pedido por linha.
final avataresProvider = StreamProvider.autoDispose<Dados<List<AvatarComunidade>>>((ref) {
  if (modoDemonstracao) return Stream.value(Dados(const <AvatarComunidade>[], DateTime.now()));
  ref.watch(ligacaoProvider);
  final dio = ref.read(dioPublicoProvider);
  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.publico,
    chave: 'comunidade.avatares',
    pedido: () => dadosDe(dio.get('/comunidade/avatares')),
    ler: AvatarComunidade.listaDe,
  );
});

/// O avatar de alguém, pelo código. Sem avatar — ou com um código que não
/// esteja na lista (o clube retirou-o, ou a lista ainda não chegou) —, o
/// brasão.
class ImagemAvatar extends ConsumerWidget {
  const ImagemAvatar(this.codigo, {super.key, this.tamanho = 40, this.aro});

  final String? codigo;
  final double tamanho;

  /// O aro: o metal no pódio, o ouro do escolhido. Sem ele, a linha discreta.
  final Color? aro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = codigo == null
        ? const <AvatarComunidade>[]
        : ref.watch(avataresProvider).valueOrNull?.valor ?? const <AvatarComunidade>[];
    AvatarComunidade? avatar;
    for (final a in lista) {
      if (a.codigo == codigo) avatar = a;
    }
    return MolduraAvatar(avatar, tamanho: tamanho, aro: aro);
  }
}

/// O desenho de um avatar já resolvido: a imagem cortada em chanfro, com o
/// aro. `null` é o brasão ("sem avatar").
class MolduraAvatar extends StatelessWidget {
  const MolduraAvatar(this.avatar, {super.key, this.tamanho = 40, this.aro});

  final AvatarComunidade? avatar;
  final double tamanho;
  final Color? aro;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final raio = tamanho / 4;
    final avatar = this.avatar;

    Widget brasao() => Padding(
      padding: EdgeInsets.all(tamanho * 0.16),
      child: Opacity(
        opacity: 0.55,
        child: Image.asset('assets/images/brasao.png', fit: BoxFit.contain, excludeFromSemantics: true),
      ),
    );

    return Semantics(
      image: true,
      label: avatar == null ? 'Sem avatar' : 'Avatar: ${avatar.nome}',
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: ShapeDecoration(
          color: AppPalette.arenaPainelAlto,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(raio)),
            side: BorderSide(color: aro ?? c.outline, width: tamanho >= 48 ? 2 : 1.5),
          ),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: BeveledRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(raio))),
          ),
          child: avatar == null
              ? brasao()
              : ImagemRede(
                  avatar.url,
                  fit: BoxFit.cover,
                  // A imagem é 512×512 e aparece, no máximo, a 96 pontos.
                  larguraCache: (tamanho * MediaQuery.devicePixelRatioOf(context)).round(),
                  falha: (_) => brasao(),
                ),
        ),
      ),
    );
  }
}

/// A grelha para escolher o avatar. Devolve o código escolhido, ou nada se a
/// folha fechar sem escolha.
Future<String?> escolherAvatar(BuildContext context, {String? actual}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // Alta, com todos: sem isto a pega ia parar ao lado do relógio.
    useSafeArea: true,
    builder: (_) => _FolhaAvatares(actual: actual),
  );
}

class _FolhaAvatares extends ConsumerWidget {
  const _FolhaAvatares({required this.actual});

  final String? actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final estado = ref.watch(avataresProvider);
    final lista = estado.valueOrNull?.valor ?? const <AvatarComunidade>[];

    // Os grupos pela ordem em que aparecem na lista.
    final grupos = <String>[];
    for (final a in lista) {
      if (!grupos.contains(a.grupo)) grupos.add(a.grupo);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('O seu avatar', style: t.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Aparece ao lado da sua alcunha, na classificação e no seu cartão.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: estado.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Text(
                          estado.hasError && estado.valueOrNull == null
                              ? 'Não foi possível carregar os avatares. Tente de novo com rede.'
                              : 'Ainda não há avatares para escolher. O clube está a prepará-los.',
                          textAlign: TextAlign.center,
                          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                ),
              for (final grupo in grupos) ...[
                if (grupos.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                    child: Text(AvatarComunidade.tituloDoGrupo(grupo), style: t.textTheme.titleMedium),
                  )
                else
                  const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, limites) {
                    // Os cinco numa linha quando cabem; num telemóvel, 3 + 2.
                    final colunas = limites.maxWidth >= 480 ? 5 : 3;
                    final largura = (limites.maxWidth - 10 * (colunas - 1)) / colunas;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 14,
                      children: [
                        for (final a in lista)
                          if (a.grupo == grupo)
                            SizedBox(
                              width: largura,
                              child: _Opcao(
                                a,
                                escolhido: a.codigo == actual,
                                onTap: () => Navigator.pop(context, a.codigo),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao(this.a, {required this.escolhido, required this.onTap});

  final AvatarComunidade a;
  final bool escolhido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      selected: escolhido,
      child: InkWell(
        onTap: onTap,
        customBorder: chanfro,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (_, l) =>
                    MolduraAvatar(a, tamanho: l.maxWidth.clamp(48, 96), aro: escolhido ? AppPalette.ouro : null),
              ),
              const SizedBox(height: 6),
              Text(
                a.nome,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.labelMedium?.copyWith(color: escolhido ? AppPalette.ouro : t.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
