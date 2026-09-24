import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import 'bilheteira.dart';
import 'compra.dart';

/// Depois de pedir bilhetes: o que falta fazer, até eles existirem.
///
/// **Um `201` não significa pago** (§4.18, a mesma regra das quotas): a
/// confirmação do IfthenPay chega ao servidor mais tarde, por isso consulta-se
/// `GET /me/bilhetes/encomendas/{id}` de 5 em 5 segundos e outra vez sempre que
/// se volta à app — de onde se pagou. Quando fica `paga`, vêm os bilhetes e
/// mostram-se aqui.
///
/// Uma zona gratuita já chega `paga` e com bilhetes: este ecrã é então só a
/// confirmação, sem consultas nenhumas.
class EncomendaPage extends ConsumerStatefulWidget {
  const EncomendaPage({super.key, required this.id, this.inicial});

  final String id;

  /// O que o `POST` devolveu. Por link não vem nada e pede-se ao servidor.
  final Compra? inicial;

  @override
  ConsumerState<EncomendaPage> createState() => _EncomendaPageState();
}

class _EncomendaPageState extends ConsumerState<EncomendaPage> {
  static const _intervalo = Duration(seconds: 5);
  static const _minimoAcompanhamento = Duration(minutes: 2);

  Compra? _compra;
  ApiException? _erro;
  Timer? _consulta, _relogio;
  late DateTime _acompanharAte;
  late final AppLifecycleListener _ciclo;
  bool _aConsultar = false;

  Encomenda? get _e => _compra?.encomenda;
  PagamentoBilhetes? get _p => _compra?.pagamento;

  /// Ainda há alguma coisa a acontecer? Uma encomenda paga, cancelada ou
  /// desistida já não muda sozinha.
  bool get _aguardar => _e == null || _e!.pendente || _e!.expirada;

  @override
  void initState() {
    super.initState();
    _compra = widget.inicial;
    _acompanharAte = _ateQuandoAcompanhar();
    _ciclo = AppLifecycleListener(onResume: _verificar); // voltou do MB WAY ou do banco
    if (_compra == null) {
      _verificar();
    }
    if (_aguardar) {
      _consulta = Timer.periodic(_intervalo, (_) => _verificar());
      _relogio = Timer.periodic(const Duration(seconds: 1), (_) => _tique());
    }
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _relogio?.cancel();
    _ciclo.dispose();
    super.dispose();
  }

  /// MB WAY: até o pedido expirar (e um pouco depois, pelo atraso do aviso).
  /// Nos outros casos, dois minutos — quem pagou por referência volta cá.
  DateTime _ateQuandoAcompanhar() {
    final minimo = DateTime.now().add(_minimoAcompanhamento);
    final fim = _p?.mbway == true ? _p?.expiraEm?.add(const Duration(seconds: 30)) : null;
    return fim != null && fim.isAfter(minimo) ? fim : minimo;
  }

  void _tique() {
    if (!mounted) return;
    if (!_aguardar || DateTime.now().isAfter(_acompanharAte)) {
      _consulta?.cancel();
      _relogio?.cancel();
    }
    setState(() {}); // contagem decrescente
  }

  Future<void> _verificar() async {
    if (_aConsultar || !mounted) return;
    _aConsultar = true;
    try {
      final compra = await ref.read(bilheteiraProvider).estado(widget.id);
      if (!mounted) return;
      final ficouPaga = _e?.paga != true && compra.encomenda.paga;
      setState(() {
        _compra = compra;
        _erro = null;
      });
      if (ficouPaga) {
        ref.invalidate(meusBilhetesProvider);
        _consulta?.cancel();
        _relogio?.cancel();
      }
    } on ApiException catch (e) {
      // Sem rede tenta na próxima volta; sem nada para mostrar, mostra o erro.
      if (mounted && _compra == null) setState(() => _erro = e);
    } finally {
      _aConsultar = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = _e;

    if (e == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compra')),
        body: _erro == null
            ? const Center(child: CircularProgressIndicator())
            : ErroView(erro: _erro!, tentarDeNovo: _verificar),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [IconButton(tooltip: 'Fechar', onPressed: _fechar, icon: const Icon(Icons.close_rounded))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 8, Tema.margem + 4, 32),
          children: [
            _Icone(e, _p),
            const SizedBox(height: 20),
            Text(_titulo(e), textAlign: TextAlign.center, style: t.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _explicacao(e),
              textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Bloco(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (e.titulo case final titulo?) _Linha('Sessão', titulo),
                  if (e.inicio case final inicio?)
                    _Linha('Quando', DateFormat("d 'de' MMMM 'às' HH:mm", 'pt_PT').format(inicio)),
                  if (e.zona case final zona?) _Linha('Zona', zona),
                  _Linha('Bilhetes', '${e.quantidade}'),
                  // O total é o que o servidor devolveu, nunca uma conta feita cá.
                  _Linha('Total', e.total == 0 ? 'Grátis' : euros(e.total), destaque: true),
                  // O método que vale é o da resposta: um MB WAY que falha no
                  // IfthenPay cai para referência.
                  if (_metodoLegivel(e, _p) case final metodo?) _Linha('Método', metodo),
                  if (_p?.referencia case final ref?) _Linha('N.º do pedido', '$ref'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (e.pendente && _p?.temLink == true)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(_p!.urlPagamento!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir página de pagamento'),
              ),
            if (_aguardar)
              TextButton(onPressed: _aConsultar ? null : _verificar, child: const Text('Já paguei — verificar')),
            if (e.bilhetes.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: () => context.go('/bilhetes/meus'),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text(e.bilhetes.length == 1 ? 'Ver o bilhete' : 'Ver os ${e.bilhetes.length} bilhetes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Estão guardados no telemóvel e abrem sem rede — o pavilhão nem sempre tem.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall,
              ),
            ],
            if (!_aguardar && e.bilhetes.isEmpty)
              FilledButton(onPressed: _fechar, child: const Text('Concluir')),
          ],
        ),
      ),
    );
  }

  String _titulo(Encomenda e) => switch (e) {
    Encomenda(paga: true) => e.quantidade == 1 ? 'Bilhete emitido' : 'Bilhetes emitidos',
    Encomenda(cancelada: true) => 'Compra cancelada',
    Encomenda(expirada: true) => 'O tempo para pagar acabou',
    _ when _p?.mbway == true => 'Aprove no telemóvel',
    _ => 'Falta pagar',
  };

  String _explicacao(Encomenda e) {
    if (e.paga) return 'Já estão na sua carteira, prontos para a entrada.';
    if (e.cancelada) return 'Os lugares voltaram à venda. Pode comprar de novo.';
    if (e.expirada) {
      // Não se diz "perdeu a compra": um pagamento que chegue tarde é aceite.
      return 'Os lugares deixaram de estar guardados. Se pagou entretanto, os '
          'bilhetes aparecem na mesma — senão, faça uma compra nova.';
    }
    if (_p?.mbway == true) {
      final falta = _p?.expiraEm?.difference(DateTime.now());
      final tempo = falta == null || falta.isNegative
          ? ''
          : ' Tem ${falta.inMinutes}:${(falta.inSeconds % 60).toString().padLeft(2, '0')} para aprovar.';
      return 'Abra a app MB WAY e confirme o pagamento.$tempo';
    }
    final ate = e.expiraEm ?? _p?.expiraEm;
    return 'Pague pelo link ou com a referência${ate == null ? '' : ' até ${dataCurta(ate)}'}. '
        'Os bilhetes são emitidos assim que o pagamento for confirmado.';
  }

  static String? _metodoLegivel(Encomenda e, PagamentoBilhetes? p) => switch (p?.metodo ?? e.metodo) {
    'gratis' => 'Gratuito',
    'mbway' => 'MB WAY',
    'paybylink' => 'Referência / link',
    _ => null,
  };

  void _fechar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/bilhetes');
    }
  }
}

class _Icone extends StatelessWidget {
  const _Icone(this.e, this.p);

  final Encomenda e;
  final PagamentoBilhetes? p;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final (icone, cor) = switch (e) {
      Encomenda(paga: true) => (Icons.confirmation_number_rounded, cores.success.foreground),
      Encomenda(cancelada: true) || Encomenda(expirada: true) => (
        Icons.close_rounded,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      _ => (p?.mbway == true ? Icons.phone_iphone_rounded : Icons.receipt_long_rounded, cores.warning.foreground),
    };
    final aguardar = e.pendente;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (aguardar)
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
