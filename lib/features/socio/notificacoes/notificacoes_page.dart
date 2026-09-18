import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'notificacoes.dart';

/// Histórico do push (guia §4.16). O push pode não ter chegado — é aqui que o
/// sócio vê o que o clube enviou.
class NotificacoesPage extends ConsumerStatefulWidget {
  const NotificacoesPage({super.key});

  @override
  ConsumerState<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends ConsumerState<NotificacoesPage> {
  /// Quais estavam por ver quando o ecrã abriu: marcam-se como vistas já, mas o
  /// ponto continua visível enquanto o sócio está a olhar para elas.
  Set<int>? _novasAoAbrir;

  @override
  Widget build(BuildContext context) {
    final lista = ref.watch(notificacoesProvider);
    final mais = ref.watch(maisNotificacoesProvider);

    // A primeira página chega depois do ecrã: marca-se quando chegar.
    final primeira = lista.valueOrNull?.valor;
    if (_novasAoAbrir == null && primeira != null) {
      final vistas = ref.watch(vistasProvider).valueOrNull;
      if (vistas != null) {
        _novasAoAbrir = {
          for (final n in primeira.notificacoes)
            if (n.id > vistas) n.id,
        };
        final maior = primeira.maiorId;
        if (maior > vistas) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(vistasProvider.notifier).marcarVistas(maior),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificacoesProvider.future),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (primeira != null && n.metrics.extentAfter < 400) {
              ref.read(maisNotificacoesProvider.notifier).carregar(primeira.antesDe);
            }
            return false;
          },
          child: lista.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(notificacoesProvider)),
            data: (d) {
              final todas = [...d.valor.notificacoes, ...mais.notificacoes];
              final haMais = mais.temMais(d.valor.antesDe) && !d.desactualizados;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
                children: [
                  AvisoDesactualizado(d),
                  const _PedirPermissao(),
                  if (todas.isEmpty)
                    const _Vazio()
                  else
                    for (final n in todas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Cartao(n, nova: _novasAoAbrir?.contains(n.id) ?? false),
                      ),
                  if (haMais)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// O push está disponível mas o aparelho ainda não deixa mostrar avisos.
///
/// Pede-se aqui, e não ao entrar: neste ecrã já se percebe para que serve, e o
/// ecrã inicial já oferece a biometria — duas caixas do sistema seguidas é de
/// mais.
class _PedirPermissao extends ConsumerWidget {
  const _PedirPermissao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushProvider);
    if (!push.disponivel || push.autorizado) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Bloco(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconePastilha(Icons.notifications_active_outlined, cor: c.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Receba os avisos do clube no telemóvel, mesmo com a app fechada.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref.read(pushProvider.notifier).pedirPermissao(),
                child: const Text('Activar notificações'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.notifications_none_rounded, size: 56, color: c.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Ainda não recebeu notificações', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'É aqui que fica tudo o que o clube enviar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao(this.n, {required this.nova});

  final Notificacao n;
  final bool nova;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;

    return Bloco(
      onTap: () => _abrir(context, n),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Icone(n, nova: nova),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: nova ? FontWeight.w700 : FontWeight.w600),
                ),
                if (n.texto.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (n.enviadaEm != null)
                      Text(
                        quandoFoiObtido(n.enviadaEm!),
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    if (n.pessoal) ...[
                      if (n.enviadaEm != null)
                        Text(' · ', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                      Text(
                        'só para si',
                        style: t.bodySmall?.copyWith(color: c.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura da imagem enviada; sem imagem, um sino (ou uma pessoa, se for só
/// para este sócio). Com um ponto quando ainda não tinha sido vista.
class _Icone extends StatelessWidget {
  const _Icone(this.n, {required this.nova});

  final Notificacao n;
  final bool nova;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final icone = n.pessoal ? Icons.person_outline_rounded : Icons.notifications_none_rounded;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (n.imagemUrl == null)
          IconePastilha(icone, cor: n.pessoal ? c.primary : c.onSurfaceVariant)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              color: c.surfaceContainerHighest,
              child: ImagemRede(
                n.imagemUrl!,
                largura: 44,
                altura: 44,
                falha: (_) => Icon(icone, size: 20, color: c.onSurfaceVariant),
              ),
            ),
          ),
        if (nova)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: Tema.alerta,
                shape: BoxShape.circle,
                border: Border.all(color: c.surfaceContainerLowest, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// O texto completo: no cartão vão só duas linhas, e o push costuma ter mais.
void _abrir(BuildContext context, Notificacao n) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (sheet) {
      final t = Theme.of(sheet).textTheme;
      final c = Theme.of(sheet).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (n.imagemUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Tema.raioPequeno),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: c.surfaceContainerHighest,
                          child: ImagemRede(n.imagemUrl!),
                        ),
                      ),
                    ),
                  ),
                Text(n.titulo, style: t.titleLarge),
                const SizedBox(height: 6),
                Text(
                  [
                    if (n.enviadaEm != null) quandoFoiObtido(n.enviadaEm!),
                    if (n.pessoal) 'só para si',
                  ].join(' · '),
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
                if (n.texto.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // Texto simples, com as quebras de linha que vieram do servidor.
                  Text(n.texto, style: t.bodyLarge),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}
