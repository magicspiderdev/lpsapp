import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/sessao.dart';
import '../../core/cache/com_cache.dart';
import '../../core/formatos.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import 'inscricao.dart';
import 'inscricao_page.dart' show EtiquetaEstadoInscricao;

/// As minhas inscrições de sócio (`GET /me/inscricoes`), cada uma com o seu
/// estado. Tocar abre a inscrição no passo em que está.
///
/// Sem nenhuma, o ecrã é o convite para começar. O botão de começar só
/// aparece a quem pode contratar (§2.12); a quem não pode diz-se quem o faz.
class InscricoesPage extends ConsumerWidget {
  const InscricoesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final lista = ref.watch(minhasInscricoesProvider);
    final podeContratar = sessaoTem(ref.watch(sessaoProvider), Capacidade.contratar);

    return Scaffold(
      appBar: AppBar(title: const Text('As minhas inscrições')),
      body: switch (lista) {
        AsyncValue(:final Dados<List<InscricaoSocio>> value) => RefreshIndicator(
          onRefresh: () => ref.refresh(minhasInscricoesProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
            children: [
              AvisoDesactualizado(value),
              if (value.valor.isEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.how_to_reg_rounded, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text('Ainda não é sócio?', textAlign: TextAlign.center, style: t.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Faça aqui o pedido — para si ou para um menor a seu cargo. O clube responde por email, '
                  'e depois assina e paga as primeiras quotas na app.',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ] else
                Bloco(child: Column(children: [for (final i in value.valor) _LinhaInscricao(i)])),
              const SizedBox(height: AppSpacing.xl),
              if (podeContratar)
                FilledButton.icon(
                  onPressed: () => context.push('/inscricoes/nova'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(value.valor.isEmpty ? 'Tornar-me sócio' : 'Nova inscrição'),
                )
              else
                NotaPermissao(explicacaoPermissao('contratar'), padding: EdgeInsets.zero),
            ],
          ),
        ),
        AsyncValue(:final Object error) => ErroView(
          erro: error,
          tentarDeNovo: () => ref.invalidate(minhasInscricoesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LinhaInscricao extends StatelessWidget {
  const _LinhaInscricao(this.i);

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final detalhe = [
      if (i.nrSocio != null) 'N.º ${i.nrSocio}',
      if (i.paraDependente) 'a seu cargo',
      if (i.criadoEm != null) 'pedido a ${dataCurta(i.criadoEm!)}',
    ].join(' · ');

    return ListTile(
      onTap: () => context.push('/inscricoes/${i.id}'),
      leading: IconePastilha(i.paraDependente ? Icons.family_restroom_rounded : Icons.person_rounded),
      title: Text(i.nome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          EtiquetaEstadoInscricao(i),
          if (detalhe.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detalhe, style: t.textTheme.bodySmall),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
