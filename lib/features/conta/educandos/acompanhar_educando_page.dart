import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/blocos.dart';
import 'educandos.dart';

/// "Acompanhar um educando" (§2.3.5): o número de sócio **e** a data de
/// nascimento têm de bater com a ficha, e a secretaria confirma o parentesco.
/// O pedido, sozinho, não dá acesso a nada.
class AcompanharEducandoPage extends ConsumerStatefulWidget {
  const AcompanharEducandoPage({super.key});

  @override
  ConsumerState<AcompanharEducandoPage> createState() => _AcompanharEducandoPageState();
}

class _AcompanharEducandoPageState extends ConsumerState<AcompanharEducandoPage> {
  final _form = GlobalKey<FormState>();
  final _nr = TextEditingController();
  DateTime? _nascimento;
  String? _relacao;
  bool _aEnviar = false;
  String? _erro;

  /// Depois de enviado: a `mensagem` do servidor, e o pedido (se veio).
  ({Educando? educando, String mensagem})? _resultado;

  @override
  void dispose() {
    _nr.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 10),
      // Quem é maior decide o servidor (`dependente_maior`), não o calendário.
      firstDate: DateTime(hoje.year - 110),
      lastDate: hoje,
      helpText: 'Data de nascimento do educando',
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  Future<void> _enviar() async {
    final valido = _form.currentState?.validate() ?? false;
    final falta = _nascimento == null
        ? 'Indique a data de nascimento do educando.'
        : _relacao == null
        ? 'Escolha a sua relação com o educando.'
        : null;
    setState(() => _erro = falta);
    if (!valido || falta != null) return;

    setState(() => _aEnviar = true);
    try {
      final r = await ref
          .read(educandosAccoesProvider)
          .pedir(nrSocio: int.parse(_nr.text.trim()), dataNascimento: _nascimento!, relacao: _relacao!);
      if (mounted) setState(() => _resultado = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível enviar o pedido. Tente novamente.');
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final podePedir = sessaoTem(ref.watch(sessaoProvider), Capacidade.gerirDependentes);

    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhar um educando')),
      body: SafeArea(
        child: switch ((_resultado, podePedir)) {
          (final r?, _) => _Enviado(resultado: r),
          (null, false) => const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: NotaPermissao('Só um adulto pode pedir para acompanhar um sócio.'),
            ),
          ),
          (null, true) => _formulario(context),
        },
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xxl),
        children: [
          Text(
            'Indique o número de sócio e a data de nascimento do seu educando, tal como estão na ficha. '
            'A secretaria confirma a ligação — pode pedir-lhe que o faça ao balcão.',
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _nr,
            enabled: !_aEnviar,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Número de sócio do educando'),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              return n == null || n <= 0 ? 'Indique o número de sócio.' : null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Como no registo: um campo que abre o calendário, sem teclado.
          InkWell(
            onTap: _aEnviar ? null : _escolherData,
            borderRadius: AppRadius.smAll,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data de nascimento do educando',
                suffixIcon: Icon(Icons.calendar_today_rounded),
              ),
              isEmpty: _nascimento == null,
              child: _nascimento == null ? null : Text(DateFormat('dd/MM/yyyy').format(_nascimento!)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('A sua relação com o educando', style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in relacoesPedido)
                ChoiceChip(
                  label: Text(rotuloRelacao(r)),
                  selected: _relacao == r,
                  onSelected: _aEnviar ? null : (_) => setState(() => _relacao = r),
                ),
            ],
          ),
          if (_erro case final erro?) ...[
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: cores.error.container, borderRadius: AppRadius.smAll),
                child: Text(erro, style: t.textTheme.bodyMedium?.copyWith(color: cores.error.foreground)),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _aEnviar ? null : _enviar,
            child: _aEnviar
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Enviar pedido'),
          ),
        ],
      ),
    );
  }
}

/// O pedido foi aceite pelo servidor: mostra-se a `mensagem` dele.
class _Enviado extends StatelessWidget {
  const _Enviado({required this.resultado});

  final ({Educando? educando, String mensagem}) resultado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cores = AppColors.of(context);
    final activo = resultado.educando?.activo ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxl, AppSpacing.screen, AppSpacing.xxl),
      children: [
        Center(
          child: IconePastilha(
            activo ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded,
            cor: activo ? cores.success.foreground : cores.warning.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          activo ? 'Já acompanha ${resultado.educando!.nome}' : 'Pedido enviado',
          style: t.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(resultado.mensagem, style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Voltar aos educandos')),
      ],
    );
  }
}
