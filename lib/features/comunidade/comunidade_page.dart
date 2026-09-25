import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/cache/com_cache.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/estado_dados.dart';
import '../../core/widgets/imagem_rede.dart';
import '../publico/agenda/agenda.dart';
import '../publico/agenda/agenda_widgets.dart' show EmblemaEquipa;
import 'comunidade.dart';

/// O separador "Comunidade": jogos para palpitar e relatar, a classificação do
/// "Adivinha o resultado" e os passatempos.
///
/// Sem sessão mostra-se o que é, e qualquer acção leva a entrar: todos os
/// pedidos da comunidade exigem conta (sócia ou não).
class ComunidadePage extends ConsumerWidget {
  const ComunidadePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessaoProvider) is SessaoAnonima) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comunidade')),
        body: const _Apresentacao(),
      );
    }
    // "Últimos": os jogos de hoje e de ontem que já acabaram, para quem lá
    // esteve dizer como acabou. Só existe quando há algum, e vem primeiro.
    final recentes = ref.watch(jogosComunidadeProvider('recentes')).valueOrNull?.valor ?? const [];
    final ultimos = ultimosJogos(recentes, DateTime.now());

    return DefaultTabController(
      // A chave muda com a tab: o controlador recomeça na primeira, que passa
      // a ser a "Últimos" quando ela aparece.
      key: ValueKey(ultimos.isNotEmpty),
      length: ultimos.isEmpty ? 3 : 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunidade'),
          // A deslizar: com a letra grande, "Classificação" não cabe num terço.
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              if (ultimos.isNotEmpty) const Tab(text: 'Últimos'),
              const Tab(text: 'Jogos'),
              const Tab(text: 'Classificação'),
              const Tab(text: 'Passatempos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (ultimos.isNotEmpty) _Ultimos(ultimos),
            const _Jogos(),
            const _Classificacao(),
            const _Passatempos(),
          ],
        ),
      ),
    );
  }
}

/// Os jogos acabados de terminar, hoje e ontem.
class _Ultimos extends ConsumerWidget {
  const _Ultimos(this.jogos);

  final List<JogoComunidade> jogos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final hoje = DateTime.now();
    bool eHoje(DateTime d) => d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
    final deHoje = [
      for (final c in jogos)
        if (eHoje(c.jogo.inicio)) c,
    ];
    final deOntem = [
      for (final c in jogos)
        if (!eHoje(c.jogo.inicio)) c,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(jogosComunidadeProvider);
        await ref.read(jogosComunidadeProvider('recentes').future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Esteve num destes jogos ou viu-o? Conte-nos como acabou.',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          if (deHoje.isNotEmpty) ...[const TituloSeccao('Hoje'), for (final c in deHoje) _CartaoJogo(c)],
          if (deOntem.isNotEmpty) ...[const TituloSeccao('Ontem'), for (final c in deOntem) _CartaoJogo(c)],
        ],
      ),
    );
  }
}

/// O que é a comunidade, para quem ainda não entrou.
class _Apresentacao extends StatelessWidget {
  const _Apresentacao();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget linha(IconData icone, String titulo, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconePastilha(icone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: t.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(texto, style: t.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 16, Tema.margem + 4, 32),
      children: [
        Text('Comunidade Leões', style: t.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Para todos os adeptos, sócios ou não. Basta uma conta.',
          style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        linha(
          Icons.psychology_alt_outlined,
          'Adivinhe o resultado',
          'Palpite nos próximos jogos e suba na classificação da época.',
        ),
        linha(
          Icons.campaign_outlined,
          'Diga como acabou',
          'Esteve no jogo? Ajude a registar o resultado dos jogos que ainda não o têm.',
        ),
        linha(Icons.card_giftcard_outlined, 'Passatempos', 'Participe e habilite-se aos prémios do clube.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.go(
            Uri(path: '/entrar', queryParameters: {'voltar': '/comunidade', 'motivo': 'comunidade'}).toString(),
          ),
          child: const Text('Entrar ou criar conta'),
        ),
      ],
    );
  }
}

// ── Jogos ──────────────────────────────────────────────────────────────────

class _Jogos extends ConsumerWidget {
  const _Jogos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentes = ref.watch(jogosComunidadeProvider('recentes'));
    final proximos = ref.watch(jogosComunidadeProvider('proximos'));

    Future<void> actualizar() async {
      ref.invalidate(jogosComunidadeProvider);
      await ref.read(jogosComunidadeProvider('proximos').future);
    }

    // Ambas por carregar: espera-se. Uma só com erro: mostra-se o erro nela.
    if (recentes.valueOrNull == null && proximos.valueOrNull == null) {
      if (recentes.hasError || proximos.hasError) {
        return ErroView(erro: (recentes.error ?? proximos.error)!, tentarDeNovo: actualizar);
      }
      return const Center(child: CircularProgressIndicator());
    }

    final porRelatar = recentes.valueOrNull?.valor ?? const <JogoComunidade>[];
    final porPalpitar = proximos.valueOrNull?.valor ?? const <JogoComunidade>[];

    return RefreshIndicator(
      onRefresh: actualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
        children: [
          if (proximos.valueOrNull case final d?) AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 12)),
          if (porRelatar.isNotEmpty) ...[
            const TituloSeccao('Como acabou?'),
            for (final j in porRelatar) _CartaoJogo(j),
          ],
          const TituloSeccao('Adivinhe o resultado'),
          if (porPalpitar.isEmpty)
            const _Vazio('Não há jogos nos próximos 14 dias. Volte mais perto do fim-de-semana.')
          else
            for (final j in porPalpitar) _CartaoJogo(j),
        ],
      ),
    );
  }
}

/// Um jogo da comunidade: as equipas e o que há para fazer nele. Tocar abre a
/// ficha do jogo, onde está o bloco inteiro.
class _CartaoJogo extends ConsumerWidget {
  const _CartaoJogo(this.c);

  final JogoComunidade c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final j = c.jogo;
    final p = c.palpites;
    final r = c.relatos;
    // Sem `permissoes.comunidade` (§2.10) não se convida a fazer nada.
    final pode = sessaoPode(ref.watch(sessaoProvider), 'comunidade');

    final (estado, destaque) = switch (c) {
      _ when r.confirmado != null => ('Resultado confirmado: ${r.confirmado}', false),
      _ when r.aberto && r.meu != null => ('Disse ${r.meu}', false),
      _ when pode && r.aberto && r.propostas.isNotEmpty => (
        '${_pessoas(r.propostas.first.relatos)} ${r.propostas.first.marcador}. Confirma?',
        true,
      ),
      _ when pode && r.aberto => ('Diga como acabou', true),
      _ when p.meu != null => ('O seu palpite: ${p.meu}', false),
      _ when pode && p.aberto => ('Palpitar', true),
      _ => ('', false),
    };

    Widget equipa(Equipa? e) => Row(
      children: [
        if (e != null) EmblemaEquipa(e, tamanho: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            e?.nome ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: e?.doClube ?? false ? FontWeight.w700 : null),
          ),
        ),
        if (j.golosCasa != null && j.golosFora != null)
          Text('${identical(e, j.casa) ? j.golosCasa : j.golosFora}', style: t.textTheme.titleMedium),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Bloco(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/comunidade/jogo/${j.id}', extra: j),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                DateFormat(j.horaConfirmada ? "EEE, d MMM · HH:mm" : 'EEE, d MMM', 'pt_PT').format(j.inicio),
                ?j.modalidade,
              ].join(' · '),
              style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            equipa(j.casa),
            const SizedBox(height: 6),
            equipa(j.fora),
            if (estado.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      estado,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: destaque ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                        fontWeight: destaque ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _pessoas(int n) => n == 1 ? '1 pessoa diz' : '$n pessoas dizem';
}

// ── Classificação ──────────────────────────────────────────────────────────

class _Classificacao extends ConsumerWidget {
  const _Classificacao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final estado = ref.watch(classificacaoProvider);
    final perfil = ref.watch(perfilComunidadeProvider).valueOrNull;
    final palpites = ref.watch(meusPalpitesProvider).valueOrNull?.valor ?? const [];

    Future<void> actualizar() async {
      ref.invalidate(perfilComunidadeProvider);
      ref.invalidate(meusPalpitesProvider);
      ref.invalidate(classificacaoProvider);
      await ref.read(classificacaoProvider.future);
    }

    return estado.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErroView(erro: e, tentarDeNovo: actualizar),
      data: (Dados<Classificacao> d) {
        final c = d.valor;
        return RefreshIndicator(
          onRefresh: actualizar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 32),
            children: [
              AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 12)),
              if (perfil != null) ...[const SizedBox(height: 12), _Alcunha(perfil)],
              if (c.eu case final eu?) ...[
                const TituloSeccao('A sua posição'),
                Bloco(child: _LinhaTabela(eu, destaque: true)),
              ],
              TituloSeccao(c.epoca == null ? 'Classificação' : 'Classificação ${c.epoca}'),
              if (c.linhas.isEmpty)
                const _Vazio('Ainda ninguém com alcunha pontuou esta época.')
              else
                Bloco(
                  child: Column(
                    children: [
                      for (final (i, l) in c.linhas.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        _LinhaTabela(l, destaque: l.eu),
                      ],
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  '${c.pontosExacto} pontos pelo resultado exacto, ${c.pontosVencedor} por acertar em quem ganha. '
                  'Em caso de empate, conta quem tem mais resultados exactos.',
                  style: t.textTheme.bodySmall,
                ),
              ),
              if (palpites.isNotEmpty) ...[
                const TituloSeccao('Os seus palpites'),
                Bloco(
                  child: Column(
                    children: [
                      for (final (i, (jogo, m, pontos)) in palpites.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          onTap: () => context.push('/comunidade/jogo/${jogo.id}', extra: jogo),
                          title: Text(
                            '${jogo.casa?.nome ?? ''} ${m.casa}–${m.fora} ${jogo.fora?.nome ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              DateFormat('d MMM', 'pt_PT').format(jogo.inicio),
                              if (jogo.golosCasa != null) 'acabou ${jogo.golosCasa}–${jogo.golosFora}',
                            ].join(' · '),
                          ),
                          trailing: Text(
                            pontos == null ? '—' : '+$pontos',
                            style: t.textTheme.titleMedium?.copyWith(
                              color: (pontos ?? 0) > 0 ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LinhaTabela extends StatelessWidget {
  const _LinhaTabela(this.l, {this.destaque = false});

  final LinhaClassificacao l;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final forte = destaque ? FontWeight.w700 : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('${l.posicao}.º', style: t.textTheme.titleSmall?.copyWith(fontWeight: forte)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.alcunha ?? (l.eu ? 'Você (sem alcunha)' : '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyLarge?.copyWith(fontWeight: forte),
                ),
                Text(
                  '${l.exactos} ${l.exactos == 1 ? 'exacto' : 'exactos'} · ${l.palpites} '
                  '${l.palpites == 1 ? 'palpite' : 'palpites'}',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text('${l.pontos}', style: t.textTheme.titleLarge?.copyWith(fontWeight: forte)),
          const SizedBox(width: 4),
          Text('pts', style: t.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// A alcunha é o que aparece na tabela. Nunca vem preenchida com o nome da
/// pessoa: aparecer é uma escolha (RGPD).
class _Alcunha extends ConsumerWidget {
  const _Alcunha(this.perfil);

  final PerfilComunidade perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    if (perfil.bloqueado) {
      return Text(
        'O clube suspendeu a sua participação na comunidade.',
        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.error),
      );
    }
    return Bloco(
      padding: const EdgeInsets.all(16),
      onTap: () => mostrarAlcunha(context, ref, perfil.alcunha),
      child: Row(
        children: [
          const IconePastilha(Icons.badge_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: perfil.alcunha == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Escolha uma alcunha', style: t.textTheme.titleSmall),
                      Text(
                        'Joga na mesma sem ela, mas só aparece na tabela quem tem alcunha.',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A sua alcunha', style: t.textTheme.bodySmall),
                      Text(perfil.alcunha!, style: t.textTheme.titleSmall),
                    ],
                  ),
          ),
          Icon(Icons.edit_outlined, color: t.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Escolher, mudar ou tirar a alcunha.
Future<void> mostrarAlcunha(BuildContext context, WidgetRef ref, String? actual) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FolhaAlcunha(actual),
  );
}

class _FolhaAlcunha extends ConsumerStatefulWidget {
  const _FolhaAlcunha(this.actual);

  final String? actual;

  @override
  ConsumerState<_FolhaAlcunha> createState() => _FolhaAlcunhaState();
}

class _FolhaAlcunhaState extends ConsumerState<_FolhaAlcunha> {
  // Começa com a alcunha que já tem, ou vazio — nunca com o nome da pessoa.
  late final _campo = TextEditingController(text: widget.actual ?? '');
  final _form = GlobalKey<FormState>();
  String? _erro;
  bool _aEnviar = false;

  /// As regras do servidor: 3 a 30 caracteres, letras, números, espaço, `.`, `-`, `_`.
  static final _permitida = RegExp(r'^[\p{L}\p{N} ._-]{3,30}$', unicode: true);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _gravar(String? alcunha) async {
    if (alcunha != null && !_form.currentState!.validate()) return;
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      await ref.read(perfilComunidadeProvider.notifier).mudarAlcunha(alcunha);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (e.erro == 'comunidade_bloqueada') ref.read(perfilComunidadeProvider.notifier).bloqueada();
      if (mounted) setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Alcunha', style: t.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'É o nome com que aparece na classificação, à vista de todos. Não use o seu nome se não quiser.',
                  style: t.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _campo,
                  autofocus: true,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Alcunha', errorText: _erro),
                  validator: (v) => _permitida.hasMatch((v ?? '').trim())
                      ? null
                      : 'De 3 a 30 caracteres: letras, números, espaço, ponto, hífen e _.',
                  onFieldSubmitted: (_) => _gravar(_campo.text.trim()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _aEnviar ? null : () => _gravar(_campo.text.trim()),
                  child: const Text('Guardar'),
                ),
                if (widget.actual != null)
                  TextButton(
                    onPressed: _aEnviar ? null : () => _gravar(null),
                    child: const Text('Sair da classificação'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Passatempos ────────────────────────────────────────────────────────────

class _Passatempos extends ConsumerWidget {
  const _Passatempos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(passatemposProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(passatemposProvider)),
          data: (d) => RefreshIndicator(
            onRefresh: () => ref.refresh(passatemposProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                if (d.valor.isEmpty)
                  const _Vazio('Não há passatempos neste momento. Quando o clube lançar um, aparece aqui.')
                else
                  for (final p in d.valor) CartaoPassatempo(p),
              ],
            ),
          ),
        );
  }
}

class CartaoPassatempo extends StatelessWidget {
  const CartaoPassatempo(this.p, {super.key});

  final Passatempo p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Bloco(
        onTap: () => context.push('/comunidade/passatempos/${p.uid}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.imagemUrl case final url?) AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(url)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EtiquetaFase(p),
                  const SizedBox(height: 8),
                  Text(p.titulo, style: t.textTheme.titleMedium),
                  if (p.resumo != null) ...[
                    const SizedBox(height: 4),
                    Text(p.resumo!, maxLines: 3, overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium),
                  ],
                  if (p.premio != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.card_giftcard_outlined, size: 16, color: t.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(child: Text(p.premio!, style: t.textTheme.bodySmall)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A fase do passatempo, e o que ela quer dizer para quem vê.
class EtiquetaFase extends StatelessWidget {
  const EtiquetaFase(this.p, {super.key});

  final Passatempo p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final (texto, fundo, frente) = switch ((p.fase, p.minha?.vencedor)) {
      ('resultados', true) => ('Ganhou!', c.primary, c.onPrimary),
      ('resultados', _) => ('Vencedores anunciados', c.surfaceContainerHigh, c.onSurfaceVariant),
      (_, _) when p.minha != null => ('Já participou', c.primaryContainer, c.onPrimaryContainer),
      ('a_decorrer', _) => ('A decorrer', c.primaryContainer, c.onPrimaryContainer),
      ('brevemente', _) => ('Brevemente', c.surfaceContainerHigh, c.onSurfaceVariant),
      ('terminado', _) => ('Terminado', c.surfaceContainerHigh, c.onSurfaceVariant),
      _ => ('', c.surfaceContainerHigh, c.onSurfaceVariant),
    };
    if (texto.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        texto,
        style: t.textTheme.labelMedium?.copyWith(color: frente, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(texto, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    );
  }
}
