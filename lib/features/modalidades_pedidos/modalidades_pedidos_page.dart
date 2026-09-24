import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/sessao.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import 'modalidades_pedidos.dart';
import 'modalidades_widgets.dart';

/// "Modalidades": os pedidos de inscrição e de baixa desta conta — do próprio
/// e dos que tem a cargo — e o botão para pedir outro (guia §4.22).
///
/// O estado do pedido é a verdade (o push da decisão pode não ter chegado),
/// por isso a lista recarrega sempre que o ecrã abre.
class ModalidadesPedidosPage extends ConsumerWidget {
  const ModalidadesPedidosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(pedidosModalidadesProvider);
    final sessao = ref.watch(sessaoProvider);
    final podeContratar = sessaoTem(sessao, Capacidade.contratar);
    final atletas = lista.valueOrNull?.valor.atletas;
    // O botão só aparece quando há por quem pedir e a conta o pode fazer.
    final mostrarPedir = podeContratar && (atletas?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Modalidades')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pedidosModalidadesProvider.future),
        child: lista.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(pedidosModalidadesProvider)),
          data: (d) {
            final v = d.valor;
            final pedidos = v.ordenados;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
              children: [
                AvisoDesactualizado(d),
                Text(
                  'Peça aqui a inscrição numa modalidade, ou a baixa, para si ou para quem tem a cargo. '
                  'Quem decide é a secretaria; recebe a resposta por email e por notificação.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!podeContratar)
                  NotaPermissao(explicacaoPermissao('contratar'), padding: const EdgeInsets.only(bottom: AppSpacing.md))
                else if (v.atletas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: BlocoFazerSeSocio(),
                  ),
                const TituloSeccao('Os meus pedidos'),
                if (pedidos.isEmpty)
                  const _Vazio()
                else
                  for (final p in pedidos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: CartaoPedido(p, onTap: () => context.push(RotasModalidades.pedido(p.id), extra: p)),
                    ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: mostrarPedir
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () => context.push(RotasModalidades.pedir),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Pedir inscrição ou baixa'),
              ),
            )
          : null,
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Bloco(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          ExcludeSemantics(child: Icon(Icons.sports_rounded, size: 32, color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Text('Ainda não fez nenhum pedido.', style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
