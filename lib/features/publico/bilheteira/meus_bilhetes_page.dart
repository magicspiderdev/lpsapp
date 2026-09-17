import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/em_breve.dart';
import '../../../core/widgets/erro_view.dart';
import 'bilheteira.dart';

/// A carteira: bilhetes comprados, os próximos primeiro.
class MeusBilhetesPage extends ConsumerWidget {
  const MeusBilhetesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(meusBilhetesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Os meus bilhetes')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.qr_code_2_rounded,
                titulo: 'Ainda não tem bilhetes',
                texto: 'Os bilhetes comprados ficam aqui,\ncom o código para mostrar à entrada.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(meusBilhetesProvider)),
        data: (bilhetes) {
          final proximos = bilhetes.where((b) => b.valido).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
          final passados = bilhetes.where((b) => !b.valido).toList()..sort((a, b) => b.inicio.compareTo(a.inicio));

          return ListView(
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
            children: [
              if (bilhetes.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 64),
                  child: PainelEmPreparacao(
                    icone: Icons.qr_code_2_rounded,
                    titulo: 'Ainda não tem bilhetes',
                    texto: 'Os bilhetes comprados aparecem aqui.',
                  ),
                ),
              for (final b in proximos) _CartaoBilhete(b),
              if (passados.isNotEmpty) ...[const TituloSeccao('Usados'), for (final b in passados) _CartaoBilhete(b)],
            ],
          );
        },
      ),
    );
  }
}

/// Bilhete na lista, com o recorte de um bilhete de papel.
class _CartaoBilhete extends StatelessWidget {
  const _CartaoBilhete(this.b);

  final BilheteComprado b;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final usado = !b.valido;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: usado ? 0.6 : 1,
        child: Bloco(
          onTap: () => context.push('/bilhetes/meus/${b.id}'),
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
                            b.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleMedium?.copyWith(color: Colors.white),
                          ),
                          if (b.subtitulo != null)
                            Text(
                              b.subtitulo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(usado ? Icons.check_circle_outline_rounded : Icons.qr_code_2_rounded, color: Colors.white),
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
                            DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_PT').format(b.inicio),
                            style: t.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [b.zona, if (b.lugar != null) b.lugar!, if (b.local != null) b.local!].join(' · '),
                            maxLines: 2,
                            style: t.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (usado)
                      Text('Usado', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onSurfaceVariant))
                    else
                      Text(b.preco == 0 ? 'Grátis' : euros(b.preco), style: t.textTheme.titleSmall),
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
class BilhetePage extends ConsumerWidget {
  const BilhetePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(bilheteProvider(id));
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bilhete')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is EmPreparacao
            ? const PainelEmPreparacao(
                icone: Icons.qr_code_2_rounded,
                titulo: 'Bilhete indisponível',
                texto: 'Este bilhete ainda não existe.',
              )
            : ErroView(erro: e, tentarDeNovo: () => ref.invalidate(bilheteProvider(id))),
        data: (b) => ListView(
          padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
          children: [
            Bloco(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Text(b.titulo, textAlign: TextAlign.center, style: t.textTheme.titleLarge),
                  if (b.subtitulo != null) ...[
                    const SizedBox(height: 4),
                    Text(b.subtitulo!, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 20),
                  // Fundo branco em claro e em escuro: um QR invertido não lê em todos os leitores.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(Tema.raioPequeno),
                    ),
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
                  SelectableText(b.codigo, style: t.textTheme.titleSmall?.copyWith(letterSpacing: 1.5)),
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
        ),
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
