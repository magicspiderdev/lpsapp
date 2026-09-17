import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import 'cartao.dart';

/// Cartão digital com o QR que a portaria lê. Abre sem rede com o último cartão guardado.
class CartaoPage extends ConsumerWidget {
  const CartaoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(cartaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cartão de sócio')),
      body: estado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(cartaoProvider)),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.refresh(cartaoProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
            children: s.semCartao || s.cartao == null ? const [_SemCartao()] : _conteudo(context, s),
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context, EstadoCartao s) {
    final c = s.cartao!;
    final tema = Theme.of(context);

    return [
      if (s.deCache) ...[
        _Aviso(
          icone: Icons.cloud_off_rounded,
          texto: s.obtidoEm == null
              ? 'Sem ligação. A mostrar o último cartão guardado.'
              : 'Sem ligação. Cartão guardado em ${DateFormat("d MMM 'às' HH:mm", 'pt_PT').format(s.obtidoEm!)}.',
          cor: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
      ],
      _CartaoQueRoda(cartao: c),
      const SizedBox(height: 8),
      Text('Toque no cartão para o virar', textAlign: TextAlign.center, style: tema.textTheme.bodySmall),
      const SizedBox(height: 16),
      if (!c.valido) ...[
        _Aviso(
          icone: Icons.info_outline_rounded,
          texto:
              'O cartão não está válido (${c.estadoLabel.toLowerCase()}). Para o regularizar, contacte a secretaria.',
          cor: const Color(0xFFB7791F),
        ),
        const SizedBox(height: 16),
      ],
      Bloco(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          children: [
            // Fundo branco em claro e em escuro: um QR invertido não lê em todos os leitores.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Tema.raioPequeno)),
              child: Opacity(
                opacity: c.valido ? 1 : 0.35,
                child: QrImageView(
                  data: c.qrConteudo,
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
            const SizedBox(height: 20),
            Text('Mostre este código à entrada', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Aumente o brilho do ecrã se o leitor tiver dificuldade.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];
  }
}

/// Proporção das imagens do cartão físico (`assets/images/card1.png`, `card2.png`).
const _proporcaoCartao = 1615 / 797;

/// A frente do cartão físico do clube, com os dados do sócio na zona livre.
/// Usado no início e no ecrã do cartão.
class CartaoVisual extends StatelessWidget {
  const CartaoVisual({
    super.key,
    required this.nome,
    required this.nrSocio,
    required this.estadoLabel,
    required this.valido,
    this.dataSocio,
    this.fotoUrl,
    this.onTap,
  });

  final String nome, estadoLabel;
  final int nrSocio;
  final bool valido;
  final DateTime? dataSocio;
  final String? fotoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final desde = dataSocio == null ? null : DateFormat('MM/yy').format(dataSocio!);

    return GestureDetector(
      onTap: onTap,
      child: _FundoCartao(
        imagem: 'assets/images/card1.png',
        // A altura é a da imagem: com a letra do sistema muito aumentada o texto
        // deixaria de caber. Dentro do cartão cresce no máximo 15%.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: LayoutBuilder(
            builder: (context, c) {
              // Tudo proporcional à largura: o cartão tem de ler bem de 280 a 430 px.
              final u = c.maxWidth / 360;
              final suave = Colors.white.withValues(alpha: 0.72);
              // Nomes compridos descem um pouco de tamanho antes de chegarem às reticências.
              final tamanhoNome = (nome.length > 34 ? 13.0 : 15.0) * u;

              return Padding(
                // À esquerda fica o emblema e o nome do clube, que já vêm na imagem.
                padding: EdgeInsets.fromLTRB(c.maxWidth * 0.19, 14 * u, 16 * u, 14 * u),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: _EstadoCartao(valido: valido, label: estadoLabel, escala: u),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (fotoUrl != null) ...[
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Avatar(nome: nome, url: fotoUrl, tamanho: 40 * u),
                          ),
                          SizedBox(width: 10 * u),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nome,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: tamanhoNome,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                                ),
                              ),
                              SizedBox(height: 4 * u),
                              // Uma linha só: encolhe em vez de passar para a seguinte.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'SÓCIO N.º ',
                                        style: TextStyle(color: suave),
                                      ),
                                      TextSpan(
                                        text: '$nrSocio',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                      if (desde != null)
                                        TextSpan(
                                          text: '   ·   DESDE $desde',
                                          style: TextStyle(color: suave),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 11 * u, letterSpacing: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Verso do cartão físico (banda e patrocinadores).
class _VersoCartao extends StatelessWidget {
  const _VersoCartao({required this.nrSocio});

  final int nrSocio;

  @override
  Widget build(BuildContext context) {
    return _FundoCartao(
      imagem: 'assets/images/card2.png',
      child: LayoutBuilder(
        builder: (context, c) {
          final u = c.maxWidth / 360;
          return Padding(
            // Por baixo da banda magnética, à esquerda do leão.
            padding: EdgeInsets.fromLTRB(20 * u, c.maxHeight * 0.36, 16 * u, 0),
            child: Text(
              'Cartão pessoal e intransmissível.\nSócio n.º $nrSocio',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11 * u, height: 1.5),
            ),
          );
        },
      ),
    );
  }
}

class _FundoCartao extends StatelessWidget {
  const _FundoCartao({required this.imagem, required this.child});

  final String imagem;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _proporcaoCartao,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Tema.raioPequeno),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(imagem, fit: BoxFit.cover),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Frente e verso, com a volta do cartão ao tocar.
class _CartaoQueRoda extends StatefulWidget {
  const _CartaoQueRoda({required this.cartao});

  final Cartao cartao;

  @override
  State<_CartaoQueRoda> createState() => _CartaoQueRodaState();
}

class _CartaoQueRodaState extends State<_CartaoQueRoda> {
  bool _verso = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cartao;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _verso ? 1 : 0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final aMostrarVerso = t > 0.5;
        final angulo = t * 3.14159265;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(aMostrarVerso ? angulo - 3.14159265 : angulo),
          child: GestureDetector(
            onTap: () => setState(() => _verso = !_verso),
            child: aMostrarVerso
                ? _VersoCartao(nrSocio: c.nrSocio)
                : CartaoVisual(
                    nome: c.nomeCompleto,
                    nrSocio: c.nrSocio,
                    estadoLabel: c.estadoLabel,
                    valido: c.valido,
                    dataSocio: c.dataSocio,
                    fotoUrl: c.fotoUrl,
                  ),
          ),
        );
      },
    );
  }
}

class _EstadoCartao extends StatelessWidget {
  const _EstadoCartao({required this.valido, required this.label, this.escala = 1});

  final bool valido;
  final String label;
  final double escala;

  @override
  Widget build(BuildContext context) {
    final cor = valido ? const Color(0xFF3DD68C) : const Color(0xFFFFB224);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * escala, vertical: 4 * escala),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7 * escala,
            height: 7 * escala,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          SizedBox(width: 5 * escala),
          Text(
            label,
            style: TextStyle(color: cor, fontSize: 11 * escala, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, required this.cor});

  final IconData icone;
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Tema.raioPequeno),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: cor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemCartao extends StatelessWidget {
  const _SemCartao();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const IconePastilha(Icons.credit_card_off_rounded),
          const SizedBox(height: 16),
          Text('Ainda não tem cartão digital', style: tema.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'O cartão é emitido pela secretaria. Contacte-a para o pedir.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
