import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../../core/widgets/erro_view.dart';
import '../publico/clube/clube.dart' show clubeProvider, Modalidade;
import 'modalidades_pedidos.dart';
import 'modalidades_widgets.dart';

/// Pedir a inscrição ou a baixa numa modalidade (guia §4.22.2–3).
///
/// Escolhe-se **quem** (de `atletas`), **o quê** (o `slug` da lista pública do
/// clube), o tipo e, se se quiser, umas observações para quem decide. Nada se
/// envia sem confirmar, e nada aqui é pagamento.
class PedirModalidadePage extends ConsumerStatefulWidget {
  const PedirModalidadePage({super.key, this.modalidade, this.tipo});

  /// Já escolhida (da página da modalidade, por exemplo).
  final String? modalidade;

  /// `inscricao` ou `baixa`. Outra coisa conta como inscrição.
  final String? tipo;

  @override
  ConsumerState<PedirModalidadePage> createState() => _PedirModalidadePageState();
}

class _PedirModalidadePageState extends ConsumerState<PedirModalidadePage> {
  late String _tipo = widget.tipo == TipoPedido.baixa ? TipoPedido.baixa : TipoPedido.inscricao;
  late String? _slug = widget.modalidade;
  int? _nrSocio;
  final _observacoes = TextEditingController();
  bool _aEnviar = false;
  ApiException? _erro;

  @override
  void dispose() {
    _observacoes.dispose();
    super.dispose();
  }

  /// O atleta escolhido, se ainda puder ser escolhido para o tipo actual.
  AtletaElegivel? _atleta(List<AtletaElegivel> atletas) {
    final escolhido = atletas.where((a) => a.nrSocio == _nrSocio && a.podePara(_tipo)).firstOrNull;
    if (escolhido != null) return escolhido;
    // Sem escolha: o primeiro que pode (é o próprio, quando pode).
    return atletas.where((a) => a.podePara(_tipo)).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider);
    final pedidos = ref.watch(pedidosModalidadesProvider);
    final clube = ref.watch(clubeProvider);

    final Widget corpo;
    if (!sessaoTem(sessao, Capacidade.contratar)) {
      corpo = ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [NotaPermissao(explicacaoPermissao('contratar'), padding: EdgeInsets.zero)],
      );
    } else {
      // Pelo valor, e não pelo estado: ao recarregar os atletas (depois de um
      // `socio_nao_associado`) o formulário fica, com o erro à vista.
      corpo = switch ((pedidos.valueOrNull, clube.valueOrNull, pedidos, clube)) {
        (final p?, final c?, _, _) => _formulario(context, p.valor.atletas, [
          for (final m in c.valor.modalidades)
            if (m.slug != null) m,
        ]),
        (_, _, AsyncError(:final error), _) => ErroView(
          erro: error,
          tentarDeNovo: () => ref.invalidate(pedidosModalidadesProvider),
        ),
        (_, _, _, AsyncError(:final error)) => ErroView(erro: error, tentarDeNovo: () => ref.invalidate(clubeProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pedir modalidade')),
      body: corpo,
    );
  }

  Widget _formulario(BuildContext context, List<AtletaElegivel> atletas, List<Modalidade> modalidades) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);

    if (atletas.isEmpty) {
      return ListView(padding: const EdgeInsets.all(AppSpacing.screen), children: const [BlocoFazerSeSocio()]);
    }

    final atleta = _atleta(atletas);
    final slug = modalidades.any((m) => m.slug == _slug) ? _slug : null;
    final pronto = atleta != null && slug != null && !_aEnviar;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xxl),
      children: [
        // ── O quê ──
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: TipoPedido.inscricao, label: Text('Inscrição'), icon: Icon(Icons.login_rounded)),
            ButtonSegment(value: TipoPedido.baixa, label: Text('Baixa'), icon: Icon(Icons.logout_rounded)),
          ],
          selected: {_tipo},
          onSelectionChanged: _aEnviar ? null : (s) => setState(() => _tipo = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        _tipo == TipoPedido.baixa
            ? AvisoPedido(texto: textoBaixaNadaFecha, cor: cores.warning, icone: Icons.schedule_rounded)
            : AvisoPedido(texto: textoInscricaoPedido, cor: cores.info),

        // ── Quem ──
        const TituloSeccao('Atleta'),
        Bloco(
          child: RadioGroup<int>(
            groupValue: atleta?.nrSocio,
            onChanged: (n) => _aEnviar || n == null ? null : setState(() => _nrSocio = n),
            child: Column(
              children: [
                for (final a in atletas)
                  RadioListTile<int>(
                    value: a.nrSocio,
                    enabled: a.podePara(_tipo) && !_aEnviar,
                    title: Text(a.nome),
                    subtitle: Text(
                      [a.descricao, if (!a.podePara(_tipo) && a.porqueNao != null) a.porqueNao!].join('\n'),
                    ),
                    isThreeLine: !a.podePara(_tipo) && a.porqueNao != null,
                  ),
              ],
            ),
          ),
        ),

        // ── Modalidade ──
        const TituloSeccao('Modalidade'),
        if (modalidades.isEmpty)
          Text(
            'Não foi possível obter a lista de modalidades do clube.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
          )
        else
          DropdownButtonFormField<String>(
            // Muda de chave quando a lista chega, para o valor inicial valer.
            key: ValueKey('modalidade-${modalidades.length}'),
            initialValue: slug,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Escolha a modalidade'),
            items: [
              for (final m in modalidades)
                DropdownMenuItem(
                  value: m.slug,
                  child: Text(m.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _aEnviar ? null : (s) => setState(() => _slug = s),
          ),

        // ── Observações ──
        const TituloSeccao('Observações (opcional)'),
        TextField(
          controller: _observacoes,
          enabled: !_aEnviar,
          maxLength: maxObservacoes,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: _tipo == TipoPedido.baixa
                ? 'Por exemplo: a partir de quando, ou material a devolver.'
                : 'Por exemplo: experiência, horários possíveis.',
            helperText: 'Quem lê é a secretaria.',
          ),
        ),

        if (_erro case final e?) ...[
          const SizedBox(height: AppSpacing.md),
          if (e.erro == 'conta_sem_socio')
            BlocoFazerSeSocio(texto: e.message)
          else
            AvisoPedido(texto: e.message, cor: cores.error, icone: Icons.error_outline_rounded),
        ],

        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: pronto ? () => _confirmarEEnviar(atleta, modalidades.firstWhere((m) => m.slug == slug)) : null,
          child: _aEnviar
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_tipo == TipoPedido.baixa ? 'Pedir a baixa' : 'Pedir a inscrição'),
        ),
        if (!pronto && !_aEnviar) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            atleta == null ? 'Nenhum atleta pode ser escolhido.' : 'Escolha a modalidade para continuar.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmarEEnviar(AtletaElegivel atleta, Modalidade modalidade) async {
    final baixa = _tipo == TipoPedido.baixa;
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baixa ? 'Pedir a baixa?' : 'Pedir a inscrição?'),
        content: Text(
          baixa
              ? 'Pedir a baixa de ${atleta.nome} em ${modalidade.nome}.\n\n$textoBaixaNadaFecha'
              : 'Pedir a inscrição de ${atleta.nome} em ${modalidade.nome}.\n\n$textoInscricaoPedido',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar pedido')),
        ],
      ),
    );
    if (sim != true || !mounted) return;

    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      final pedido = await ref
          .read(accoesModalidadesProvider)
          .pedir(modalidade: modalidade.slug!, tipo: _tipo, nrSocio: atleta.nrSocio, observacoes: _observacoes.text);
      ref.invalidate(pedidosModalidadesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado.')));
      context.pushReplacement(RotasModalidades.pedido(pedido.id), extra: pedido);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.erro) {
        // Já há um por decidir: abre-se esse, em vez de recomeçar.
        case 'ja_existe' when e.dados['id'] != null:
          ref.invalidate(pedidosModalidadesProvider);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          context.pushReplacement(RotasModalidades.pedido('${e.dados['id']}'));
          return;
        // O atleta deixou de estar a cargo: a lista de quem se pode escolher mudou.
        case 'socio_nao_associado':
          _nrSocio = null;
          ref.invalidate(pedidosModalidadesProvider);
        // `menor_de_idade`, `conta_sem_socio` e o resto: a `message` vem pronta.
        default:
          break;
      }
      setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }
}
