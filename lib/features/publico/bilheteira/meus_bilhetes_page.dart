import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'bilheteira.dart';
import 'imagem_bilhete.dart';

/// Separador de linhas do texto que se envia.
const _quebra = '\n';

/// A carteira: bilhetes comprados, os próximos primeiro.
class MeusBilhetesPage extends ConsumerWidget {
  const MeusBilhetesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(meusBilhetesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Os meus bilhetes')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is SemSessao
            ? const PainelEmPreparacao(
                icone: Icons.qr_code_2_rounded,
                titulo: 'Entre para ver os seus bilhetes',
                texto: 'Os bilhetes ficam na sua conta,\ncom o código para mostrar à entrada.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(meusBilhetesProvider)),
        data: (d) {
          // Um cartão por evento, não um por bilhete.
          final (proximos, passados) = ref.watch(carteiraProvider);

          return ListView(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
            children: [
              AvisoDesactualizado(d),
              if (d.valor.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: PainelEmPreparacao(
                    icone: Icons.qr_code_2_rounded,
                    titulo: 'Ainda não tem bilhetes',
                    texto: 'Os bilhetes comprados aparecem aqui.',
                  ),
                ),
              for (final g in proximos) _CartaoEvento(g),
              if (passados.isNotEmpty) ...[
                const TituloSeccao('Já passaram'),
                for (final g in passados) _CartaoEvento(g),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Um evento na carteira, com o recorte de um bilhete de papel.
///
/// Mostra quantos bilhetes se tem para aquele evento; abre no primeiro por
/// usar, que é o que a portaria vai querer ler.
class _CartaoEvento extends StatelessWidget {
  const _CartaoEvento(this.g);

  final GrupoBilhetes g;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final usados = g.todosUsados;
    // Abrir no primeiro por usar poupa uma passagem com a fila à espera.
    final abrir = g.bilhetes.firstWhere((b) => b.valido, orElse: () => g.primeiro);
    final quantos = '${g.quantos} ${g.quantos == 1 ? 'bilhete' : 'bilhetes'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: usados ? 0.6 : 1,
        child: Bloco(
          onTap: () => context.push('/bilhetes/meus/${abrir.id}'),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: Tema.gradienteClube),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleMedium?.copyWith(color: Colors.white),
                          ),
                          if (g.subtitulo case final subtitulo?)
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Quantos(quantos: g.quantos, usados: usados),
                  ],
                ),
              ),
              // Picotado, como num bilhete de papel.
              const _Picotado(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_PT').format(g.inicio),
                            style: t.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [quantos, if (g.zonas.isNotEmpty) g.zonas, ?g.local].join(' · '),
                            maxLines: 2,
                            style: t.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      switch (g) {
                        // Meio usados: o que falta é a informação útil à porta.
                        GrupoBilhetes(todosUsados: true) => 'Usados',
                        GrupoBilhetes(:final porUsar, :final quantos) when porUsar < quantos => '$porUsar por usar',
                        GrupoBilhetes(total: 0) => 'Grátis',
                        _ => euros(g.total),
                      },
                      style: usados
                          ? t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)
                          : t.textTheme.titleSmall,
                    ),
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

/// O sinal de quantos bilhetes o cartão guarda — um QR, ou um QR com o número
/// por cima quando é mais do que um.
class _Quantos extends StatelessWidget {
  const _Quantos({required this.quantos, required this.usados});

  final int quantos;
  final bool usados;

  @override
  Widget build(BuildContext context) {
    final icone = Icon(usados ? Icons.check_circle_outline_rounded : Icons.qr_code_2_rounded, color: Colors.white);
    if (quantos == 1) return icone;

    return Semantics(
      label: '$quantos bilhetes',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '×$quantos',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          icone,
        ],
      ),
    );
  }
}

class _Picotado extends StatelessWidget {
  const _Picotado();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, caixa) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < caixa.maxWidth ~/ 12; i++)
                  Container(width: 6, height: 1.5, color: c.outlineVariant),
              ],
            ),
          ),
          // Meias-luas nas pontas, como o recorte de um bilhete.
          Align(
            alignment: Alignment.centerLeft,
            child: _Recorte(cor: c.surface, esquerda: true),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _Recorte(cor: c.surface, esquerda: false),
          ),
        ],
      ),
    );
  }
}

class _Recorte extends StatelessWidget {
  const _Recorte({required this.cor, required this.esquerda});

  final Color cor;
  final bool esquerda;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(esquerda ? -10 : 10, 0),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
      ),
    );
  }
}

/// O bilhete aberto: o QR grande, para a portaria ler.
///
/// Quem comprou vários passa de um para o outro **arrastando o dedo**: à
/// entrada os códigos são lidos um a um, e voltar à lista entre cada pessoa
/// era um passo a mais com a fila à espera.
class BilhetePage extends ConsumerStatefulWidget {
  const BilhetePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BilhetePage> createState() => _BilhetePageState();
}

class _BilhetePageState extends ConsumerState<BilhetePage> {
  PageController? _paginas;

  /// Em que bilhete se está. `null` = ainda não se arrastou nada, e então vale
  /// aquele por onde se entrou.
  ///
  /// Nulo, e não `0`: com `0` como "ainda não mexeu", arrastar **para o
  /// primeiro** bilhete era indistinguível de não ter mexido — o título e o
  /// botão de partilhar continuavam a ser os do bilhete por onde se entrou, e
  /// partilhava-se o código errado.
  int? _actual;

  @override
  void dispose() {
    _paginas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A carteira tem de estar carregada para haver bilhete: é dela que ele vem,
    // e é isso que o faz abrir sem rede.
    final carteira = ref.watch(meusBilhetesProvider);
    final bilhetes = ref.watch(bilhetesDoEventoProvider(widget.id));

    if (bilhetes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bilhete')),
        body: carteira.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const PainelEmPreparacao(
                icone: Icons.qr_code_2_rounded,
                titulo: 'Bilhete indisponível',
                texto: 'Este bilhete não está na sua carteira.',
              ),
      );
    }

    final inicial = bilhetes.indexWhere((b) => b.id == widget.id).clamp(0, bilhetes.length - 1);
    _paginas ??= PageController(initialPage: inicial);
    final indice = (_actual ?? inicial).clamp(0, bilhetes.length - 1);
    final b = bilhetes[indice];

    return Scaffold(
      appBar: AppBar(
        title: Text(bilhetes.length > 1 ? 'Bilhete ${indice + 1} de ${bilhetes.length}' : 'Bilhete'),
        actions: [
          Builder(
            builder: (botao) => IconButton(
              // Partilha-se o que está à frente, não "o bilhete": num evento
              // com vários, o que se vê é o que se envia.
              tooltip: 'Enviar este bilhete',
              icon: Icon(Icons.adaptive.share),
              onPressed: () => _enviar(botao, b),
            ),
          ),
        ],
      ),
      body: bilhetes.length == 1
          ? _Bilhete(bilhetes.single)
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _paginas,
                    itemCount: bilhetes.length,
                    onPageChanged: (i) => setState(() => _actual = i),
                    itemBuilder: (_, i) => _Bilhete(bilhetes[i]),
                  ),
                ),
                // Quem não sabe que pode arrastar não arrasta: os pontos são o
                // que diz que há mais bilhetes deste lado.
                _Pontos(quantos: bilhetes.length, actual: indice),
              ],
            ),
    );
  }

  /// Enviar **um** bilhete a quem vai com ele: a imagem do bilhete, com o QR,
  /// e o texto com o mesmo código.
  ///
  /// A imagem é o que serve à porta — quem recebe mostra-a e é lida, sem ter
  /// de instalar a app. O texto vai na mesma: uma mensagem só com fotografia
  /// não se pesquisa, e o código escrito lê-se em voz alta se o leitor falhar.
  /// Não expõe mais nada do que o texto já expunha: o QR é o mesmo código.
  ///
  /// O código é ao portador: quem o mostrar primeiro entra, e não há forma de
  /// o voltar atrás. Por isso vai um de cada vez, com o aviso no próprio texto
  /// — e por isso está pedido ao CISOC um "transferir bilhete" a sério, que
  /// emite um código novo para outra conta e anula este.
  Future<void> _enviar(BuildContext origem, BilheteComprado b) async {
    final quando = DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_PT').format(b.inicio);
    final texto = [
      b.titulo,
      if (b.subtitulo != null) b.subtitulo!,
      quando,
      if (b.local != null) b.local!,
      if (b.zona.isNotEmpty) 'Zona: ${b.zona}',
      '',
      'Código de entrada: ${b.codigo}',
      '',
      'Este código entra uma vez só. Mostre-o à entrada.',
    ].join(_quebra);

    final caixa = origem.findRenderObject() as RenderBox?;
    // Sem a imagem, envia-se o texto na mesma: o código é o que conta, e o
    // bilhete não pode ficar por enviar porque um desenho falhou.
    final imagem = await _ficheiroDoBilhete(b);

    await SharePlus.instance.share(
      ShareParams(
        text: texto,
        subject: 'Bilhete · ${b.titulo}',
        files: imagem == null ? null : [imagem],
        sharePositionOrigin: caixa == null ? null : caixa.localToGlobal(Offset.zero) & caixa.size,
      ),
    );
  }

  /// O bilhete desenhado, gravado onde a folha de partilha o consegue ler.
  ///
  /// Vai para a pasta temporária: é um ficheiro para entregar a outra app,
  /// não uma cópia do bilhete para guardar — o bilhete vive na carteira.
  Future<XFile?> _ficheiroDoBilhete(BilheteComprado b) async {
    try {
      final bytes = await imagemDoBilhete(b);
      if (bytes == null) return null;
      final pasta = Directory('${(await getTemporaryDirectory()).path}/bilhetes');
      await pasta.create(recursive: true);
      final ficheiro = File('${pasta.path}/bilhete-${b.id}.png');
      await ficheiro.writeAsBytes(bytes);
      return XFile(ficheiro.path, mimeType: 'image/png', name: 'bilhete.png');
    } catch (_) {
      return null;
    }
  }
}

/// O código por extenso, para se ler em voz alta se o QR não passar.
///
/// Toca-se para copiar, e **não se selecciona arrastando**: com um
/// `SelectableText` aqui, o arrastar do dedo a meio do ecrã ia para a selecção
/// de texto em vez de passar ao bilhete seguinte — e é precisamente a meio do
/// ecrã que o polegar arrasta.
class _Codigo extends StatelessWidget {
  const _Codigo(this.codigo);

  final String codigo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(Tema.raioPequeno),
      onTap: () async {
        // O aviso guarda-se antes do `await`: depois dele este widget pode já
        // não estar montado, e não se diz "copiado" sem ter copiado.
        final aviso = ScaffoldMessenger.of(context);
        try {
          await Clipboard.setData(ClipboardData(text: codigo));
          aviso.showSnackBar(const SnackBar(content: Text('Código copiado')));
        } catch (_) {
          aviso.showSnackBar(const SnackBar(content: Text('Não foi possível copiar o código')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                codigo,
                textAlign: TextAlign.center,
                style: t.textTheme.titleSmall?.copyWith(letterSpacing: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 16, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Onde se vai nos bilhetes de um evento, e que há mais para o lado.
class _Pontos extends StatelessWidget {
  const _Pontos({required this.quantos, required this.actual});

  final int quantos, actual;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < quantos; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == actual ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == actual ? c.primary : c.outlineVariant,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Arraste para o bilhete seguinte', style: TextStyle(fontSize: 12, color: c.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Um bilhete: o QR grande e os detalhes por baixo.
class _Bilhete extends StatelessWidget {
  const _Bilhete(this.b);

  final BilheteComprado b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
      children: [
        Bloco(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              if (b.convite) ...[const _SeloOferta(), const SizedBox(height: 12)],
              Text(b.titulo, textAlign: TextAlign.center, style: t.textTheme.titleLarge),
              if (b.subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(b.subtitulo!, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
              ],
              const SizedBox(height: 20),
              // Fundo branco em claro e em escuro: um QR invertido não lê em todos os leitores.
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Tema.raioPequeno)),
                child: Opacity(
                  opacity: b.valido ? 1 : 0.3,
                  child: QrImageView(
                    data: b.codigo,
                    size: 220,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0B0D10)),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0B0D10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Codigo(b.codigo),
              const SizedBox(height: 10),
              if (b.valido)
                Text('Mostre este código à entrada', style: t.textTheme.bodyMedium)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Bilhete já usado', style: t.textTheme.labelLarge),
                ),
            ],
          ),
        ),
        const TituloSeccao('Detalhes'),
        Bloco(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              _Detalhe('Quando', DateFormat("EEEE, d 'de' MMMM 'às' HH:mm", 'pt_PT').format(b.inicio)),
              if (b.local != null) _Detalhe('Onde', b.local!),
              _Detalhe('Bilhete', [b.zona, if (b.lugar != null) b.lugar!].join(' · ')),
              if (b.titular != null) _Detalhe('Titular', b.titular!),
              if (b.paraNome != null && b.paraNome != b.titular) _Detalhe('Para', b.paraNome!),
              if (b.compradoPorOutro) const _Detalhe('Comprado por', 'O seu encarregado de educação'),
              if (b.convite)
                _Detalhe('Oferta', b.conviteMensagem ?? 'Convite do clube')
              else
                _Detalhe('Preço', b.preco == 0 ? 'Grátis' : euros(b.preco)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'O bilhete é pessoal. O código só pode ser usado uma vez.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// "Oferta do clube", por cima de um convite.
class _SeloOferta extends StatelessWidget {
  const _SeloOferta();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard_rounded, size: 16, color: c.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            'Oferta do clube',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: c.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

class _Detalhe extends StatelessWidget {
  const _Detalhe(this.rotulo, this.valor);

  final String rotulo, valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(valor, textAlign: TextAlign.end, style: t.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
