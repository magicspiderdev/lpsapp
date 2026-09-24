import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/formatos.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import 'modalidades_pedidos.dart';

/// A cor de um estado. Só cosmética: o texto é sempre o `estado_label` do
/// servidor, e um estado que não se conhece fica neutro.
StatusColor corDoEstado(PedidoModalidade p, AppColors cores) {
  if (p.aberto) return cores.warning;
  if (p.temMotivo) return cores.error;
  return switch (p.estado) {
    'aprovado' => cores.success,
    _ => cores.neutral,
  };
}

/// Pílula com o `estado_label`.
class PilulaEstadoPedido extends StatelessWidget {
  const PilulaEstadoPedido(this.pedido, {super.key});

  final PedidoModalidade pedido;

  @override
  Widget build(BuildContext context) {
    final cor = corDoEstado(pedido, AppColors.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(color: cor.container, borderRadius: BorderRadius.circular(100)),
      child: Text(pedido.estadoLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor.foreground)),
    );
  }
}

/// Caixa de aviso com ícone, nas cores de um estado.
class AvisoPedido extends StatelessWidget {
  const AvisoPedido({super.key, required this.texto, required this.cor, this.icone = Icons.info_outline_rounded});

  final String texto;
  final StatusColor cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: cor.container, borderRadius: AppRadius.smAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icone, size: 20, color: cor.foreground)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cor.foreground)),
          ),
        ],
      ),
    );
  }
}

/// O que se diz numa baixa, antes e depois de a pedir. Quem carrega no botão
/// costuma achar que deixa de pagar nesse instante.
const textoBaixaNadaFecha =
    'Pedir a baixa não fecha nada. A mensalidade continua a ser cobrada até a secretaria aprovar o '
    'pedido — é a aprovação que diz qual foi o último mês pago.';

const textoInscricaoPedido =
    'Pedir não é inscrever: a secretaria confirma a vaga e o escalão. A mensalidade só começa '
    'quando o pedido for aprovado, e é cobrada com as outras.';

/// Um pedido na lista: modalidade, quem, estado, valor e — se houver — o motivo.
class CartaoPedido extends ConsumerWidget {
  const CartaoPedido(this.pedido, {super.key, this.onTap});

  final PedidoModalidade pedido;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);
    final p = pedido;
    final valor = textoValorEstimado(p);
    final quando = p.criadoEm;

    return Bloco(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(p.modalidadeNome, style: t.textTheme.titleMedium)),
                    const SizedBox(width: AppSpacing.sm),
                    PilulaEstadoPedido(p),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [p.tipoLabel, if (p.atletaNome.isNotEmpty) p.atletaNome].join(' · '),
                  style: t.textTheme.bodyMedium,
                ),
                if (valor != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(valor, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
                if (p.baixa && p.aberto) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Continua a pagar até o pedido ser aprovado.',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (quando != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Pedido a ${dataMedia(quando)}',
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (p.motivo case final motivo? when p.temMotivo) ...[
            const SizedBox(height: AppSpacing.md),
            AvisoPedido(texto: motivo, cor: cores.error, icone: Icons.feedback_outlined),
          ],
          if (p.baixaPorResolver) BotaoSecretaria(pedido: p),
          if (p.cancelavel)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => confirmarECancelar(context, ref, p),
                child: const Text('Desistir do pedido'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Numa baixa recusada, o caminho para falar com a secretaria. O suporte é da
/// zona de sócio; sem ficha, diz-se só a quem falar.
class BotaoSecretaria extends ConsumerWidget {
  const BotaoSecretaria({super.key, required this.pedido});

  final PedidoModalidade pedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    if (ref.watch(sessaoProvider) is! SessaoSocio) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          'Para resolver, fale com a secretaria do clube.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => context.push('/socio/suporte'),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Falar com a secretaria'),
      ),
    );
  }
}

/// Desistir de um pedido, depois de confirmar. Devolve o pedido como ficou,
/// ou `null` se não se desistiu (ou se falhou — o erro vai num aviso).
Future<PedidoModalidade?> confirmarECancelar(BuildContext context, WidgetRef ref, PedidoModalidade p) async {
  final sim = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Desistir do pedido?'),
      content: Text(
        p.baixa
            ? 'O pedido de baixa de ${p.modalidadeNome} deixa de existir, e a inscrição continua como está.'
            : 'O pedido de inscrição em ${p.modalidadeNome} deixa de existir. Pode voltar a pedir mais tarde.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desistir')),
      ],
    ),
  );
  if (sim != true || !context.mounted) return null;

  final aviso = ScaffoldMessenger.of(context);
  try {
    final novo = await ref.read(accoesModalidadesProvider).cancelar(p.id);
    ref.invalidate(pedidosModalidadesProvider);
    ref.invalidate(pedidoModalidadeProvider(p.id));
    aviso.showSnackBar(const SnackBar(content: Text('Desistiu do pedido.')));
    return novo;
  } on ApiException catch (e) {
    // `estado_invalido`: alguém decidiu entretanto. A lista mostra como ficou.
    if (e.erro == 'estado_invalido' || e.erro == 'nao_encontrado') {
      ref.invalidate(pedidosModalidadesProvider);
      ref.invalidate(pedidoModalidadeProvider(p.id));
    }
    aviso.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

/// Para uma conta sem ficha de sócio e sem ninguém a cargo: pedir exige ser
/// sócio. Oferece a inscrição de sócio.
class BlocoFazerSeSocio extends StatelessWidget {
  const BlocoFazerSeSocio({super.key, this.texto});

  final String? texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Bloco(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconePastilha(Icons.badge_outlined, cor: t.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Primeiro, ser sócio', style: t.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            texto ??
                'Para inscrever alguém numa modalidade é preciso ser sócio. Faça primeiro a inscrição de '
                    'sócio; depois, é aqui que pede a modalidade.',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(onPressed: () => context.push('/inscricoes'), child: const Text('Inscrever-me como sócio')),
        ],
      ),
    );
  }
}
