import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/clientes.dart';
import '../../core/api/envelope.dart';
import '../../core/auth/sessao.dart';
import '../../core/widgets/erro_view.dart';

/// `GET /me/resumo` — o ecrã inicial do sócio numa só chamada (guia §4.3).
class Resumo {
  final String nomeCompleto, estadoLabel;
  final int nrSocio;
  final String? fotoUrl;
  final bool temModalidade;

  /// A dívida **não se soma**: é a das faturas ou a das quotas, conforme `origem`.
  final double dividaTotal;
  final int mesesPendentes;
  final int mensagensNaoLidas;

  Resumo.fromJson(Map<String, dynamic> j)
      : nomeCompleto = j['socio']['nome_completo'] as String,
        estadoLabel = j['socio']['estado_label'] as String,
        nrSocio = j['socio']['nr_socio'] as int,
        fotoUrl = j['socio']['foto_url'] as String?,
        temModalidade = j['tem_modalidade'] as bool,
        dividaTotal = (j['divida']['total'] as num).toDouble(),
        mesesPendentes = j['divida']['meses_pendentes'] as int,
        mensagensNaoLidas = j['mensagens_nao_lidas'] as int;
}

final resumoProvider = FutureProvider.autoDispose<Resumo>((ref) async {
  // Refaz quando a sessão muda (outro sócio, ou saída).
  if (ref.watch(sessaoProvider) is! SessaoSocio) throw StateError('Sem sessão de sócio');
  return Resumo.fromJson(await dadosDe(ref.read(dioSocioProvider).get('/me/resumo')));
});

class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  static final _euros = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoProvider);
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sócio'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessaoProvider.notifier).sair(),
          ),
        ],
      ),
      body: resumo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(resumoProvider)),
        data: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(resumoProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: r.fotoUrl == null ? null : NetworkImage(r.fotoUrl!),
                ),
                title: Text(r.nomeCompleto, style: tema.textTheme.titleMedium),
                subtitle: Text('Sócio n.º ${r.nrSocio} · ${r.estadoLabel}'),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.temModalidade ? 'Em dívida (faturas)' : 'Em dívida (quotas)',
                          style: tema.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(_euros.format(r.dividaTotal), style: tema.textTheme.headlineMedium),
                      if (r.mesesPendentes > 0)
                        Text(r.mesesPendentes == 1 ? '1 mês por pagar' : '${r.mesesPendentes} meses por pagar'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
