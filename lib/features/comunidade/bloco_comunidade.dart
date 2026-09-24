import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';
import '../publico/agenda/agenda.dart';
import '../publico/bilheteira/bilheteira.dart' show SemSessao;
import 'comunidade.dart';

/// O bloco da comunidade na ficha de um jogo: "Adivinha o resultado" antes do
/// apito, "Como acabou?" depois. Qual se mostra decide-o o servidor (`aberto`,
/// `motivo`); a app não olha para as datas.
///
/// É um acrescento à ficha: se falhar (sem rede, sem sessão), a ficha do jogo
/// continua igual.
class BlocoComunidade extends ConsumerWidget {
  const BlocoComunidade(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(jogoComunidadeProvider(id))) {
      AsyncError(error: SemSessao()) => const _ConviteEntrar(),
      AsyncData(:final value) => _Conteudo(id, value),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo(this.id, this.c);

  final String id;
  final JogoComunidade c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloqueado = ref.watch(perfilComunidadeProvider).valueOrNull?.bloqueado ?? false;
    final r = c.relatos;
    final p = c.palpites;

    final partes = <Widget>[
      if (p.aberto || p.meu != null || p.total > 0) _Palpite(id, c, bloqueado: bloqueado),
      if (r.aberto || r.meu != null || r.confirmado != null) _Relato(id, c, bloqueado: bloqueado),
    ];
    if (partes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccao('Comunidade Leões'),
        if (bloqueado) ...[const _AvisoBloqueado(), const SizedBox(height: 10)],
        for (final (i, w) in partes.indexed) ...[if (i > 0) const SizedBox(height: 10), w],
      ],
    );
  }
}

/// "Adivinha o resultado": o palpite desta conta e o que os outros acham.
class _Palpite extends ConsumerWidget {
  const _Palpite(this.id, this.c, {required this.bloqueado});

  final String id;
  final JogoComunidade c;
  final bool bloqueado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final p = c.palpites;
    final jogo = c.jogo;
    final podeMexer = p.aberto && !bloqueado;

    Future<void> palpitar() async {
      final m = await pedirMarcador(context, jogo, titulo: 'O seu palpite', inicial: p.meu);
      if (m == null || !context.mounted) return;
      await _escrever(context, ref, id, () => ref.read(jogoComunidadeProvider(id).notifier).palpitar(m));
    }

    Future<void> retirar() =>
        _escrever(context, ref, id, () => ref.read(jogoComunidadeProvider(id).notifier).retirarPalpite());

    return Bloco(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconePastilha(Icons.psychology_alt_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text('Adivinha o resultado', style: t.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          if (p.meu case final meu?) ...[
            Text('O seu palpite', style: t.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(_comEquipas(jogo, meu), style: t.textTheme.titleLarge),
            if (p.meusPontos case final pontos?) ...[
              const SizedBox(height: 4),
              Text(
                switch (pontos) {
                  0 => 'Não pontuou neste jogo',
                  1 => 'Ganhou 1 ponto',
                  _ => 'Ganhou $pontos pontos',
                },
                style: t.textTheme.bodyMedium?.copyWith(
                  color: pontos > 0 ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!p.aberto)
              Text('Os pontos contam quando o jogo acabar.', style: t.textTheme.bodySmall),
          ] else if (p.aberto)
            Text(
              'Diga como acha que acaba. Vale até ao apito inicial: 3 pontos pelo resultado exacto, '
              '1 por acertar em quem ganha.',
              style: t.textTheme.bodyMedium,
            ),
          if (p.total > 0) ...[const SizedBox(height: 14), _Distribuicao(jogo, p)],
          if (podeMexer) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: palpitar, child: Text(p.meu == null ? 'Palpitar' : 'Mudar palpite')),
                ),
                if (p.meu != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: retirar, child: const Text('Retirar')),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Quantos acham que ganha a casa, empata ou ganha a visita. É agregada: não
/// diz quem apostou em quê.
class _Distribuicao extends StatelessWidget {
  const _Distribuicao(this.jogo, this.p);

  final ItemAgenda jogo;
  final Palpites p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final soma = p.vitoriaCasa + p.empate + p.vitoriaFora;
    if (soma == 0) return const SizedBox.shrink();
    int pct(int n) => (n * 100 / soma).round();

    final partes = [
      (jogo.casa?.nome ?? 'Casa', p.vitoriaCasa, c.primary),
      ('Empate', p.empate, c.outline),
      (jogo.fora?.nome ?? 'Fora', p.vitoriaFora, c.tertiary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.total == 1 ? '1 palpite' : '${p.total} palpites',
          style: t.textTheme.labelMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final (_, n, cor) in partes)
                  if (n > 0)
                    Expanded(
                      flex: n,
                      child: ColoredBox(color: cor),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final (nome, n, cor) in partes)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                ),
                Text('${pct(n)} %', style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Como acabou?": relatar o resultado, ao estilo do Waze. Vale quando
/// `necessarios` pessoas diferentes dizem o mesmo.
class _Relato extends ConsumerWidget {
  const _Relato(this.id, this.c, {required this.bloqueado});

  final String id;
  final JogoComunidade c;
  final bool bloqueado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final r = c.relatos;
    final jogo = c.jogo;
    final podeRelatar = r.aberto && !bloqueado && !r.meuAnulado;

    Future<void> relatar(Marcador m) => _escrever(context, ref, id, () async {
      final confirmou = await ref.read(jogoComunidadeProvider(id).notifier).relatar(m);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmou
                ? 'Obrigado! O resultado foi confirmado.'
                : 'Obrigado pela ajuda! A sua participação faz a diferença.',
          ),
        ),
      );
    });

    Future<void> outro() async {
      final m = await pedirMarcador(context, jogo, titulo: 'Como acabou?', inicial: r.meu);
      if (m != null && context.mounted) await relatar(m);
    }

    // Propostas que esta conta ainda não disse: são as que se podem confirmar.
    final paraConfirmar = [
      for (final p in r.propostas)
        if (p.marcador != r.meu) p,
    ];

    return Bloco(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconePastilha(Icons.campaign_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.confirmado != null ? 'Resultado da comunidade' : 'Como acabou?',
                  style: t.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (r.confirmado case final m?)
            Text('Confirmado por quem estava lá: ${_comEquipas(jogo, m)}.', style: t.textTheme.bodyMedium)
          else ...[
            if (podeRelatar)
              Text(
                // Sem falar do mínimo de relatos: a mensagem é que a ajuda de
                // cada adepto conta, não as regras do consenso.
                'Esteve no jogo ou viu-o? Conte-nos como acabou: é com a ajuda dos adeptos '
                'que os resultados ficam registados.',
                style: t.textTheme.bodyMedium,
              ),
            if (r.meu case final meu?) ...[
              const SizedBox(height: 10),
              Text(
                r.meuAnulado ? 'O clube anulou o seu relato ($meu).' : 'Disse: ${_comEquipas(jogo, meu)}',
                style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (podeRelatar) ...[
              for (final p in paraConfirmar) ...[
                const SizedBox(height: 10),
                _Proposta(jogo, p, onConfirmar: () => relatar(p.marcador)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: paraConfirmar.isEmpty && r.meu == null
                    ? FilledButton(onPressed: outro, child: const Text('Dizer o resultado'))
                    : OutlinedButton(
                        onPressed: outro,
                        child: Text(r.meu == null ? 'Foi outro resultado' : 'Corrigir o que disse'),
                      ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "2 pessoas dizem 3–1. Confirma?"
class _Proposta extends StatelessWidget {
  const _Proposta(this.jogo, this.p, {required this.onConfirmar});

  final ItemAgenda jogo;
  final Proposta p;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final quem = p.relatos == 1 ? '1 pessoa diz' : '${p.relatos} pessoas dizem';
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quem, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onPrimaryContainer)),
        Text(
          _comEquipas(jogo, p.marcador),
          style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.onPrimaryContainer),
        ),
      ],
    );
    // O tema estica os botões à largura toda; aqui, só o que o texto pede.
    final botao = FilledButton.tonal(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
      onPressed: onConfirmar,
      child: const Text('Confirmo'),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: t.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
      ),
      // Com a letra do sistema grande o botão não cabe ao lado: vai para baixo.
      child: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [texto, const SizedBox(height: 8), botao])
          : Row(
              children: [
                Expanded(child: texto),
                const SizedBox(width: 8),
                botao,
              ],
            ),
    );
  }
}

class _ConviteEntrar extends StatelessWidget {
  const _ConviteEntrar();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final aqui = GoRouterState.of(context).uri.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccao('Comunidade Leões'),
        Bloco(
          padding: const EdgeInsets.all(16),
          onTap: () =>
              context.go(Uri(path: '/entrar', queryParameters: {'voltar': aqui, 'motivo': 'comunidade'}).toString()),
          child: Row(
            children: [
              const IconePastilha(Icons.groups_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Entre para adivinhar o resultado e ajudar a registar como acabou.',
                  style: t.textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvisoBloqueado extends StatelessWidget {
  const _AvisoBloqueado();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
      ),
      child: Text(
        'O clube suspendeu a sua participação na comunidade. Para saber porquê, fale com a secretaria.',
        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onErrorContainer),
      ),
    );
  }
}

/// "Leões 3–1 Sporting": o resultado com os nomes, para não haver dúvida de
/// qual é a casa.
String _comEquipas(ItemAgenda j, Marcador m) {
  final casa = j.casa?.nome, fora = j.fora?.nome;
  return casa == null || fora == null ? '$m' : '$casa ${m.casa}–${m.fora} $fora';
}

/// Uma escrita na comunidade, com os erros tratados como o guia pede (§4.23, 6).
Future<void> _escrever(BuildContext context, WidgetRef ref, String id, Future<void> Function() accao) async {
  final aviso = ScaffoldMessenger.of(context);
  try {
    await accao();
  } on ApiException catch (e) {
    switch (e.erro) {
      // Esconde os botões e mostra a mensagem.
      case 'comunidade_bloqueada':
        ref.read(perfilComunidadeProvider.notifier).bloqueada();
      // O estado do jogo mudou entretanto: o servidor sabe melhor.
      case 'jogo_com_resultado' ||
          'jogo_por_comecar' ||
          'relatos_fechados' ||
          'palpites_fechados' ||
          'estado_invalido' ||
          'nao_encontrado':
        ref.read(jogoComunidadeProvider(id).notifier).recarregar();
      default:
        break;
    }
    aviso.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Pede um resultado com dois contadores, um por equipa. Sem teclado e sem
/// texto: tudo o que se envia à comunidade é estruturado.
Future<Marcador?> pedirMarcador(BuildContext context, ItemAgenda jogo, {required String titulo, Marcador? inicial}) {
  return showModalBottomSheet<Marcador>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FolhaMarcador(jogo: jogo, titulo: titulo, inicial: inicial ?? const Marcador(0, 0)),
  );
}

class _FolhaMarcador extends StatefulWidget {
  const _FolhaMarcador({required this.jogo, required this.titulo, required this.inicial});

  final ItemAgenda jogo;
  final String titulo;
  final Marcador inicial;

  @override
  State<_FolhaMarcador> createState() => _FolhaMarcadorState();
}

class _FolhaMarcadorState extends State<_FolhaMarcador> {
  late int _casa = widget.inicial.casa, _fora = widget.inicial.fora;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, Tema.margem),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titulo, style: t.textTheme.headlineSmall),
            const SizedBox(height: 20),
            _Contador(
              equipa: widget.jogo.casa?.nome ?? 'Casa',
              valor: _casa,
              onMudar: (v) => setState(() => _casa = v),
            ),
            const SizedBox(height: 12),
            _Contador(
              equipa: widget.jogo.fora?.nome ?? 'Fora',
              valor: _fora,
              onMudar: (v) => setState(() => _fora = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, Marcador(_casa, _fora)),
              child: Text('Enviar $_casa–$_fora'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.equipa, required this.valor, required this.onMudar});

  final String equipa;
  final int valor;
  final ValueChanged<int> onMudar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(equipa, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium),
        ),
        IconButton.outlined(
          tooltip: 'Menos um golo de $equipa',
          onPressed: valor > 0 ? () => onMudar(valor - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$valor',
            textAlign: TextAlign.center,
            style: t.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        IconButton.outlined(
          tooltip: 'Mais um golo de $equipa',
          // A API aceita de 0 a 99.
          onPressed: valor < 99 ? () => onMudar(valor + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
