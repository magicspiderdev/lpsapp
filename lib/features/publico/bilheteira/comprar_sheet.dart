import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../auth/auth_widgets.dart';
import 'bilheteira.dart';
import 'compra.dart';

/// Confirmar a compra de uma zona: quantos, quanto, e como pagar.
///
/// A folha só aparece depois de haver conta e de a zona deixar comprar — as
/// portas de entrada (`entrar`, `associar ficha`, `comprar fora da app`) são
/// decididas no ecrã da sessão, antes de chegar aqui.
///
/// **Numa zona gratuita não há nada para pagar**: não se pergunta o método nem
/// o telemóvel, e a compra fica feita numa chamada (§4.18).
Future<void> mostrarComprar(
  BuildContext context, {
  required Sessao sessao,
  required Zona zona,
  required int quantidade,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
  builder: (_) => _ComprarSheet(sessao: sessao, zona: zona, quantidade: quantidade),
);

class _ComprarSheet extends ConsumerStatefulWidget {
  const _ComprarSheet({required this.sessao, required this.zona, required this.quantidade});

  final Sessao sessao;
  final Zona zona;
  final int quantidade;

  @override
  ConsumerState<_ComprarSheet> createState() => _ComprarSheetState();
}

class _ComprarSheetState extends ConsumerState<_ComprarSheet> {
  String _metodo = 'mbway';
  final _telefone = TextEditingController();
  bool _aEnviar = false;
  String? _erro;

  /// `409 venda_externa`: o sítio onde esta zona se compra mesmo.
  String? _urlCompra;

  /// `409 limite_bilhetes` / `esgotado`: quantos ainda dá para levar.
  int? _restantes;

  /// `403 conta_sem_socio`: a compra precisa de ficha de sócio.
  bool _precisaDeSocio = false;

  Zona get z => widget.zona;
  double get _total => z.preco * widget.quantidade;

  @override
  void dispose() {
    _telefone.dispose();
    super.dispose();
  }

  /// Em branco é válido: sem telemóvel, o servidor usa o da ficha (§4.18).
  bool get _telefoneValido => _telefone.text.isEmpty || RegExp(r'^9\d{8}$').hasMatch(_telefone.text);

  Future<void> _confirmar() async {
    setState(() {
      _aEnviar = true;
      _erro = null;
      _urlCompra = null;
      _restantes = null;
      _precisaDeSocio = false;
    });

    try {
      final compra = await ref.read(bilheteiraProvider).comprar(
        sessao: widget.sessao.id,
        zona: z.id,
        quantidade: widget.quantidade,
        // Numa gratuita o método é ignorado: não se manda nenhum.
        metodo: z.gratuita ? null : _metodo,
        telefone: z.gratuita || _metodo != 'mbway' ? null : _telefone.text,
      );
      if (!mounted) return;
      // A carteira ganhou bilhetes (ou vai ganhar): volta a pedi-la.
      ref.invalidate(meusBilhetesProvider);
      ref.invalidate(sessaoProvider(widget.sessao.id));
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/bilhetes/encomenda/${compra.encomenda.id}', extra: compra);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.message;
        _urlCompra = e.dados['url_compra'] as String?;
        _restantes = (e.dados['restantes'] as num?)?.toInt();
        _precisaDeSocio = e.erro == 'conta_sem_socio';
      });
      // A sessão mudou debaixo dos pés: o ecrã de trás tem de saber.
      if (e.erro == 'venda_fechada' || e.erro == 'esgotado') {
        ref.invalidate(sessaoProvider(widget.sessao.id));
        ref.invalidate(sessoesProvider);
      }
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = widget.quantidade;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 0, Tema.margem + 4, Tema.margem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(z.gratuita ? 'Levantar bilhetes' : 'Comprar bilhetes', style: t.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('$n ${n == 1 ? 'bilhete' : 'bilhetes'} · ${z.nome}', style: t.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text(
                z.gratuita ? 'Grátis' : euros(_total),
                style: t.textTheme.displaySmall?.copyWith(fontSize: 40),
              ),
              if (!z.gratuita) ...[
                const SizedBox(height: 20),
                Text('Como quer pagar?', style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mbway', label: Text('MB WAY'), icon: Icon(Icons.phone_iphone_rounded)),
                    ButtonSegment(value: 'paybylink', label: Text('Referência'), icon: Icon(Icons.receipt_rounded)),
                  ],
                  selected: {_metodo},
                  showSelectedIcon: false,
                  onSelectionChanged: _aEnviar ? null : (s) => setState(() => _metodo = s.first),
                ),
                const SizedBox(height: 12),
                if (_metodo == 'mbway')
                  TextField(
                    controller: _telefone,
                    enabled: !_aEnviar,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                    decoration: InputDecoration(
                      labelText: 'Telemóvel MB WAY',
                      prefixText: '+351 ',
                      helperText: 'Em branco, vai para o telemóvel da sua ficha.',
                      errorText: _telefoneValido ? null : 'Telemóvel com 9 dígitos, começado por 9',
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                else
                  Text(
                    'Recebe uma referência Multibanco e um link para pagar por cartão ou outros meios. '
                    'Os lugares ficam guardados até pagar.',
                    style: t.textTheme.bodySmall,
                  ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Não há nada a pagar: os bilhetes ficam já na sua carteira.',
                  style: t.textTheme.bodySmall,
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 16),
                AvisoErro(_restantes == null ? _erro! : '$_erro (ainda pode levar $_restantes)'),
                if (_precisaDeSocio)
                  TextButton(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push('/associar-socio?voltar=/bilhetes/${widget.sessao.id}');
                    },
                    child: const Text('Associar a minha ficha de sócio'),
                  ),
                if (_urlCompra case final url?)
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    child: const Text('Comprar no site da bilheteira'),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _aEnviar || !_telefoneValido ? null : _confirmar,
                child: _aEnviar
                    ? const ProgressoBotao()
                    : Text(switch ((z.gratuita, _metodo)) {
                        (true, _) => 'Levantar $n ${n == 1 ? 'bilhete' : 'bilhetes'}',
                        (_, 'mbway') => 'Enviar pedido MB WAY',
                        _ => 'Gerar referência',
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
