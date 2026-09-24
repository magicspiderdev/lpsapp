import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../../core/widgets/imagem_rede.dart';
import 'comunidade.dart';
import 'comunidade_page.dart' show EtiquetaFase;

/// `/comunidade/passatempos/{uid}` — um passatempo, e participar nele.
///
/// Uma participação por conta, sem volta atrás: pede-se confirmação antes de
/// enviar. Se a pessoa pode participar decide-o o servidor (`pode_participar`,
/// `motivo`).
class PassatempoPage extends ConsumerStatefulWidget {
  const PassatempoPage({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<PassatempoPage> createState() => _PassatempoPageState();
}

class _PassatempoPageState extends ConsumerState<PassatempoPage> {
  int? _opcao;
  final _resposta = TextEditingController();
  bool _aEnviar = false;

  @override
  void dispose() {
    _resposta.dispose();
    super.dispose();
  }

  Future<void> _participar(Passatempo p) async {
    final resumo = switch (p.tipo) {
      'escolha' => 'Vai responder "${p.opcoes[_opcao!]}".',
      'texto' => 'Vai enviar a sua resposta.',
      _ => 'Vai inscrever-se neste passatempo.',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Participar?'),
        content: Text('$resumo Só se participa uma vez, e depois de enviar não dá para mudar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Rever')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Participar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final aviso = ScaffoldMessenger.of(context);
    setState(() => _aEnviar = true);
    try {
      await ref
          .read(passatempoProvider(widget.uid).notifier)
          .participar(
            opcao: p.tipo == 'escolha' ? _opcao : null,
            resposta: p.tipo == 'texto' ? _resposta.text.trim() : null,
          );
      aviso.showSnackBar(const SnackBar(content: Text('Está a participar. Boa sorte!')));
    } on ApiException catch (e) {
      switch (e.erro) {
        case 'conta_sem_socio':
          if (mounted) {
            aviso.showSnackBar(
              SnackBar(
                content: Text(e.message),
                action: SnackBarAction(
                  label: 'Associar',
                  onPressed: () => context.push(
                    Uri(
                      path: '/associar-socio',
                      queryParameters: {'voltar': '/comunidade/passatempos/${widget.uid}'},
                    ).toString(),
                  ),
                ),
              ),
            );
          }
          return;
        case 'comunidade_bloqueada':
          ref.read(perfilComunidadeProvider.notifier).bloqueada();
          ref.read(passatempoProvider(widget.uid).notifier).recarregar();
        // `menor_de_idade`: passatempo `so_maiores` (§2.10). Recarregado, vem
        // com `motivo: so_maiores` e o botão desaparece.
        case 'passatempo_fechado' || 'ja_participou' || 'nao_encontrado' || 'menor_de_idade' || 'idade_por_verificar':
          ref.read(passatempoProvider(widget.uid).notifier).recarregar();
        default:
          break;
      }
      aviso.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(passatempoProvider(widget.uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Passatempo')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(passatempoProvider(widget.uid))),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(passatempoProvider(widget.uid).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 40),
            children: [
              if (p.imagemUrl case final url?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Tema.raio),
                  child: AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(url)),
                ),
                const SizedBox(height: 16),
              ],
              Align(alignment: Alignment.centerLeft, child: EtiquetaFase(p)),
              const SizedBox(height: 10),
              Text(p.titulo, style: Theme.of(context).textTheme.headlineSmall),
              if (p.descricao ?? p.resumo case final texto?) ...[
                const SizedBox(height: 10),
                Text(texto, style: Theme.of(context).textTheme.bodyLarge),
              ],
              const SizedBox(height: 16),
              _Factos(p),
              const SizedBox(height: 20),
              _Participacao(
                p,
                opcao: _opcao,
                resposta: _resposta,
                aEnviar: _aEnviar,
                onOpcao: (i) => setState(() => _opcao = i),
                onParticipar: () => _participar(p),
              ),
              if (p.regulamento case final r?) ...[
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text('Regulamento'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text(r, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Prémio, quantos ganham, quantos participam, e se é só para sócios.
class _Factos extends StatelessWidget {
  const _Factos(this.p);

  final Passatempo p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget linha(IconData i, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(i, size: 20, color: t.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: t.textTheme.bodyMedium)),
        ],
      ),
    );
    return Bloco(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          if (p.premio != null) linha(Icons.card_giftcard_outlined, p.premio!),
          linha(Icons.emoji_events_outlined, p.vencedores == 1 ? '1 vencedor' : '${p.vencedores} vencedores'),
          linha(Icons.groups_outlined, p.participantes == 1 ? '1 participante' : '${p.participantes} participantes'),
          if (p.soSocios) linha(Icons.verified_outlined, 'Só para sócios'),
          if (p.soMaiores) linha(Icons.eighteen_up_rating_outlined, 'Só para maiores de 18 anos'),
        ],
      ),
    );
  }
}

/// O que a pessoa pode fazer: participar, ver o que respondeu, saber se ganhou.
class _Participacao extends StatelessWidget {
  const _Participacao(
    this.p, {
    required this.opcao,
    required this.resposta,
    required this.aEnviar,
    required this.onOpcao,
    required this.onParticipar,
  });

  final Passatempo p;
  final int? opcao;
  final TextEditingController resposta;
  final bool aEnviar;
  final ValueChanged<int> onOpcao;
  final VoidCallback onParticipar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final minha = p.minha;

    // Já participou: o que respondeu e, depois de anunciado, se ganhou.
    if (minha != null) {
      final ganhou = minha.vencedor == true;
      return Bloco(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (minha.vencedor) {
              true => 'Parabéns, ganhou!',
              false => 'Desta vez não ganhou',
              null => 'Está a participar',
            }, style: t.textTheme.titleMedium?.copyWith(color: ganhou ? t.colorScheme.primary : null)),
            const SizedBox(height: 6),
            if (minha.opcao case final i? when i >= 0 && i < p.opcoes.length)
              Text('Respondeu: ${p.opcoes[i]}', style: t.textTheme.bodyMedium),
            if (minha.resposta case final r?) Text('Respondeu: $r', style: t.textTheme.bodyMedium),
            if (p.respostaCerta case final i? when i >= 0 && i < p.opcoes.length)
              Text('A resposta certa era: ${p.opcoes[i]}', style: t.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(switch (minha.vencedor) {
              true => 'O clube vai contactá-lo pelo email da sua conta para combinar a entrega do prémio.',
              false => 'Obrigado por participar. Fique atento aos próximos passatempos.',
              null => 'Os vencedores são anunciados aqui quando o clube os escolher.',
            }, style: t.textTheme.bodySmall),
          ],
        ),
      );
    }

    if (!p.podeParticipar) {
      final texto = switch (p.motivo) {
        'por_abrir' => 'Ainda não abriu. Volte quando começar.',
        'terminado' => 'Já terminou.',
        'so_socios' => 'Este passatempo é só para sócios.',
        'so_maiores' => 'Este passatempo é só para maiores de 18 anos.',
        // §2.10: a data do registo é só uma declaração. Não há endpoint para
        // a pessoa se verificar a si própria — a app só explica como.
        'idade_por_verificar' =>
          'Este passatempo é só para maiores de 18 anos, com a idade confirmada. '
              'Associe a conta à sua ficha de sócio, ou mostre um documento na secretaria.',
        'bloqueado' => 'O clube suspendeu a sua participação na comunidade.',
        _ => 'Não é possível participar neste passatempo.',
      };
      return Text(texto, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant));
    }

    // Um tipo que a app não conhece não se consegue preencher.
    if (!p.tipoConhecido) {
      return Text(
        'Para participar neste passatempo, actualize a app.',
        style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }

    final pronto = switch (p.tipo) {
      'escolha' => opcao != null,
      'texto' => resposta.text.trim().isNotEmpty,
      _ => true,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.pergunta != null) ...[Text(p.pergunta!, style: t.textTheme.titleMedium), const SizedBox(height: 10)],
        if (p.tipo == 'escolha')
          RadioGroup<int>(
            groupValue: opcao,
            onChanged: (i) => i == null ? null : onOpcao(i),
            child: Column(
              children: [
                for (final (i, o) in p.opcoes.indexed)
                  RadioListTile<int>(value: i, title: Text(o), contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
        // A resposta escrita só o clube a lê: não é uma mensagem para os outros adeptos.
        if (p.tipo == 'texto') ...[
          ListenableBuilder(
            listenable: resposta,
            builder: (_, _) => TextField(
              controller: resposta,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'A sua resposta', helperText: 'Só o clube a lê.'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: resposta,
          builder: (_, _) {
            final podeEnviar =
                !aEnviar &&
                switch (p.tipo) {
                  'texto' => resposta.text.trim().isNotEmpty,
                  _ => pronto,
                };
            return FilledButton(
              onPressed: podeEnviar ? onParticipar : null,
              child: Text(p.tipo == 'inscricao' ? 'Inscrever-me' : 'Participar'),
            );
          },
        ),
      ],
    );
  }
}
