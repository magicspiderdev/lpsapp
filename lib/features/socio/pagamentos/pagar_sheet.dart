import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../auth/auth_widgets.dart';
import '../inicio_page.dart';
import 'dados.dart';
import 'modelos.dart';

/// O que se vai pagar: quotas (escolhendo quantos meses) ou uma fatura.
sealed class AlvoPagamento {
  const AlvoPagamento();
}

class PagarQuotas extends AlvoPagamento {
  final Quotas quotas;
  const PagarQuotas(this.quotas);
}

class PagarFatura extends AlvoPagamento {
  final Fatura fatura;
  const PagarFatura(this.fatura);
}

Future<void> mostrarPagarQuotas(BuildContext context, Quotas q) => _mostrar(context, PagarQuotas(q));

Future<void> mostrarPagarFatura(BuildContext context, Fatura f) => _mostrar(context, PagarFatura(f));

Future<void> _mostrar(BuildContext context, AlvoPagamento alvo) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
  builder: (_) => _PagarSheet(alvo),
);

class _PagarSheet extends ConsumerStatefulWidget {
  const _PagarSheet(this.alvo);

  final AlvoPagamento alvo;

  @override
  ConsumerState<_PagarSheet> createState() => _PagarSheetState();
}

class _PagarSheetState extends ConsumerState<_PagarSheet> {
  late int _meses;
  String _metodo = 'mbway';
  final _telefone = TextEditingController();
  bool _aEnviar = false;
  String? _erro;

  /// `409 fatura_acumulada`: a fatura a pagar é outra.
  int? _faturaActual;

  @override
  void initState() {
    super.initState();
    if (widget.alvo case PagarQuotas(:final quotas)) {
      _meses = quotas.minimoPagamento.clamp(1, quotas.selecionaveis.length);
    }
    final tel = ref.read(resumoProvider).valueOrNull?.valor.telefone ?? '';
    _telefone.text = tel.length > 9 ? tel.substring(tel.length - 9) : tel;
  }

  @override
  void dispose() {
    _telefone.dispose();
    super.dispose();
  }

  bool get _telefoneValido => RegExp(r'^9\d{8}$').hasMatch(_telefone.text);

  Future<void> _confirmar() async {
    setState(() {
      _aEnviar = true;
      _erro = null;
      _faturaActual = null;
    });
    final pedidos = ref.read(pedidosNaContaProvider);
    final telefone = _metodo == 'mbway' ? _telefone.text : null;
    try {
      final r = switch (widget.alvo) {
        PagarQuotas() => await pedidos.pagarQuotas(quantidade: _meses, metodo: _metodo, telefone: telefone),
        PagarFatura(:final fatura) => await pedidos.pagarFatura(fatura.id, metodo: _metodo, telefone: telefone),
      };
      if (!mounted) return;
      refrescarContas(ref);
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/socio/pagamento', extra: r);
    } on ApiException catch (e) {
      setState(() {
        _erro = e.message;
        if (e.erro == 'fatura_acumulada') _faturaActual = e.dados['id_fatura_atual'] as int?;
      });
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final alvo = widget.alvo;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 0, Tema.margem + 4, Tema.margem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (alvo) {
                PagarQuotas() => 'Pagar quotas',
                PagarFatura(:final fatura) => 'Pagar ${fatura.mesLabel}',
              }, style: t.textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (alvo case PagarQuotas(:final quotas)) ..._quantidade(t, quotas),
              if (alvo case PagarFatura(:final fatura))
                _valor(t, fatura.emFalta > 0 ? fatura.emFalta : fatura.valorTotal),
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
                    errorText: _telefone.text.isEmpty || _telefoneValido
                        ? null
                        : 'Telemóvel com 9 dígitos, começado por 9',
                  ),
                  onChanged: (_) => setState(() {}),
                )
              else
                Text(
                  'Recebe uma referência Multibanco e um link para pagar por cartão ou outros meios.',
                  style: t.textTheme.bodySmall,
                ),
              if (_erro != null) ...[
                const SizedBox(height: 16),
                AvisoErro(_erro!),
                if (_faturaActual != null)
                  TextButton(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.push('/socio/faturas/$_faturaActual');
                    },
                    child: const Text('Abrir a fatura a pagar'),
                  ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _aEnviar || (_metodo == 'mbway' && !_telefoneValido) ? null : _confirmar,
                child: _aEnviar
                    ? const ProgressoBotao()
                    : Text(_metodo == 'mbway' ? 'Enviar pedido MB WAY' : 'Gerar referência'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valor(ThemeData t, double valor, {String? nota}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(euros(valor), style: t.textTheme.displaySmall?.copyWith(fontSize: 40)),
      if (nota != null) Text(nota, style: t.textTheme.bodySmall),
    ],
  );

  List<Widget> _quantidade(ThemeData t, Quotas q) {
    final max = q.selecionaveis.length;
    final min = q.minimoPagamento.clamp(1, max);
    final escolhidos = q.selecionaveis.take(_meses).toList();
    // Previsão a partir da caderneta; o total que conta é o que o servidor devolver.
    final previsto = escolhidos.fold<double>(0, (s, m) => s + (m.valor ?? 0));

    return [
      _valor(t, previsto, nota: 'Valor previsto — o total é confirmado a seguir.'),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_meses ${_meses == 1 ? 'mês' : 'meses'}', style: t.textTheme.titleMedium),
                if (escolhidos.isNotEmpty)
                  Text(
                    escolhidos.length == 1
                        ? escolhidos.first.mesLabel
                        : '${escolhidos.first.mesLabel} a ${escolhidos.last.mesLabel}',
                    style: t.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _aEnviar || _meses <= min ? null : () => setState(() => _meses--),
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _aEnviar || _meses >= max ? null : () => setState(() => _meses++),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      if (min > 1)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Mínimo de $min meses por pagamento.', style: t.textTheme.bodySmall),
        ),
      if (q.ordensPendentes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFB7791F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Tema.raioPequeno),
          ),
          child: Text(
            q.ordensPendentes.length == 1
                ? 'Tem um pagamento de quotas por concluir. Ao criar um novo, esse deixa de valer.'
                : 'Tem ${q.ordensPendentes.length} pagamentos de quotas por concluir. Ao criar um novo, esses deixam de valer.',
            style: const TextStyle(color: Color(0xFF8A5A12), fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ];
  }
}
