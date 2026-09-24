import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/formatos.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../auth/auth_widgets.dart';
import 'assinatura.dart';
import 'inscricao.dart';

/// Uma inscrição de sócio, do pedido ao fim (§4.21).
///
/// O ecrã é conduzido **só** pelo `proximo_passo` que o servidor manda:
/// `aguardar` mostra a espera, `assinar` o quadro de assinatura (um documento
/// de cada vez), `pagar` a escolha dos meses e do método, `nada` o fim —
/// concluída, recusada ou cancelada. Um passo desconhecido mostra o
/// `estado_label` e nenhum botão.
class InscricaoPage extends ConsumerStatefulWidget {
  const InscricaoPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<InscricaoPage> createState() => _InscricaoPageState();
}

class _InscricaoPageState extends ConsumerState<InscricaoPage> {
  /// O pedido de pagamento feito neste ecrã. O `GET` da inscrição não o traz,
  /// por isso só se mostra enquanto o ecrã está aberto.
  PagamentoInscricao? _pagamento;

  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    // Voltou do MB WAY, do banco ou do email: pode ter mudado tudo.
    _ciclo = AppLifecycleListener(onResume: _actualizarEmSilencio);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  InscricaoController get _controlador => ref.read(inscricaoProvider(widget.id).notifier);

  Future<void> _actualizarEmSilencio() async {
    try {
      await _controlador.actualizar();
    } on ApiException {
      // Sem rede: fica o que está no ecrã, e tenta-se na próxima.
    }
  }

  Future<void> _desistir() async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Desistir da inscrição?'),
        content: const Text('O pedido é cancelado. Se mudar de ideias, pode fazer outro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Desistir')),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    final mensagens = ScaffoldMessenger.of(context);
    try {
      await _controlador.desistir();
    } on ApiException catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text(e.message)));
      if (e.erro == 'estado_invalido') _controlador.recarregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(inscricaoProvider(widget.id));
    final i = estado.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscrição de sócio'),
        actions: [
          if (i != null && i.podeDesistir)
            PopupMenuButton<void>(
              tooltip: 'Mais opções',
              itemBuilder: (_) => [PopupMenuItem(onTap: _desistir, child: const Text('Desistir da inscrição'))],
            ),
        ],
      ),
      body: switch (estado) {
        AsyncValue(:final InscricaoSocio value) => RefreshIndicator(
          onRefresh: _actualizarEmSilencio,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
            children: [
              _Cabecalho(value),
              if (_Etapas.indice(value) != null) ...[const SizedBox(height: AppSpacing.xl), _Etapas(value)],
              const SizedBox(height: AppSpacing.xl),
              ..._passo(value),
              if (value.assinados.isNotEmpty) ...[
                const TituloSeccao('Documentos assinados'),
                Bloco(
                  child: Column(
                    children: [for (final d in value.assinados) _LinhaPdf(inscricao: value, doc: d)],
                  ),
                ),
              ],
            ],
          ),
        ),
        AsyncValue(:final Object error) => ErroView(erro: error, tentarDeNovo: _controlador.recarregar),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  List<Widget> _passo(InscricaoSocio i) => switch (i.passo) {
    PassoInscricao.aguardar => [_Aguardar(i)],
    PassoInscricao.assinar => [
      if (i.nrSocio != null) ...[_NumeroReservado(i), const SizedBox(height: AppSpacing.lg)],
      _Assinar(i),
    ],
    PassoInscricao.pagar => [
      if (i.nrSocio != null) ...[_NumeroReservado(i), const SizedBox(height: AppSpacing.lg)],
      if (_pagamento case final p?)
        _Acompanhar(i, p, pedirOutro: () => setState(() => _pagamento = null))
      else
        _Pagar(i, aoPedir: (p) => setState(() => _pagamento = p)),
    ],
    PassoInscricao.nada => [_Fim(i)],
    PassoInscricao.desconhecido => [
      _Aviso(
        icone: Icons.info_outline_rounded,
        titulo: i.estadoLabel,
        texto: 'Não há nada a fazer por aqui de momento. Se tiver dúvidas, fale com a secretaria.',
        cor: AppColors.of(context).neutral,
      ),
    ],
  };
}

// ── Cabeçalho e etapas ─────────────────────────────────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.i);

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(i.nome, style: t.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtiquetaEstadoInscricao(i),
            if (i.paraDependente)
              Text('A seu cargo', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

/// O `estado_label` numa pastilha, com a cor do que ele quer dizer. Um estado
/// desconhecido fica neutro.
class EtiquetaEstadoInscricao extends StatelessWidget {
  const EtiquetaEstadoInscricao(this.i, {super.key});

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final cor = switch (i) {
      InscricaoSocio(concluida: true) => cores.success,
      InscricaoSocio(recusada: true) => cores.error,
      InscricaoSocio(passo: PassoInscricao.assinar || PassoInscricao.pagar) => cores.warning,
      InscricaoSocio(passo: PassoInscricao.aguardar) => cores.info,
      _ => cores.neutral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: ShapeDecoration(color: cor.container, shape: AppRadius.pill),
      child: Text(
        i.estadoLabel,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor.foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Pedido · Decisão · Assinar · Pagar. Lê-se do `proximo_passo`; nas saídas
/// (recusada, cancelada) e nos passos desconhecidos não aparece.
class _Etapas extends StatelessWidget {
  const _Etapas(this.i);

  final InscricaoSocio i;

  static const _nomes = ['Pedido', 'Decisão', 'Assinar', 'Pagar'];

  /// Quantas etapas estão feitas, ou `null` para não mostrar.
  static int? indice(InscricaoSocio i) => switch (i.passo) {
    PassoInscricao.aguardar => 1,
    PassoInscricao.assinar => 2,
    PassoInscricao.pagar => 3,
    PassoInscricao.nada when i.concluida => 4,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final feitas = indice(i)!;
    return Semantics(
      label: feitas == 4 ? 'Inscrição concluída' : 'Passo ${feitas + 1} de 4: ${_nomes[feitas]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var n = 0; n < _nomes.length; n++)
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: n < feitas
                          ? t.colorScheme.primary
                          : n == feitas
                          ? t.colorScheme.primary.withValues(alpha: 0.35)
                          : t.colorScheme.outlineVariant,
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _nomes[n],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: n == feitas ? t.colorScheme.onSurface : t.colorScheme.onSurfaceVariant,
                      fontWeight: n == feitas ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Aguardar ───────────────────────────────────────────────────────────────

class _Aguardar extends StatelessWidget {
  const _Aguardar(this.i);

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Aviso(
          icone: Icons.hourglass_top_rounded,
          titulo: 'O clube está a ver o pedido',
          texto:
              'Não há nada a fazer por agora. Quando o clube decidir, recebe um email '
              '— e, se for admitido, fica aqui o número de sócio e os documentos para assinar.',
          cor: AppColors.of(context).info,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ValorQuota(i.quotas),
      ],
    );
  }
}

/// A quota por mês. Antes da admissão (`firme: false`) é uma estimativa, e
/// diz-se: é o clube que confirma o escalão.
class _ValorQuota extends StatelessWidget {
  const _ValorQuota(this.q);

  final QuotasInscricao q;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final mes = q.valorMes;
    return Bloco(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quota', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text(mes != null ? '${euros(mes)} por mês' : euros(q.valor), style: t.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            q.firme
                ? 'Paga-se no início um mínimo de ${q.minimoMeses} meses.'
                : 'Valor estimado pela idade. Fica confirmado quando o clube admitir o pedido.',
            style: t.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── O número reservado ─────────────────────────────────────────────────────

class _NumeroReservado extends StatelessWidget {
  const _NumeroReservado(this.i);

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(gradient: cores.brandGradient, borderRadius: AppRadius.lgAll),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.concluida ? 'Número de sócio' : 'Admitido — número de sócio reservado',
                  style: t.textTheme.bodyMedium?.copyWith(color: cores.onBrandMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'N.º ${i.nrSocio}',
                  style: t.textTheme.headlineMedium?.copyWith(color: cores.onBrand, fontWeight: FontWeight.w800),
                ),
                if (!i.concluida) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'É o que vai impresso na ficha que assina.',
                    style: t.textTheme.bodySmall?.copyWith(color: cores.onBrandMuted),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.verified_rounded, color: cores.onBrand, size: 36),
        ],
      ),
    );
  }
}

// ── Assinar ────────────────────────────────────────────────────────────────

/// Um documento de cada vez, pela ordem de `por_assinar`. Depois de cada
/// assinatura, a inscrição que volta decide o que vem a seguir.
class _Assinar extends ConsumerStatefulWidget {
  const _Assinar(this.i);

  final InscricaoSocio i;

  @override
  ConsumerState<_Assinar> createState() => _AssinarState();
}

class _AssinarState extends ConsumerState<_Assinar> {
  final _tracos = TracosAssinatura();
  bool _aEnviar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _tracos.addListener(_mudou);
  }

  @override
  void didUpdateWidget(_Assinar antes) {
    super.didUpdateWidget(antes);
    // Outro documento: o quadro recomeça em branco.
    if (antes.i.proximoDocumento?.tipo != widget.i.proximoDocumento?.tipo) {
      _tracos.limpar();
      _erro = null;
    }
  }

  @override
  void dispose() {
    _tracos
      ..removeListener(_mudou)
      ..dispose();
    super.dispose();
  }

  void _mudou() => setState(() {});

  Future<void> _assinar(DocumentoInscricao doc) async {
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    final controlador = ref.read(inscricaoProvider(widget.i.id).notifier);
    try {
      final png = await _tracos.png();
      await controlador.assinar(doc.tipo, png);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${doc.nome} assinado.')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.message);
      // O estado mudou do lado do clube (ainda por admitir, ou já assinada):
      // o servidor sabe melhor.
      if (e.erro == 'estado_invalido') controlador.recarregar();
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final i = widget.i;
    final doc = i.proximoDocumento;
    final podeContratar = sessaoTem(ref.watch(sessaoProvider), Capacidade.contratar);
    if (doc == null) return const SizedBox.shrink();

    final total = i.documentos.isEmpty ? i.porAssinar.length : i.documentos.length;
    final numero = total - i.porAssinar.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          total > 1 ? 'Documento $numero de $total' : 'Documento a assinar',
          style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(doc.nome, style: t.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          i.paraDependente
              ? 'Assina o encarregado de educação. Recebe o documento em PDF, com o número de sócio, o nome e a hora.'
              : 'Assine com o dedo no quadro. Recebe o documento em PDF, com o número de sócio, o seu nome e a hora.',
          style: t.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!podeContratar)
          NotaPermissao(explicacaoPermissao('contratar'), padding: EdgeInsets.zero)
        else ...[
          QuadroAssinatura(tracos: _tracos),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _aEnviar || _tracos.vazia ? null : _tracos.limpar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Limpar'),
            ),
          ),
          if (_erro != null) ...[AvisoErro(_erro!), const SizedBox(height: AppSpacing.md)],
          FilledButton(
            onPressed: _aEnviar || _tracos.vazia ? null : () => _assinar(doc),
            child: _aEnviar ? const ProgressoBotao() : Text('Assinar ${doc.nome}'),
          ),
        ],
      ],
    );
  }
}

// ── Pagar ──────────────────────────────────────────────────────────────────

/// Os meses (entre `minimo_meses` e `maximo_meses`, com um contador) e o
/// método. **Não se envia valor nenhum**: o total é o da resposta.
class _Pagar extends ConsumerStatefulWidget {
  const _Pagar(this.i, {required this.aoPedir});

  final InscricaoSocio i;
  final ValueChanged<PagamentoInscricao> aoPedir;

  @override
  ConsumerState<_Pagar> createState() => _PagarState();
}

class _PagarState extends ConsumerState<_Pagar> {
  late int _meses = widget.i.quotas.minimoMeses;
  String _metodo = 'mbway';
  final _telefone = TextEditingController();
  bool _aEnviar = false;
  String? _erro;

  QuotasInscricao get _q => widget.i.quotas;

  bool get _telefoneValido => RegExp(r'^9\d{8}$').hasMatch(_telefone.text);

  @override
  void dispose() {
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _pedir() async {
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    final controlador = ref.read(inscricaoProvider(widget.i.id).notifier);
    try {
      final p = await controlador.pagar(
        meses: _meses,
        metodo: _metodo,
        telefone: _metodo == 'mbway' ? _telefone.text : null,
      );
      widget.aoPedir(p);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.message);
      if (e.erro == 'estado_invalido') controlador.recarregar();
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final podePagar = sessaoTem(ref.watch(sessaoProvider), Capacidade.pagar);
    final mes = _q.valorMes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pagar as primeiras quotas', style: t.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Documentos assinados. Falta pagar as quotas para a inscrição ficar concluída.',
          style: t.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!podePagar)
          NotaPermissao(explicacaoPermissao('pagar'), padding: EdgeInsets.zero)
        else ...[
          Bloco(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_meses meses', style: t.textTheme.titleMedium),
                          if (mes != null)
                            // Previsão para escolher; o total que conta é o da resposta.
                            Text('Previsto: ${euros(mes * _meses)}', style: t.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Menos um mês',
                      onPressed: _aEnviar || _meses <= _q.minimoMeses ? null : () => setState(() => _meses--),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filledTonal(
                      tooltip: 'Mais um mês',
                      onPressed: _aEnviar || _meses >= _q.maximoMeses ? null : () => setState(() => _meses++),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Entre ${_q.minimoMeses} e ${_q.maximoMeses} meses. O total é confirmado a seguir.',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Como quer pagar?', style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'mbway', label: Text('MB WAY'), icon: Icon(Icons.phone_iphone_rounded)),
              ButtonSegment(value: 'paybylink', label: Text('Multibanco'), icon: Icon(Icons.receipt_rounded)),
            ],
            selected: {_metodo},
            showSelectedIcon: false,
            onSelectionChanged: _aEnviar ? null : (s) => setState(() => _metodo = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_metodo == 'mbway')
            TextField(
              controller: _telefone,
              enabled: !_aEnviar,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: InputDecoration(
                labelText: 'Telemóvel MB WAY',
                prefixText: '+351 ',
                errorText: _telefone.text.isEmpty || _telefoneValido ? null : 'Telemóvel com 9 dígitos, começado por 9',
              ),
              onChanged: (_) => setState(() {}),
            )
          else
            Text(
              'Recebe uma referência Multibanco e um link para pagar por outros meios.',
              style: t.textTheme.bodySmall,
            ),
          if (_erro != null) ...[const SizedBox(height: AppSpacing.lg), AvisoErro(_erro!)],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _aEnviar || (_metodo == 'mbway' && !_telefoneValido) ? null : _pedir,
            child: _aEnviar
                ? const ProgressoBotao()
                : Text(_metodo == 'mbway' ? 'Enviar pedido MB WAY' : 'Gerar referência'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Se já pediu o pagamento, não precisa de pedir outro: a referência foi para o seu email.',
            style: t.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Depois de pedir o pagamento. **Um `201` não é pago**: a confirmação do
/// IfthenPay chega ao servidor mais tarde, por isso consulta-se a inscrição de
/// 5 em 5 segundos (e sempre que se volta à app) até ela ficar `concluida`.
class _Acompanhar extends ConsumerStatefulWidget {
  const _Acompanhar(this.i, this.p, {required this.pedirOutro});

  final InscricaoSocio i;
  final PagamentoInscricao p;
  final VoidCallback pedirOutro;

  @override
  ConsumerState<_Acompanhar> createState() => _AcompanharState();
}

class _AcompanharState extends ConsumerState<_Acompanhar> {
  static const _intervalo = Duration(seconds: 5);

  /// MB WAY: os 5 minutos que o pedido dura no telemóvel. Por referência,
  /// dois — quem paga no multibanco volta cá, ou recebe o email.
  late final DateTime _ate = DateTime.now().add(
    widget.p.mbway ? const Duration(minutes: 5, seconds: 30) : const Duration(minutes: 2),
  );
  Timer? _consulta;
  bool _aConsultar = false;

  @override
  void initState() {
    super.initState();
    _consulta = Timer.periodic(_intervalo, (_) {
      if (DateTime.now().isAfter(_ate)) {
        _consulta?.cancel();
        if (mounted) setState(() {});
        return;
      }
      _verificar();
    });
  }

  @override
  void dispose() {
    _consulta?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_aConsultar || !mounted) return;
    setState(() => _aConsultar = true);
    try {
      // Quando chega a `concluida`, o ecrã inteiro muda para o fim.
      await ref.read(inscricaoProvider(widget.i.id).notifier).actualizar();
    } on ApiException {
      // Sem rede tenta na próxima volta.
    } finally {
      if (mounted) setState(() => _aConsultar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final cores = AppColors.of(context);
    final aAcompanhar = _consulta?.isActive ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Aviso(
          icone: p.mbway ? Icons.phone_iphone_rounded : Icons.receipt_long_rounded,
          titulo: p.mbway ? 'Aprove no telemóvel' : 'Falta pagar',
          texto: p.mbway
              ? 'Abra a app MB WAY e confirme o pagamento. A inscrição fica concluída assim que ele for confirmado.'
              : 'Pague pelo link ou com a referência${p.limite == null ? '' : ' até ${dataCurta(p.limite!)}'}. '
                    'A inscrição fica concluída assim que o pagamento for confirmado — também lhe enviámos isto por email.',
          cor: cores.warning,
          aGirar: aAcompanhar,
        ),
        const SizedBox(height: AppSpacing.lg),
        Bloco(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              // O valor e o método são os da resposta: um MB WAY que falhe
              // cai para referência, e o total é o que o servidor calculou.
              _Linha('Total', euros(p.valor), destaque: true),
              _Linha('Meses', '${p.meses}'),
              _Linha('Método', p.metodoLegivel),
              if (p.telefone case final tel?) _Linha('Telemóvel', tel),
              if (p.referencia case final ref?) _Linha('N.º do pedido', '$ref'),
              if (p.limite case final limite?) _Linha('Pagar até', dataCurta(limite)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (p.temLink)
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(p.urlPagamento!), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir página de pagamento'),
          ),
        TextButton(onPressed: _aConsultar ? null : _verificar, child: const Text('Já paguei — verificar')),
        if (!aAcompanhar) TextButton(onPressed: widget.pedirOutro, child: const Text('Escolher outro método')),
      ],
    );
  }
}

// ── O fim ──────────────────────────────────────────────────────────────────

class _Fim extends ConsumerWidget {
  const _Fim(this.i);

  final InscricaoSocio i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);

    if (i.concluida) {
      final temFicha = ref.watch(sessaoProvider) is SessaoSocio;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (i.nrSocio != null) ...[_NumeroReservado(i), const SizedBox(height: AppSpacing.lg)],
          _Aviso(
            icone: Icons.check_circle_rounded,
            titulo: i.paraDependente ? '${primeiroNome(i.nome)} já é sócio' : 'Já é sócio',
            texto: i.paraDependente
                ? 'O pagamento entrou e a inscrição está concluída. Fica a seu cargo nesta conta.'
                : 'O pagamento entrou e a inscrição está concluída. A sua conta ficou ligada à ficha de sócio.',
            cor: cores.success,
          ),
          if (!i.paraDependente && temFicha) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: () => context.go('/socio'), child: const Text('Ir para a zona de sócio')),
          ],
        ],
      );
    }
    if (i.recusada) {
      return _Aviso(
        icone: Icons.cancel_rounded,
        titulo: 'O pedido não foi aceite',
        // O que a secretaria escreveu, tal e qual.
        texto: i.motivo ?? 'O clube não deu motivo. Se tiver dúvidas, fale com a secretaria.',
        cor: cores.error,
      );
    }
    if (i.cancelada) {
      return _Aviso(
        icone: Icons.block_rounded,
        titulo: 'Inscrição cancelada',
        texto: 'Este pedido já não está a decorrer. Se quiser, pode fazer outro.',
        cor: cores.neutral,
      );
    }
    // Outra saída que esta versão não conhece: o rótulo do servidor chega.
    return _Aviso(
      icone: Icons.info_outline_rounded,
      titulo: i.estadoLabel,
      texto: i.motivo ?? 'Esta inscrição já não precisa de nada da sua parte.',
      cor: cores.neutral,
    );
  }
}

// ── Peças ──────────────────────────────────────────────────────────────────

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.cor,
    this.aGirar = false,
  });

  final IconData icone;
  final String titulo, texto;
  final StatusColor cor;
  final bool aGirar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: cor.container, borderRadius: AppRadius.lgAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (aGirar) CircularProgressIndicator(strokeWidth: 2, color: cor.foreground.withValues(alpha: 0.5)),
                Icon(icone, color: cor.foreground, size: aGirar ? 16 : 24),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: t.textTheme.titleMedium?.copyWith(color: cor.foreground)),
                const SizedBox(height: AppSpacing.xs),
                Text(texto, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface)),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(width: AppSpacing.lg),
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

/// Um documento assinado: toca-se e abre o PDF na app do telemóvel, como os
/// documentos da zona de sócio.
class _LinhaPdf extends ConsumerStatefulWidget {
  const _LinhaPdf({required this.inscricao, required this.doc});

  final InscricaoSocio inscricao;
  final DocumentoInscricao doc;

  @override
  ConsumerState<_LinhaPdf> createState() => _LinhaPdfState();
}

class _LinhaPdfState extends ConsumerState<_LinhaPdf> {
  bool _aAbrir = false;

  Future<void> _abrir() async {
    setState(() => _aAbrir = true);
    final mensagens = ScaffoldMessenger.of(context);
    try {
      final ficheiro = await guardarPdfInscricao(ref.read(inscricoesApiProvider), widget.inscricao.id, widget.doc.tipo);
      final r = await OpenFilex.open(ficheiro.path, type: 'application/pdf');
      if (r.type == ResultType.noAppToOpen) {
        mensagens.showSnackBar(const SnackBar(content: Text('Não há nenhuma app para abrir PDFs neste telemóvel.')));
      }
    } on ApiException catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      mensagens.showSnackBar(const SnackBar(content: Text('Não foi possível abrir o documento.')));
    } finally {
      if (mounted) setState(() => _aAbrir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return ListTile(
      onTap: _aAbrir ? null : _abrir,
      leading: const IconePastilha(Icons.picture_as_pdf_rounded),
      title: Text(d.nome),
      subtitle: Text(
        [
          if (d.assinadoEm != null) 'assinado a ${dataCurta(d.assinadoEm!)}',
          if (d.assinante != null) d.assinante!,
        ].join(' · '),
      ),
      trailing: _aAbrir
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}
