import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/formatos.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/blocos.dart';
import '../auth/auth_widgets.dart';
import 'inscricao.dart';

/// Primeiro passo da inscrição (§4.21): os dados de quem se inscreve.
///
/// Serve para a própria pessoa ou para um menor a cargo de quem tem a conta
/// (`dependente`). **A app não calcula idades**: os campos do encarregado
/// aparecem quando se escolhe "um menor", e se um menor for inscrito como
/// "eu", é o servidor que o diz (`422`, com a razão pronta a mostrar).
///
/// Só as caixas que o contrato pede. O parentesco escolhe-se, não se escreve.
class InscricaoFormPage extends ConsumerStatefulWidget {
  const InscricaoFormPage({super.key, this.dependente = false});

  /// Começar já com "um menor a meu cargo" escolhido.
  final bool dependente;

  @override
  ConsumerState<InscricaoFormPage> createState() => _InscricaoFormPageState();
}

class _InscricaoFormPageState extends ConsumerState<InscricaoFormPage> {
  static const _parentescos = ['mãe', 'pai', 'avó', 'avô', 'tutor'];

  final _form = GlobalKey<FormState>();
  late bool _dependente = widget.dependente;
  DateTime? _nascimento;
  String? _parentesco;
  bool _aEnviar = false;
  String? _erro;

  final _nome = TextEditingController();
  final _nif = TextEditingController();
  final _cc = TextEditingController();
  final _morada = TextEditingController();
  final _cp = TextEditingController();
  final _localidade = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _encNome = TextEditingController();
  final _encCc = TextEditingController();
  final _encTelefone = TextEditingController();
  final _encEmail = TextEditingController();

  List<TextEditingController> get _todos => [
    _nome,
    _nif,
    _cc,
    _morada,
    _cp,
    _localidade,
    _email,
    _telefone,
    _encNome,
    _encCc,
    _encTelefone,
    _encEmail,
  ];

  @override
  void initState() {
    super.initState();
    _preencherDaConta();
  }

  /// O que a conta já sabe vai para quem o é: o próprio, ou o encarregado.
  /// Só o nome e o email — o resto não vem na sessão.
  void _preencherDaConta() {
    final conta = contaDe(ref.read(sessaoProvider));
    if (conta == null) return;
    final (nome, email) = _dependente ? (_encNome, _encEmail) : (_nome, _email);
    if (nome.text.isEmpty) nome.text = conta.nome;
    if (email.text.isEmpty) email.text = conta.email ?? '';
  }

  void _trocarPara(bool dependente) {
    if (dependente == _dependente) return;
    final conta = contaDe(ref.read(sessaoProvider));
    setState(() {
      _dependente = dependente;
      _erro = null;
      // Trocar leva o nome e o email da conta para o lado certo, sem apagar o
      // que a pessoa tenha escrito à mão.
      if (conta != null) {
        final (deNome, deEmail, paraNome, paraEmail) = dependente
            ? (_nome, _email, _encNome, _encEmail)
            : (_encNome, _encEmail, _nome, _email);
        if (deNome.text == conta.nome) deNome.clear();
        if (deEmail.text == (conta.email ?? '')) deEmail.clear();
        if (paraNome.text.isEmpty) paraNome.text = conta.nome;
        if (paraEmail.text.isEmpty) paraEmail.text = conta.email ?? '';
      }
    });
  }

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - (_dependente ? 8 : 30)),
      firstDate: DateTime(hoje.year - 110),
      lastDate: hoje,
      helpText: 'Data de nascimento',
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  Future<void> _submeter() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_nascimento == null) {
      setState(() => _erro = 'Indique a data de nascimento.');
      return;
    }
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    final dados = DadosInscricao(
      dependente: _dependente,
      nome: _nome.text,
      dataNascimento: _nascimento!,
      nif: _nif.text,
      cc: _cc.text,
      morada: _morada.text,
      cp: _cp.text,
      localidade: _localidade.text,
      email: _email.text,
      telefone: _telefone.text,
      encNome: _encNome.text,
      encParentesco: _parentesco,
      encCc: _encCc.text,
      encTelefone: _encTelefone.text,
      encEmail: _encEmail.text,
    );
    try {
      final i = await ref.read(inscricoesApiProvider).submeter(dados);
      ref.invalidate(minhasInscricoesProvider);
      if (!mounted) return;
      context.pushReplacement('/inscricoes/${i.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      // Já há uma a meio para esta pessoa: continua-se essa, não se recomeça.
      if (inscricaoExistente(e) case final id?) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        context.pushReplacement('/inscricoes/$id');
        return;
      }
      // `422 dados_invalidos` (um menor como "eu", o nome sem apelido…) e
      // `403 menor_de_idade` trazem a razão escrita.
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final podeContratar = sessaoTem(ref.watch(sessaoProvider), Capacidade.contratar);

    return Scaffold(
      appBar: AppBar(title: const Text('Tornar-me sócio')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxl),
              children: [
                Text(
                  'O clube vê o pedido e responde por email. Só depois de ser admitido se assinam os '
                  'documentos e se pagam as primeiras quotas.',
                  style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Quem se inscreve?', style: t.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Eu'), icon: Icon(Icons.person_rounded)),
                    ButtonSegment(
                      value: true,
                      label: Text('Um menor a meu cargo'),
                      icon: Icon(Icons.family_restroom_rounded),
                    ),
                  ],
                  selected: {_dependente},
                  showSelectedIcon: false,
                  onSelectionChanged: _aEnviar ? null : (s) => _trocarPara(s.first),
                ),
                if (_dependente) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Um menor é inscrito pelo encarregado de educação, que é quem assina os documentos.',
                    style: t.textTheme.bodySmall,
                  ),
                ],
                TituloSeccao(_dependente ? 'O menor' : 'Os seus dados'),
                ..._campos(t),
                if (_dependente) ...[const TituloSeccao('O encarregado de educação'), ..._camposEncarregado(t)],
                if (_erro != null) ...[const SizedBox(height: AppSpacing.lg), AvisoErro(_erro!)],
                const SizedBox(height: AppSpacing.xl),
                if (podeContratar)
                  FilledButton(
                    onPressed: _aEnviar ? null : _submeter,
                    child: _aEnviar ? const ProgressoBotao() : const Text('Enviar pedido'),
                  )
                else
                  NotaPermissao(explicacaoPermissao('contratar'), padding: EdgeInsets.zero),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _campos(ThemeData t) => [
    TextFormField(
      controller: _nome,
      enabled: !_aEnviar,
      decoration: const InputDecoration(labelText: 'Nome completo'),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: _dependente ? null : const [AutofillHints.name],
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o nome completo' : null,
    ),
    const SizedBox(height: AppSpacing.md),
    _CampoData(valor: _nascimento, aoTocar: _aEnviar ? null : _escolherData),
    const SizedBox(height: AppSpacing.md),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _nif,
            enabled: !_aEnviar,
            decoration: const InputDecoration(labelText: 'NIF'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextFormField(
            controller: _cc,
            enabled: !_aEnviar,
            decoration: const InputDecoration(labelText: 'Cartão de Cidadão'),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
          ),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.md),
    TextFormField(
      controller: _morada,
      enabled: !_aEnviar,
      decoration: const InputDecoration(labelText: 'Morada'),
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.streetAddressLine1],
    ),
    const SizedBox(height: AppSpacing.md),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: TextFormField(
            controller: _cp,
            enabled: !_aEnviar,
            // Entra como a pessoa o escrever; o servidor arruma (2740025 → 2740-025).
            decoration: const InputDecoration(labelText: 'Código postal'),
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.postalCode],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextFormField(
            controller: _localidade,
            enabled: !_aEnviar,
            decoration: const InputDecoration(labelText: 'Localidade'),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.addressCity],
          ),
        ),
      ],
    ),
    const SizedBox(height: AppSpacing.md),
    _campoEmail(_email, 'Email'),
    const SizedBox(height: AppSpacing.md),
    _campoTelefone(_telefone, 'Telemóvel'),
  ];

  List<Widget> _camposEncarregado(ThemeData t) => [
    TextFormField(
      controller: _encNome,
      enabled: !_aEnviar,
      decoration: const InputDecoration(labelText: 'Nome completo'),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      validator: (v) => _dependente && (v == null || v.trim().isEmpty) ? 'Indique o nome do encarregado' : null,
    ),
    const SizedBox(height: AppSpacing.md),
    Text('Parentesco', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
    const SizedBox(height: AppSpacing.sm),
    Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final p in _parentescos)
          ChoiceChip(
            label: Text(p[0].toUpperCase() + p.substring(1)),
            selected: _parentesco == p,
            onSelected: _aEnviar ? null : (s) => setState(() => _parentesco = s ? p : null),
          ),
      ],
    ),
    const SizedBox(height: AppSpacing.md),
    TextFormField(
      controller: _encCc,
      enabled: !_aEnviar,
      decoration: const InputDecoration(labelText: 'Cartão de Cidadão'),
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: AppSpacing.md),
    _campoTelefone(_encTelefone, 'Telemóvel'),
    const SizedBox(height: AppSpacing.md),
    _campoEmail(_encEmail, 'Email'),
  ];

  Widget _campoEmail(TextEditingController c, String rotulo) => TextFormField(
    controller: c,
    enabled: !_aEnviar,
    decoration: InputDecoration(labelText: rotulo),
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.email],
    validator: (v) => v != null && v.trim().isNotEmpty && !v.contains('@') ? 'Indique um email válido' : null,
  );

  Widget _campoTelefone(TextEditingController c, String rotulo) => TextFormField(
    controller: c,
    enabled: !_aEnviar,
    decoration: InputDecoration(labelText: rotulo),
    keyboardType: TextInputType.phone,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d +]')), LengthLimitingTextInputFormatter(16)],
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.telephoneNumber],
  );
}

/// A data de nascimento escolhe-se num calendário: nada de a escrever.
class _CampoData extends StatelessWidget {
  const _CampoData({required this.valor, required this.aoTocar});

  final DateTime? valor;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: aoTocar,
      borderRadius: AppRadius.mdAll,
      child: InputDecorator(
        isEmpty: valor == null,
        decoration: InputDecoration(
          labelText: 'Data de nascimento',
          enabled: aoTocar != null,
          suffixIcon: const Icon(Icons.calendar_today_rounded),
        ),
        child: Text(valor == null ? '' : dataCurta(valor!)),
      ),
    );
  }
}
