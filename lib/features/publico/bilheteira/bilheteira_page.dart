import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'bilheteira.dart';

/// Sessões com bilhetes à venda.
class BilheteiraPage extends ConsumerWidget {
  const BilheteiraPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sessoesProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 20, Tema.margem, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ENTRADAS',
                    style: t.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Bilhetes', style: t.headlineLarge),
                ],
              ),
            ),
            Expanded(
              child: estado.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => e is EmPreparacao
                    ? const PainelEmPreparacao(
                        icone: Icons.confirmation_number_outlined,
                        titulo: 'Bilhetes a caminho',
                        texto:
                            'Comprar bilhetes para jogos e eventos,\ncom desconto de sócio e entrada pelo telemóvel.',
                      )
                    : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(sessoesProvider)),
                data: (sessoes) => ListView(
                  padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
                  children: [for (final s in sessoes) _CartaoSessao(s), const SizedBox(height: 16), _MeusBilhetes()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoSessao extends StatelessWidget {
  const _CartaoSessao(this.s);

  final Sessao s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final data = DateFormat("d 'de' MMMM", 'pt_PT').format(s.inicio);
    final hora = DateFormat('HH:mm').format(s.inicio);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Bloco(
        onTap: () => context.push('/bilhetes/${s.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.capaUrl != null)
              AspectRatio(aspectRatio: 16 / 9, child: ImagemRede(s.capaUrl!))
            else
              Container(
                height: 96,
                decoration: const BoxDecoration(gradient: Tema.gradienteClube),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(16),
                child: Text('$data · $hora', style: t.textTheme.titleSmall?.copyWith(color: Colors.white)),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.titulo, style: t.textTheme.titleMedium),
                  if (s.subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(s.subtitulo!, style: t.textTheme.bodySmall),
                  ],
                  if (s.local != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: t.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.local!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: s.esgotado
                            ? Text('Esgotado', style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.error))
                            : Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: 'desde ', style: t.textTheme.bodySmall),
                                    TextSpan(
                                      text: s.precoDesde == 0 ? 'grátis' : euros(s.precoDesde ?? 0),
                                      style: t.textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      FilledButton.tonal(
                        // Tamanho próprio: o tema dá largura total aos botões, o que não cabe numa linha.
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: s.esgotado ? null : () => context.push('/bilhetes/${s.id}'),
                        child: Text(s.esgotado ? 'Sem bilhetes' : 'Ver bilhetes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os bilhetes comprados vivem na conta, como o cartão de sócio.
class _MeusBilhetes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Bloco(
      padding: const EdgeInsets.all(16),
      onTap: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Os bilhetes comprados aparecem aqui quando a bilheteira abrir.'))),
      child: Row(
        children: [
          const IconePastilha(Icons.qr_code_2_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Os meus bilhetes', style: t.textTheme.titleSmall),
                Text('Entrada pelo telemóvel, sem imprimir', style: t.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

/// Escolha de zona e quantidade para uma sessão.
class SessaoPage extends ConsumerStatefulWidget {
  const SessaoPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SessaoPage> createState() => _SessaoPageState();
}

class _SessaoPageState extends ConsumerState<SessaoPage> {
  final _quantidades = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(sessaoProvider(widget.id));
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bilhetes')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.confirmation_number_outlined,
                titulo: 'Bilhetes a caminho',
                texto: 'Ainda não é possível comprar bilhetes na app.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(sessaoProvider(widget.id))),
        data: (s) => ListView(
          padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
          children: [
            Text(s.titulo, style: t.textTheme.headlineSmall),
            if (s.subtitulo != null) Text(s.subtitulo!, style: t.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Bloco(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Linha(Icons.event_outlined, DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_PT').format(s.inicio)),
                  if (s.local != null) ...[const SizedBox(height: 10), _Linha(Icons.place_outlined, s.local!)],
                ],
              ),
            ),
            const TituloSeccao('Escolha os bilhetes'),
            Bloco(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, z) in s.zonas.indexed) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _LinhaZona(
                      z,
                      quantidade: _quantidades[z.id] ?? 0,
                      onMudar: (q) => setState(() => _quantidades[z.id] = q),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: estado.valueOrNull == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 12),
                child: _Comprar(sessao: estado.value!, quantidades: _quantidades),
              ),
            ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.icone, this.texto);

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Icon(icone, size: 18, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: t.textTheme.bodyMedium)),
      ],
    );
  }
}

class _LinhaZona extends StatelessWidget {
  const _LinhaZona(this.z, {required this.quantidade, required this.onMudar});

  final Zona z;
  final int quantidade;
  final ValueChanged<int> onMudar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(z.nome, style: t.textTheme.titleSmall),
                Text(
                  [
                    z.preco == 0 ? 'Grátis' : euros(z.preco),
                    if (z.nota != null) z.nota!,
                    if (!z.disponivel) 'esgotado',
                  ].join(' · '),
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: !z.disponivel || quantidade == 0 ? null : () => onMudar(quantidade - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 32,
            child: Text('$quantidade', textAlign: TextAlign.center, style: t.textTheme.titleMedium),
          ),
          IconButton.filledTonal(
            onPressed: !z.disponivel || quantidade >= 6 ? null : () => onMudar(quantidade + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _Comprar extends StatelessWidget {
  const _Comprar({required this.sessao, required this.quantidades});

  final Sessao sessao;
  final Map<String, int> quantidades;

  @override
  Widget build(BuildContext context) {
    var total = 0.0;
    var bilhetes = 0;
    for (final z in sessao.zonas) {
      final q = quantidades[z.id] ?? 0;
      total += z.preco * q;
      bilhetes += q;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bilhetes > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text('$bilhetes ${bilhetes == 1 ? 'bilhete' : 'bilhetes'}')),
                Text(euros(total), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        FilledButton(
          // A compra depende da bilheteira no CISOC e de conta para quem não é sócio.
          onPressed: bilhetes == 0
              ? null
              : () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('A compra de bilhetes ainda não está disponível.'))),
          child: Text(bilhetes == 0 ? 'Escolha os bilhetes' : 'Continuar'),
        ),
      ],
    );
  }
}
