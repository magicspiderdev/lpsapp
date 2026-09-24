import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/sessao.dart' as auth;
import '../../../core/formatos.dart';
import '../../../core/links.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import 'bilheteira.dart';
import 'compra.dart';
import 'comprar_sheet.dart';

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
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(sessoesProvider)),
                data: (d) => RefreshIndicator(
                  onRefresh: () => ref.refresh(sessoesProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
                    children: [
                      AvisoDesactualizado(d),
                      if (d.valor.isEmpty) const _SemSessoes() else for (final s in d.valor) _CartaoSessao(s),
                      const SizedBox(height: 16),
                      _MeusBilhetes(),
                    ],
                  ),
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
                        child: !s.aVenda
                            ? Text(
                                s.motivoFechada!,
                                style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.error),
                              )
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
                        onPressed: s.aVenda ? () => context.push('/bilhetes/${s.id}') : null,
                        child: Text(s.aVenda ? 'Ver bilhetes' : 'Sem bilhetes'),
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

class _SemSessoes extends StatelessWidget {
  const _SemSessoes();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          const IconePastilha(Icons.confirmation_number_outlined),
          const SizedBox(height: 16),
          Text('Sem bilhetes à venda', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Quando o clube abrir a venda para um jogo ou evento, aparece aqui.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall,
          ),
        ],
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
      onTap: () => context.push('/bilhetes/meus'),
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

/// Escolha de bilhetes de uma sessão: **uma zona de cada vez**.
///
/// Não é uma limitação do ecrã: uma encomenda é de uma zona
/// (`POST /me/bilhetes/encomendas` leva `{sessao, zona, quantidade}`, §4.18).
/// Somar tipos de bilhete diferentes num só total prometia uma compra que a
/// API não faz — e dava dois pagamentos onde o ecrã mostrava um.
class SessaoPage extends ConsumerStatefulWidget {
  const SessaoPage({super.key, required this.id, this.quantidadesIniciais = const {}});

  final String id;

  /// A escolha feita antes de ir entrar na conta (vem no link de volta).
  final Map<String, int> quantidadesIniciais;

  @override
  ConsumerState<SessaoPage> createState() => _SessaoPageState();
}

class _SessaoPageState extends ConsumerState<SessaoPage> {
  String? _zona;
  int _quantidade = 1;

  @override
  void initState() {
    super.initState();
    // Voltou de entrar na conta: retoma a escolha que tinha feito.
    if (widget.quantidadesIniciais.entries.firstOrNull case final escolha?) {
      _zona = escolha.key;
      _quantidade = escolha.value;
    }
  }

  /// O caminho de volta a este ecrã, com a escolha, para quem tem de sair
  /// daqui (entrar na conta, associar a ficha) e voltar ao mesmo sítio.
  String get _aqui => Uri(
    path: '/bilhetes/${widget.id}',
    queryParameters: _zona == null
        ? null
        : {
            'z': quantidadesParaLink({_zona!: _quantidade}),
          },
  ).toString();

  void _continuar(Sessao s, Zona z, QuemPode quem) {
    switch (quem) {
      case QuemPode.precisaDeConta:
        context.go(Uri(path: '/entrar', queryParameters: {'voltar': _aqui, 'motivo': 'bilhetes'}).toString());
      case QuemPode.precisaDeSocio:
        context.push(Uri(path: '/associar-socio', queryParameters: {'voltar': _aqui}).toString());
      case QuemPode.foraDaApp:
        if (z.urlCompra case final url?) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      case QuemPode.indisponivel || QuemPode.soEncarregado:
        break;
      case QuemPode.podeComprar:
        mostrarComprar(context, sessao: s, zona: z, quantidade: _quantidade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(sessaoProvider(widget.id));
    final quemSou = ref.watch(auth.sessaoProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilhetes'),
        actions: [
          if (estado.valueOrNull?.valor case final s?)
            Builder(
              builder: (botao) => IconButton(
                tooltip: 'Partilhar',
                icon: Icon(Icons.adaptive.share),
                onPressed: () => Links.partilhar(botao, titulo: s.titulo, link: Links.sessao(s.id)),
              ),
            ),
        ],
      ),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(sessaoProvider(widget.id))),
        data: (d) {
          final s = d.valor;
          // A zona escolhida pode ter deixado de existir entre o link e agora.
          final zona = s.zonas.where((z) => z.id == _zona).firstOrNull;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(sessaoProvider(widget.id).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
              children: [
                AvisoDesactualizado(d),
                Text(s.titulo, style: t.textTheme.headlineSmall),
                if (s.subtitulo != null) Text(s.subtitulo!, style: t.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Bloco(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _Linha(
                        Icons.event_outlined,
                        DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_PT').format(s.inicio),
                      ),
                      if (s.local != null) ...[const SizedBox(height: 10), _Linha(Icons.place_outlined, s.local!)],
                    ],
                  ),
                ),
                const TituloSeccao('Tipos de bilhete'),
                Bloco(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, z) in s.zonas.indexed) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16, height: 1),
                        _LinhaZona(
                          z,
                          quem: quemPodeComprar(quemSou, z, sessaoAVenda: s.aVenda),
                          seleccionada: z.id == _zona,
                          quantidade: z.id == _zona ? _quantidade : 0,
                          onSeleccionar: () => setState(() {
                            _zona = z.id;
                            // Trocar de zona recomeça em um: o número da
                            // anterior não diz nada sobre esta.
                            _quantidade = 1;
                          }),
                          onQuantidade: (q) => setState(() => _quantidade = q),
                        ),
                      ],
                    ],
                  ),
                ),
                if (s.zonas.length > 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Cada compra é de um tipo de bilhete. Para levar de tipos diferentes, '
                    'faça uma compra de cada vez.',
                    style: t.textTheme.bodySmall,
                  ),
                ],
                if (_explicacao(zona, quemSou, s) case final aviso?) ...[
                  const SizedBox(height: 10),
                  Text(aviso, style: t.textTheme.bodySmall),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: switch (estado.valueOrNull?.valor) {
        final s? => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 12),
            child: _BarraDeCompra(
              sessao: s,
              zona: s.zonas.where((z) => z.id == _zona).firstOrNull,
              quantidade: _quantidade,
              quem: quemSou,
              onContinuar: _continuar,
            ),
          ),
        ),
        _ => null,
      },
    );
  }

  /// A frase que explica a zona escolhida, quando ela precisa de explicação.
  String? _explicacao(Zona? z, auth.Sessao quemSou, Sessao s) {
    if (z == null) return null;
    return switch (quemPodeComprar(quemSou, z, sessaoAVenda: s.aVenda)) {
      QuemPode.precisaDeSocio =>
        'Esta zona é reservada a sócios. Associe a sua ficha de sócio à conta para a poder comprar.',
      QuemPode.foraDaApp => 'Os bilhetes desta zona compram-se no site da bilheteira.',
      QuemPode.podeComprar when z.maxPorConta != null =>
        'Máximo de ${z.maxPorConta} ${z.maxPorConta == 1 ? 'bilhete' : 'bilhetes'} por conta nesta zona.',
      _ => null,
    };
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

/// Uma zona: escolhe-se tocando na linha; o contador só aparece na escolhida.
///
/// O contador em baixo, e não ao lado do nome: num ecrã estreito com a letra
/// do sistema no máximo, nome e três botões na mesma linha não cabem.
class _LinhaZona extends StatelessWidget {
  const _LinhaZona(
    this.z, {
    required this.quem,
    required this.seleccionada,
    required this.quantidade,
    required this.onSeleccionar,
    required this.onQuantidade,
  });

  final Zona z;
  final QuemPode quem;
  final bool seleccionada;
  final int quantidade;
  final VoidCallback onSeleccionar;
  final ValueChanged<int> onQuantidade;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final indisponivel = quem == QuemPode.indisponivel;
    // Uma zona de sócios continua a escolher-se: é no fundo do ecrã que se
    // explica o que falta. Escondê-la só deixava a pergunta por responder.
    final legenda = [
      z.gratuita ? 'Grátis' : euros(z.preco),
      if (z.exigeSocio) 'só sócios',
      if (!z.naApp) 'compra-se no site',
      ?z.nota,
      if (!z.disponivel) 'esgotado',
    ].join(' · ');

    return Material(
      color: seleccionada ? c.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: indisponivel ? null : onSeleccionar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    seleccionada ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: indisponivel ? c.onSurfaceVariant : (seleccionada ? c.primary : c.outline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          z.nome,
                          style: t.textTheme.titleSmall?.copyWith(color: indisponivel ? c.onSurfaceVariant : null),
                        ),
                        Text(legenda, style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              if (seleccionada && quem == QuemPode.podeComprar) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$quantidade ${quantidade == 1 ? 'bilhete' : 'bilhetes'}',
                        style: t.textTheme.titleMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Menos um bilhete',
                      onPressed: quantidade <= 1 ? null : () => onQuantidade(quantidade - 1),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Mais um bilhete',
                      // O máximo é o da zona (`max_por_conta`), não um número
                      // inventado cá; o servidor tem a palavra final.
                      onPressed: quantidade >= z.maximo ? null : () => onQuantidade(quantidade + 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// O botão do fundo: diz o que falta fazer, e não "Continuar" para tudo.
class _BarraDeCompra extends StatelessWidget {
  const _BarraDeCompra({
    required this.sessao,
    required this.zona,
    required this.quantidade,
    required this.quem,
    required this.onContinuar,
  });

  final Sessao sessao;
  final Zona? zona;
  final int quantidade;
  final auth.Sessao quem;
  final void Function(Sessao, Zona, QuemPode) onContinuar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (!sessao.aVenda) return FilledButton(onPressed: null, child: Text(sessao.motivoFechada!));

    final z = zona;
    if (z == null) return const FilledButton(onPressed: null, child: Text('Escolha o bilhete'));

    final estado = quemPodeComprar(quem, z, sessaoAVenda: sessao.aVenda);
    if (estado == QuemPode.soEncarregado) {
      return NotaPermissao(auth.explicacaoPermissao('comprar'), padding: EdgeInsets.zero);
    }
    final total = z.preco * quantidade;
    final (texto, activo) = switch (estado) {
      QuemPode.podeComprar when z.gratuita => ('Levantar bilhetes', true),
      QuemPode.podeComprar => ('Continuar', true),
      QuemPode.precisaDeConta => ('Entrar para continuar', true),
      QuemPode.precisaDeSocio => ('Associar a minha ficha de sócio', true),
      QuemPode.foraDaApp => ('Comprar no site da bilheteira', z.urlCompra != null),
      QuemPode.indisponivel => (z.disponivel ? 'Sem bilhetes' : 'Esgotado', false),
      QuemPode.soEncarregado => ('', false),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (estado == QuemPode.podeComprar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text('$quantidade ${quantidade == 1 ? 'bilhete' : 'bilhetes'} · ${z.nome}')),
                Text(total == 0 ? 'Grátis' : euros(total), style: t.textTheme.titleMedium),
              ],
            ),
          ),
        FilledButton(onPressed: activo ? () => onContinuar(sessao, z, estado) : null, child: Text(texto)),
      ],
    );
  }
}
