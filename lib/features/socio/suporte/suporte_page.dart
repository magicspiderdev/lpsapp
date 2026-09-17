import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'suporte.dart';

/// "hoje" → 14:32, esta semana → "seg.", antes → 12/08.
String horaCurta(DateTime? d) {
  if (d == null) return '';
  final agora = DateTime.now();
  final hoje = DateUtils.dateOnly(agora);
  final dia = DateUtils.dateOnly(d);
  if (dia == hoje) return DateFormat('HH:mm').format(d);
  if (hoje.difference(dia).inDays < 7) return DateFormat('EEE', 'pt_PT').format(d);
  return DateFormat('dd/MM').format(d);
}

class SuportePage extends ConsumerWidget {
  const SuportePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(conversasProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Secretaria')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/socio/suporte/nova'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Nova conversa'),
      ),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(conversasProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(conversasProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 100),
            children: [
              AvisoDesactualizado(d),
              if (d.valor.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Column(
                    children: [
                      const IconePastilha(Icons.support_agent_rounded),
                      const SizedBox(height: 16),
                      Text('Fale com a secretaria', style: t.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Dúvidas sobre quotas, pagamentos ou inscrições.\nA resposta aparece aqui.',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                Bloco(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, c) in d.valor.indexed) ...[
                        if (i > 0) const Divider(indent: 72),
                        _LinhaConversa(c),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaConversa extends StatelessWidget {
  const _LinhaConversa(this.c);

  final Conversa c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final novas = c.naoLidas > 0;

    return ListTile(
      onTap: () => context.push('/socio/suporte/${c.id}'),
      leading: IconePastilha(
        c.fechada ? Icons.check_rounded : Icons.forum_outlined,
        cor: c.fechada ? t.colorScheme.onSurfaceVariant : null,
      ),
      title: Text(
        c.ultimaMensagem.isEmpty ? 'Anexo' : c.ultimaMensagem,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: novas ? t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text([if (c.ultimaDoClube) 'Secretaria' else 'Você', if (c.fechada) 'fechada'].join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(horaCurta(c.ultimaEm), style: t.textTheme.bodySmall),
          if (novas) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: t.colorScheme.primary, borderRadius: BorderRadius.circular(100)),
              child: Text(
                '${c.naoLidas}',
                style: TextStyle(color: t.colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
