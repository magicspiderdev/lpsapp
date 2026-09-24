import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/cache/com_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import 'educandos.dart';

/// Os educandos da conta (§2.3.5): as ligações activas e os pedidos à espera
/// da secretaria. Qualquer conta, sócia ou não.
///
/// Abre-se também pelo push de quando a secretaria decide um pedido (`route:
/// "/socio/dependentes"`): a lista recarrega sempre que o ecrã abre.
class EducandosPage extends ConsumerStatefulWidget {
  const EducandosPage({super.key});

  @override
  ConsumerState<EducandosPage> createState() => _EducandosPageState();
}

class _EducandosPageState extends ConsumerState<EducandosPage> {
  /// Tentou-se já pôr a sessão em dia com a lista? Uma vez por abertura.
  bool _sessaoRenovada = false;

  /// Educando com uma remoção a caminho.
  int? _aRemover;

  // Recarregar ao abrir (o push) vem de graça: o provider é autoDispose, por
  // isso cada abertura mostra a cache e pede sempre ao servidor.

  void _verSessao(List<Educando> lista) {
    if (_sessaoRenovada) return;
    if (!sessaoDesactualizada(lista, contaDe(ref.read(sessaoProvider)))) return;
    _sessaoRenovada = true;
    ref.read(educandosAccoesProvider).renovarSessao();
  }

  Future<void> _remover(Educando e) async {
    final activo = e.activo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(activo ? 'Deixar de acompanhar ${e.nome}?' : 'Desistir do pedido?'),
        content: Text(
          activo
              ? 'Deixa de ver a ficha, o cartão e os pagamentos de ${e.nome} na app. '
                    'Para voltar, terá de pedir outra vez e esperar pela secretaria.'
              : 'O pedido para acompanhar ${e.nome} deixa de estar à espera da secretaria.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogo, false), child: const Text('Cancelar')),
          FilledButton(
            style: activo ? FilledButton.styleFrom(backgroundColor: Theme.of(dialogo).colorScheme.error) : null,
            onPressed: () => Navigator.pop(dialogo, true),
            child: Text(activo ? 'Deixar de acompanhar' : 'Desistir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _aRemover = e.nrSocio);
    try {
      await ref.read(educandosAccoesProvider).remover(e.nrSocio);
      _avisar(activo ? 'Deixou de acompanhar ${e.nome}.' : 'Pedido retirado.');
    } on ApiException catch (err) {
      _avisar(err.message);
      // `nao_encontrado`: já não estava — a lista que se tem está velha.
      ref.invalidate(educandosProvider);
    } finally {
      if (mounted) setState(() => _aRemover = null);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Dados<List<Educando>>>>(educandosProvider, (_, s) {
      final d = s.valueOrNull;
      if (d != null && d.actuais) _verSessao(d.valor);
    });

    final sessao = ref.watch(sessaoProvider);
    final conta = contaDe(sessao);
    final podePedir = sessaoTem(sessao, Capacidade.gerirDependentes);
    final estado = ref.watch(educandosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Educandos')),
      floatingActionButton: podePedir && (estado.valueOrNull?.valor.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RotasEducandos.pedir),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Acompanhar'),
              tooltip: 'Acompanhar um educando',
            )
          : null,
      body: estado.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(educandosProvider)),
        data: (dados) {
          final lista = ordenarEducandos(dados.valor);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(educandosProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.bottomBarClearance,
              ),
              children: [
                AvisoDesactualizado(dados),
                if (lista.isEmpty)
                  _Vazio(podePedir: podePedir)
                else
                  for (final e in lista) ...[
                    CartaoEducando(
                      educando: e,
                      podePrivacidade:
                          e.activo && (conta?.dependente(e.nrSocio)?.tem(Capacidade.consentimentos) ?? false),
                      aRemover: _aRemover == e.nrSocio,
                      onPrivacidade: () => context.push(RotasEducandos.privacidade(e.nrSocio)),
                      onRemover: _aRemover == null ? () => _remover(e) : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.podePedir});

  final bool podePedir;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        children: [
          const IconePastilha(Icons.family_restroom_rounded),
          const SizedBox(height: AppSpacing.lg),
          Text('Ainda não acompanha nenhum educando', style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Se é pai, mãe ou encarregado de educação de um sócio menor, pode acompanhá-lo aqui: '
            'a ficha, o cartão e os pagamentos. A secretaria confirma a ligação.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (podePedir) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => context.push(RotasEducandos.pedir),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Acompanhar um educando'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Um educando. Pendente: "à espera da secretaria" e só "desistir do pedido".
/// Activo: nome, relação, privacidade e deixar de acompanhar. Estado que não
/// se conhece: só o nome — sem acções.
class CartaoEducando extends StatelessWidget {
  const CartaoEducando({
    super.key,
    required this.educando,
    required this.onPrivacidade,
    required this.onRemover,
    this.podePrivacidade = false,
    this.aRemover = false,
  });

  final Educando educando;
  final bool podePrivacidade, aRemover;
  final VoidCallback onPrivacidade;

  /// `null` enquanto outra remoção está a caminho.
  final VoidCallback? onRemover;

  @override
  Widget build(BuildContext context) {
    final e = educando;
    final t = Theme.of(context);
    final cores = AppColors.of(context);
    final relacao = rotuloRelacao(e.relacao);
    final linha = [if (relacao.isNotEmpty) relacao, 'Sócio n.º ${e.nrSocio}'].join(' · ');

    return Bloco(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Avatar(nome: e.nome.isEmpty ? '?' : e.nome, tamanho: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nome, style: t.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      Text(linha, style: t.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (e.pendente) ...[
            const SizedBox(height: AppSpacing.md),
            _Etiqueta(
              texto: 'À espera da secretaria',
              icone: Icons.hourglass_top_rounded,
              frente: cores.warning.foreground,
              fundo: cores.warning.container,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A secretaria confirma a identidade e o parentesco. Pode pedir-lhe que o faça ao balcão.',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ],
          if (e.pendente || e.activo) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.end,
              children: [
                if (e.activo && podePrivacidade)
                  TextButton.icon(
                    onPressed: onPrivacidade,
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacidade'),
                  ),
                if (aRemover)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: e.activo ? t.colorScheme.error : null),
                    onPressed: onRemover,
                    child: Text(e.activo ? 'Deixar de acompanhar' : 'Desistir do pedido'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.icone, required this.frente, required this.fundo});

  final String texto;
  final IconData icone;
  final Color frente, fundo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: fundo, borderRadius: AppRadius.xsAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: frente),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: frente)),
          ),
        ],
      ),
    );
  }
}
