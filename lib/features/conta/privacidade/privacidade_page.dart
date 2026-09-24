import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'consentimentos.dart';

/// Privacidade (§2.11): um interruptor por consentimento.
///
/// Sem [nrSocio] são os da própria conta; com ele, os de um educando com
/// ligação activa — é aqui que o encarregado autoriza (ou não) o uso de imagem.
/// O ecrã é o mesmo: quem pode mudar o quê vem do servidor em cada linha.
class PrivacidadePage extends ConsumerWidget {
  const PrivacidadePage({super.key, this.nrSocio});

  final int? nrSocio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    final conta = contaDe(sessao);
    final nr = nrSocio;
    final dependente = nr == null ? null : conta?.dependente(nr);
    final pode = nr == null
        ? sessaoTem(sessao, Capacidade.consentimentos)
        : dependente?.tem(Capacidade.consentimentos) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade')),
      body: pode
          ? ConsentimentosLista(nrSocio: nr, nomeDependente: dependente?.nome)
          : _SemAcesso(
              texto: nr == null
                  ? 'A privacidade desta conta é gerida pelo encarregado de educação.'
                  : dependente == null
                  ? 'Já não acompanha este sócio na app.'
                  : 'Os consentimentos deste sócio não são geridos por esta conta.',
            ),
    );
  }
}

class _SemAcesso extends StatelessWidget {
  const _SemAcesso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: NotaPermissao(texto)),
    );
  }
}

/// A lista de interruptores, com carregamento, erro e cache. Serve a conta e
/// cada educando.
class ConsentimentosLista extends ConsumerStatefulWidget {
  const ConsentimentosLista({super.key, this.nrSocio, this.nomeDependente});

  final int? nrSocio;

  /// Para dizer sempre de quem é a conta que se está a ver.
  final String? nomeDependente;

  @override
  ConsumerState<ConsentimentosLista> createState() => _ConsentimentosListaState();
}

class _ConsentimentosListaState extends ConsumerState<ConsentimentosLista> {
  /// Tipos com uma escrita a caminho: o interruptor fica parado até ela voltar.
  final _emCurso = <String>{};

  bool get _deDependente => widget.nrSocio != null;

  Future<void> _alterar(Consentimento c, bool ativo, {String? politicaVersao}) async {
    setState(() => _emCurso.add(c.tipo));
    try {
      await ref
          .read(consentimentosProvider(widget.nrSocio).notifier)
          .alterar(c.tipo, ativo: ativo, politicaVersao: politicaVersao);
    } on ApiException catch (e) {
      _avisar(e.message);
    } catch (_) {
      _avisar('Não foi possível guardar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _emCurso.remove(c.tipo));
    }
  }

  Future<void> _renovar(Consentimento c) async {
    final aceitou = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Aceitar de novo'),
        content: Text(
          c.tipo == 'app_account'
              ? 'Os termos de utilização e a política de privacidade foram actualizados'
                    '${c.versaoActual == null ? '' : ' (versão ${c.versaoActual})'}. '
                    'Para continuar a usar a conta, aceite a versão actual.'
              : 'O texto de "${c.rotulo}" foi actualizado'
                    '${c.versaoActual == null ? '' : ' (versão ${c.versaoActual})'} '
                    'desde que foi dado. Confirme que continua a autorizar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.pop(dialogo, true), child: const Text('Aceito')),
        ],
      ),
    );
    if (aceitou == true) await _alterar(c, true, politicaVersao: c.versaoActual);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = consentimentosProvider(widget.nrSocio);
    final estado = ref.watch(provider);
    final t = Theme.of(context);

    return estado.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(provider)),
      data: (dados) {
        final lista = dados.valor;
        final primeiroNome = _primeiroNome(widget.nomeDependente);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
            children: [
              AvisoDesactualizado(dados),
              if (_deDependente) ...[
                _DeQuem(nome: widget.nomeDependente, nrSocio: widget.nrSocio!),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                _deDependente
                    ? 'O que autoriza ao clube em nome de ${primeiroNome ?? 'este sócio'}. '
                          'Pode mudar de ideias a qualquer momento.'
                    : 'O que autoriza ao clube. Pode mudar de ideias a qualquer momento.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (lista.isEmpty)
                Bloco(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Não há consentimentos para mostrar.', style: t.textTheme.bodyMedium),
                )
              else
                Bloco(
                  child: Column(
                    children: [
                      for (final (i, c) in lista.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                        InterruptorConsentimento(
                          consentimento: c,
                          deDependente: _deDependente,
                          aGuardar: _emCurso.contains(c.tipo),
                          // Um de cada vez: a resposta de um traz a lista toda.
                          bloqueado: _emCurso.isNotEmpty,
                          onChanged: (v) => _alterar(c, v),
                          onRenovar: () => _renovar(c),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String? _primeiroNome(String? nome) {
    final p = nome?.trim().split(RegExp(r'\s+')).first.toLowerCase() ?? '';
    return p.isEmpty ? null : p[0].toUpperCase() + p.substring(1);
  }
}

/// De quem é a conta que se está a ver — para ninguém decidir pelo filho errado.
class _DeQuem extends StatelessWidget {
  const _DeQuem({required this.nome, required this.nrSocio});

  final String? nome;
  final int nrSocio;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = (nome == null || nome!.trim().isEmpty) ? 'Sócio n.º $nrSocio' : nome!;
    return Semantics(
      container: true,
      label: 'Consentimentos de $n, sócio n.º $nrSocio',
      excludeSemantics: true,
      child: Row(
        children: [
          Avatar(nome: n, tamanho: 48),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n, style: t.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('Sócio n.º $nrSocio', style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha: o rótulo que vem do servidor, o interruptor, e por baixo o que
/// houver a explicar — porque não se pode mudar, que é preciso aceitar de
/// novo, quem o deu.
class InterruptorConsentimento extends StatelessWidget {
  const InterruptorConsentimento({
    super.key,
    required this.consentimento,
    required this.onChanged,
    required this.onRenovar,
    this.deDependente = false,
    this.aGuardar = false,
    this.bloqueado = false,
  });

  final Consentimento consentimento;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRenovar;
  final bool deDependente, aGuardar, bloqueado;

  @override
  Widget build(BuildContext context) {
    final c = consentimento;
    final t = Theme.of(context);
    final cores = AppColors.of(context);
    final discreto = t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant);
    final dadoPor = c.ativo ? textoDadoPor(c.dadoPor, deDependente: deDependente) : null;
    final quando = c.ativo && c.concedidoEm != null ? DateFormat('dd/MM/yyyy').format(c.concedidoEm!) : null;
    final activavel = c.podeAlterar && !bloqueado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: c.ativo,
            onChanged: activavel ? onChanged : null,
            title: Text(c.rotulo, style: t.textTheme.titleSmall),
            subtitle: switch ((dadoPor, quando)) {
              (final d?, final q?) => Text('$d · $q', style: discreto),
              (final d?, null) => Text(d, style: discreto),
              _ => null,
            },
            secondary: aGuardar
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : null,
          ),
          if (!c.podeAlterar)
            _Nota(
              icone: Icons.lock_outline_rounded,
              cor: t.colorScheme.onSurfaceVariant,
              texto: explicacaoPorqueNao(c.porqueNao),
            ),
          if (c.precisaRenovar)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: cores.warning.container, borderRadius: AppRadius.smAll),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.update_rounded, size: 20, color: cores.warning.foreground),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'O texto mudou desde que foi dado. É preciso aceitar de novo.',
                            style: t.textTheme.bodySmall?.copyWith(color: cores.warning.foreground),
                          ),
                        ),
                      ],
                    ),
                    if (c.podeAlterar) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: cores.warning.foreground),
                          onPressed: bloqueado ? null : onRenovar,
                          child: const Text('Aceitar de novo'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icone, required this.cor, required this.texto});

  final IconData icone;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cor)),
          ),
        ],
      ),
    );
  }
}
