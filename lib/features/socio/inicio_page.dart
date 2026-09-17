import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/biometria.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/cache_local.dart';
import '../../core/cache/com_cache.dart';
import '../../core/rede/ligacao.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import 'cartao/cartao_page.dart';
import 'conta/contas.dart';
import 'conta/seletor_conta.dart';

/// `GET /me/resumo` — o ecrã inicial do sócio numa só chamada (guia §4.3).
class Resumo {
  final String nomeCompleto, estadoLabel;
  final int nrSocio, estado;
  final String? fotoUrl;
  final DateTime? dataSocio, ultimaQuota;
  final bool temModalidade;

  /// A dívida **não se soma**: é a das faturas ou a das quotas, conforme `origem`.
  final double dividaTotal;
  final int mesesPendentes;
  final int mensagensNaoLidas;

  Resumo.fromJson(Map<String, dynamic> j)
    : nomeCompleto = j['socio']['nome_completo'] as String,
      estadoLabel = j['socio']['estado_label'] as String,
      estado = j['socio']['estado'] as int,
      nrSocio = j['socio']['nr_socio'] as int,
      fotoUrl = j['socio']['foto_url'] as String?,
      dataSocio = _data(j['socio']['data_socio']),
      ultimaQuota = _data(j['ultima_quota']),
      temModalidade = j['tem_modalidade'] as bool,
      dividaTotal = (j['divida']['total'] as num).toDouble(),
      mesesPendentes = j['divida']['meses_pendentes'] as int,
      mensagensNaoLidas = j['mensagens_nao_lidas'] as int;

  bool get ativo => estado == 1;

  /// Primeiro nome, para o cumprimento.
  String get primeiroNome {
    final p = nomeCompleto.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1);
  }

  static DateTime? _data(dynamic v) => (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;
}

final resumoProvider = StreamProvider.autoDispose<Dados<Resumo>>((ref) {
  final sessao = ref.watch(sessaoProvider);
  if (sessao is! SessaoSocio) throw StateError('Sem sessão de sócio');
  ref.watch(ligacaoProvider); // quando a ligação volta, actualiza
  final conta = PedidosNaConta(ref);

  return comCache(
    cache: ref.read(cacheProvider),
    ambito: Ambito.sessao,
    chave: 'resumo.${sessao.socio.nrSocio}.${conta.chave}',
    pedido: () => conta.get('/me/resumo'),
    ler: Resumo.fromJson,
  );
});

final _euros = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoProvider);

    // Acabou de entrar com palavra-passe e o aparelho tem biometria: oferecer uma vez.
    final tipo = ref.watch(tipoBiometriaProvider).valueOrNull;
    if (tipo != null && ref.watch(biometriaProvider.select((b) => b.oferecer))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _oferecerBiometria(context, ref, tipo);
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: resumo.when(
          skipLoadingOnReload: true,
          loading: () => const _Carregar(),
          error: (e, _) => SafeArea(
            child: ErroView(erro: e, tentarDeNovo: () => ref.invalidate(resumoProvider)),
          ),
          data: (d) => RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () => ref.refresh(resumoProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Topo(d.valor)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
                  sliver: SliverList.list(
                    children: [
                      AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 16)),
                      const TituloSeccao('Cartão de sócio'),
                      CartaoVisual(
                        nome: d.valor.nomeCompleto,
                        nrSocio: d.valor.nrSocio,
                        estadoLabel: d.valor.estadoLabel,
                        valido: d.valor.ativo,
                        dataSocio: d.valor.dataSocio,
                        onTap: () => context.go('/socio/cartao'),
                      ),
                      TituloSeccao(
                        ref.watch(contaActivaProvider) == null ? 'A sua conta' : 'Conta de ${d.valor.primeiroNome}',
                      ),
                      _Conta(d.valor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho com o gradiente do clube: cumprimento, valor em dívida e acções.
class _Topo extends ConsumerWidget {
  const _Topo(this.r);

  final Resumo r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final emDia = r.dividaTotal <= 0;
    final temDependentes = (ref.watch(dependentesProvider).valueOrNull?.valor ?? const []).isNotEmpty;
    final aVerDependente = ref.watch(contaActivaProvider) != null;
    final dependente = ref.watch(dependenteActivoProvider);
    // Dependente "só consulta": sem botão de pagar (guia §2.3.4).
    final podePagar = dependente?.podePagar ?? true;

    return Container(
      decoration: const BoxDecoration(
        gradient: Tema.gradienteClube,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(Tema.margem, MediaQuery.paddingOf(context).top + 8, Tema.margem, 24),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _perfil(context, ref),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Avatar(nome: r.nomeCompleto, url: r.fotoUrl, tamanho: 38),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Com sócios a seu cargo, o nome abre o seletor de conta.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: temDependentes ? () => mostrarSeletorConta(context) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              aVerDependente ? r.primeiroNome : 'Olá, ${r.primeiroNome}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(color: Colors.white),
                            ),
                          ),
                          if (temDependentes) ...[
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                          ],
                        ],
                      ),
                      Text(
                        aVerDependente ? 'Conta a seu cargo · N.º ${r.nrSocio}' : 'Sócio n.º ${r.nrSocio}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                      ),
                    ],
                  ),
                ),
              ),
              _BotaoVidro(
                icone: Icons.chat_bubble_outline_rounded,
                marca: r.mensagensNaoLidas > 0,
                onTap: () => _emBreve(context),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            emDia ? 'Tudo em dia' : 'Em dívida',
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              _euros.format(r.dividaTotal),
              style: t.displaySmall?.copyWith(color: Colors.white, fontSize: 44),
            ),
          ),
          const SizedBox(height: 8),
          _Pastilha(
            emDia
                ? (r.temModalidade ? 'Faturas pagas' : 'Quotas pagas')
                : '${r.mesesPendentes} ${r.mesesPendentes == 1 ? 'mês' : 'meses'} por pagar',
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (podePagar)
                AccaoRedonda(
                  icone: Icons.add_rounded,
                  legenda: 'Pagar',
                  sobreEscuro: true,
                  onTap: () => _emBreve(context),
                ),
              AccaoRedonda(
                icone: Icons.qr_code_2_rounded,
                legenda: 'Cartão',
                sobreEscuro: true,
                onTap: () => context.go('/socio/cartao'),
              ),
              AccaoRedonda(
                icone: r.temModalidade ? Icons.receipt_long_rounded : Icons.calendar_month_rounded,
                legenda: r.temModalidade ? 'Faturas' : 'Quotas',
                sobreEscuro: true,
                onTap: () => _emBreve(context),
              ),
              AccaoRedonda(
                icone: Icons.more_horiz_rounded,
                legenda: 'Mais',
                sobreEscuro: true,
                onTap: () => _perfil(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotaoVidro extends StatelessWidget {
  const _BotaoVidro({required this.icone, required this.onTap, this.marca = false});

  final IconData icone;
  final VoidCallback onTap;
  final bool marca;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(dimension: 40, child: Icon(icone, color: Colors.white, size: 20)),
          ),
        ),
        if (marca)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Tema.alerta,
                shape: BoxShape.circle,
                border: Border.all(color: Tema.verde, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pastilha extends StatelessWidget {
  const _Pastilha(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(100)),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Conta extends StatelessWidget {
  const _Conta(this.r);

  final Resumo r;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final mes = DateFormat('MMMM y', 'pt_PT');

    return Bloco(
      child: Column(
        children: [
          ListTile(
            leading: const IconePastilha(Icons.event_available_rounded),
            title: const Text('Última quota paga'),
            subtitle: Text(r.ultimaQuota == null ? 'Sem registo' : _capital(mes.format(r.ultimaQuota!))),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _emBreve(context),
          ),
          const Divider(indent: 72),
          ListTile(
            leading: const IconePastilha(Icons.history_rounded),
            title: const Text('Pagamentos'),
            subtitle: const Text('Histórico e referências'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _emBreve(context),
          ),
          const Divider(indent: 72),
          ListTile(
            leading: IconePastilha(Icons.support_agent_rounded, cor: c.onSurfaceVariant),
            title: const Text('Falar com a secretaria'),
            subtitle: Text(
              r.mensagensNaoLidas > 0
                  ? '${r.mensagensNaoLidas} ${r.mensagensNaoLidas == 1 ? 'mensagem nova' : 'mensagens novas'}'
                  : 'Suporte',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _emBreve(context),
          ),
        ],
      ),
    );
  }

  static String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Carregar extends StatelessWidget {
  const _Carregar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 360 + MediaQuery.paddingOf(context).top,
          decoration: const BoxDecoration(
            gradient: Tema.gradienteClube,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ],
    );
  }
}

void _emBreve(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Disponível em breve.')));
}

/// Folha do perfil: é sempre a conta da sessão, mesmo a ver a de um dependente.
void _perfil(BuildContext context, WidgetRef ref) {
  final sessao = ref.read(sessaoProvider);
  if (sessao is! SessaoSocio) return;
  final s = sessao.socio;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(nome: s.nomeCompleto, url: s.fotoUrl, tamanho: 72),
            const SizedBox(height: 12),
            Text(s.nomeCompleto, textAlign: TextAlign.center, style: Theme.of(sheet).textTheme.titleLarge),
            Text('Sócio n.º ${s.nrSocio}', style: Theme.of(sheet).textTheme.bodySmall),
            const SizedBox(height: 24),
            Consumer(
              builder: (context, ref, _) {
                final tipo = ref.watch(tipoBiometriaProvider).valueOrNull;
                if (tipo == null) return const SizedBox.shrink();
                return SwitchListTile(
                  secondary: IconePastilha(
                    tipo == TipoBiometria.facial ? Icons.face_retouching_natural : Icons.fingerprint_rounded,
                  ),
                  title: Text('Entrar com ${tipo.nome}'),
                  value: ref.watch(biometriaProvider.select((b) => b.activa)),
                  onChanged: (v) => ref.read(biometriaProvider.notifier).definir(v),
                );
              },
            ),
            ListTile(
              leading: IconePastilha(Icons.logout_rounded, cor: Theme.of(sheet).colorScheme.error),
              title: const Text('Terminar sessão'),
              onTap: () {
                Navigator.pop(sheet);
                ref.read(sessaoProvider.notifier).sair();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _oferecerBiometria(BuildContext context, WidgetRef ref, TipoBiometria tipo) {
  final controlo = ref.read(biometriaProvider.notifier);
  if (!ref.read(biometriaProvider).oferecer) return;
  controlo.dispensarOferta();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    builder: (sheet) {
      final tema = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 8, 32, Tema.margem + 8, Tema.margem),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: tema.colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(
                  tipo == TipoBiometria.facial ? Icons.face_retouching_natural : Icons.fingerprint_rounded,
                  size: 40,
                  color: tema.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text('Entrar com ${tipo.nome}?', textAlign: TextAlign.center, style: tema.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Da próxima vez abre a área de sócio sem escrever a palavra-passe. '
                'Pode desligar a qualquer momento no seu perfil.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  await controlo.definir(true);
                },
                child: const Text('Activar'),
              ),
              const SizedBox(height: 4),
              TextButton(onPressed: () => Navigator.pop(sheet), child: const Text('Agora não')),
            ],
          ),
        ),
      );
    },
  );
}
