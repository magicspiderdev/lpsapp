import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import 'dados.dart';
import 'modelos.dart';
import 'widgets.dart';

enum _Fase { aguardar, pago, expirado, cancelado }

/// Depois de pedir um pagamento: instruções e acompanhamento até ficar pago.
///
/// Um `201` não significa pago (guia §4.11): a confirmação chega quando o
/// IfthenPay avisa o servidor, por isso consulta-se de 5 em 5 s durante uns
/// minutos e outra vez sempre que se volta à app.
class ResultadoPagamentoPage extends ConsumerStatefulWidget {
  const ResultadoPagamentoPage({super.key, required this.resultado});

  final ResultadoPagamento resultado;

  @override
  ConsumerState<ResultadoPagamentoPage> createState() => _ResultadoPagamentoPageState();
}

class _ResultadoPagamentoPageState extends ConsumerState<ResultadoPagamentoPage> {
  static const _intervalo = Duration(seconds: 5);
  static const _duracaoAcompanhamento = Duration(minutes: 2);

  _Fase _fase = _Fase.aguardar;
  Timer? _consulta, _relogio;
  late DateTime _acompanharAte;
  late final AppLifecycleListener _ciclo;
  bool _aConsultar = false;

  ResultadoPagamento get r => widget.resultado;

  @override
  void initState() {
    super.initState();
    // MB WAY: acompanhar até o pedido expirar (e um pouco depois, pelo atraso do aviso).
    final fimMbway = r.mbway && r.expiraEm != null ? r.expiraEm!.add(const Duration(seconds: 30)) : null;
    final fimPadrao = DateTime.now().add(_duracaoAcompanhamento);
    _acompanharAte = fimMbway != null && fimMbway.isAfter(fimPadrao) ? fimMbway : fimPadrao;

    _consulta = Timer.periodic(_intervalo, (_) => _verificar());
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) => _tique());
    _ciclo = AppLifecycleListener(onResume: _verificar); // voltou do banco ou da app MB WAY
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _relogio?.cancel();
    _ciclo.dispose();
    super.dispose();
  }

  void _tique() {
    if (!mounted || _fase != _Fase.aguardar) return;
    final agora = DateTime.now();
    if (r.mbway && r.expiraEm != null && agora.isAfter(r.expiraEm!.add(const Duration(seconds: 30)))) {
      _verificar(ultima: true);
    }
    if (agora.isAfter(_acompanharAte)) _consulta?.cancel();
    setState(() {}); // contagem decrescente
  }

  Future<void> _verificar({bool ultima = false}) async {
    if (_aConsultar || _fase != _Fase.aguardar) return;
    _aConsultar = true;
    try {
      final p = await ref.read(pedidosNaContaProvider).estadoPagamento(r.idPagamento);
      if (!mounted || p == null) return;
      if (p.pago) {
        _terminar(_Fase.pago);
      } else if (p.estado == 'CANCELADO' || p.estado == 'ANULADO') {
        _terminar(_Fase.cancelado);
      } else if (ultima && r.mbway) {
        _terminar(_Fase.expirado);
      }
    } catch (_) {
      // Sem rede: tenta na próxima volta.
    } finally {
      _aConsultar = false;
    }
  }

  void _terminar(_Fase fase) {
    _consulta?.cancel();
    _relogio?.cancel();
    refrescarContas(ref);
    setState(() => _fase = fase);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [IconButton(onPressed: _fechar, icon: const Icon(Icons.close_rounded))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 8, Tema.margem + 4, 24),
          children: [
            _Icone(_fase, r),
            const SizedBox(height: 20),
            Text(_titulo, textAlign: TextAlign.center, style: t.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _explicacao,
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Bloco(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _Linha('Total', euros(r.total), destaque: true),
                  if (r.meses.isNotEmpty) _Linha('Meses', r.meses.join(', ')),
                  _Linha('Método', r.mbway ? 'MB WAY' : 'Referência / link'),
                  if (!r.mbway && r.limite != null) _Linha('Pagar até', dataCurta(r.limite!)),
                  if (r.referencia != null) _Linha('N.º do pedido', r.referencia!),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_fase == _Fase.aguardar && r.temLink)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(r.urlPagamento!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir página de pagamento'),
              ),
            if (_fase == _Fase.aguardar)
              TextButton(onPressed: _aConsultar ? null : _verificar, child: const Text('Já paguei — verificar')),
            if (_fase != _Fase.aguardar) FilledButton(onPressed: _fechar, child: const Text('Concluir')),
          ],
        ),
      ),
    );
  }

  String get _titulo => switch (_fase) {
    _Fase.pago => 'Pagamento recebido',
    _Fase.cancelado => 'Pagamento cancelado',
    _Fase.expirado => 'O pedido MB WAY expirou',
    _Fase.aguardar when r.mbway => 'Aprove no telemóvel',
    _Fase.aguardar => r.reutilizado ? 'Já tinha um pagamento criado' : 'Referência criada',
  };

  String get _explicacao {
    switch (_fase) {
      case _Fase.pago:
        return 'Obrigado. A conta já está actualizada.';
      case _Fase.cancelado:
        return 'Este pagamento já não é válido. Pode criar um novo.';
      case _Fase.expirado:
        return 'Não foi aprovado a tempo. Se aprovou mesmo assim, a confirmação pode demorar; caso contrário, faça um novo pedido.';
      case _Fase.aguardar:
        if (r.mbway) {
          final falta = r.expiraEm?.difference(DateTime.now());
          final tempo = falta == null || falta.isNegative
              ? ''
              : ' Tem ${falta.inMinutes}:${(falta.inSeconds % 60).toString().padLeft(2, '0')} para aprovar.';
          return '${r.reutilizado ? 'O pedido já tinha sido enviado. ' : ''}Abra a app MB WAY e confirme o pagamento.$tempo';
        }
        return 'Pague pelo link ou com a referência até à data limite. A confirmação aparece aqui quando o banco a enviar.';
    }
  }

  void _fechar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/socio');
    }
  }
}

class _Icone extends StatelessWidget {
  const _Icone(this.fase, this.r);

  final _Fase fase;
  final ResultadoPagamento r;

  @override
  Widget build(BuildContext context) {
    final (icone, cor) = switch (fase) {
      _Fase.pago => (Icons.check_rounded, CoresEstado.pago),
      _Fase.cancelado || _Fase.expirado => (Icons.close_rounded, Theme.of(context).colorScheme.onSurfaceVariant),
      _Fase.aguardar => (r.mbway ? Icons.phone_iphone_rounded : Icons.receipt_long_rounded, CoresEstado.aguardar),
    };
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (fase == _Fase.aguardar)
            SizedBox.square(
              dimension: 104,
              child: CircularProgressIndicator(strokeWidth: 3, color: cor.withValues(alpha: 0.5)),
            ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icone, size: 44, color: cor),
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor, {this.destaque = false});

  final String rotulo, valor;
  final bool destaque;

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
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: destaque ? t.textTheme.titleMedium : t.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
