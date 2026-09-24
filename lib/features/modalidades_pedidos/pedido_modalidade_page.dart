import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatos.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import 'modalidades_pedidos.dart';
import 'modalidades_widgets.dart';

/// Um pedido de modalidade. Abre com o que a lista (ou o `409 ja_existe`)
/// já trouxe, para não abrir a girar, e actualiza a seguir.
class PedidoModalidadePage extends ConsumerWidget {
  const PedidoModalidadePage({super.key, required this.id, this.inicial});

  final String id;
  final PedidoModalidade? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(pedidoModalidadeProvider(id));
    final pedido = estado.valueOrNull?.valor ?? inicial;

    return Scaffold(
      appBar: AppBar(title: Text(pedido?.modalidadeNome ?? 'Pedido')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pedidoModalidadeProvider(id).future),
        child: switch ((pedido, estado)) {
          (null, AsyncError(:final error)) => ErroView(
            erro: error,
            tentarDeNovo: () => ref.invalidate(pedidoModalidadeProvider(id)),
          ),
          (null, _) => const Center(child: CircularProgressIndicator()),
          (final PedidoModalidade p, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
            children: [if (estado.valueOrNull case final d?) AvisoDesactualizado(d), _Detalhe(p)],
          ),
        },
      ),
    );
  }
}

class _Detalhe extends ConsumerWidget {
  const _Detalhe(this.p);

  final PedidoModalidade p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);
    final valor = textoValorEstimado(p);

    Widget linha(String rotulo, String valor) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(valor, style: t.textTheme.bodyMedium),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bloco(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(p.tipoLabel, style: t.textTheme.titleMedium)),
                  PilulaEstadoPedido(p),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              linha('Modalidade', p.modalidadeNome),
              if (p.atletaNome.isNotEmpty)
                linha('Atleta', [p.atletaNome, if (p.atletaNrSocio case final n?) 'sócio n.º $n'].join(' · ')),
              if (valor != null) linha('Mensalidade', valor),
              if (p.criadoEm case final d?) linha('Pedido a', dataMedia(d)),
              if (p.decididoEm case final d?) linha('Decidido a', dataMedia(d)),
              if (p.observacoes case final o?) linha('Observações', o),
            ],
          ),
        ),
        if (p.baixa && p.aberto) ...[
          const SizedBox(height: AppSpacing.md),
          AvisoPedido(texto: textoBaixaNadaFecha, cor: cores.warning, icone: Icons.schedule_rounded),
        ] else if (p.aberto) ...[
          const SizedBox(height: AppSpacing.md),
          AvisoPedido(
            texto: 'A secretaria vai ver o pedido. Recebe a resposta por email e por notificação.',
            cor: cores.info,
          ),
        ],
        if (p.motivo case final motivo? when p.temMotivo) ...[
          const TituloSeccao('Porque não foi aceite'),
          AvisoPedido(texto: motivo, cor: cores.error, icone: Icons.feedback_outlined),
        ],
        if (p.baixaPorResolver) BotaoSecretaria(pedido: p),
        if (p.cancelavel) ...[
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(onPressed: () => confirmarECancelar(context, ref, p), child: const Text('Desistir do pedido')),
        ],
      ],
    );
  }
}
