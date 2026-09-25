import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/tema/tema.dart';
import '../../core/widgets/links_legais.dart';
import 'auth_widgets.dart';
import 'entrar_page.dart' show saidaDoLogin;

/// Criar conta com email (`POST /api/v2/auth/registo`), para quem não é sócio
/// — e para o sócio que prefira entrar pelo email.
///
/// Dois passos: os dados, e depois o código que chega ao email. O servidor
/// responde sempre o mesmo, exista ou não a conta, por isso o segundo passo
/// aparece na mesma — nunca se diz quem já tem conta.
class RegistoPage extends ConsumerStatefulWidget {
  const RegistoPage({super.key});

  @override
  ConsumerState<RegistoPage> createState() => _RegistoPageState();
}

class _RegistoPageState extends ConsumerState<RegistoPage> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _codigo = TextEditingController();

  DateTime? _nascimento;
  bool _comunicacoes = false;
  bool _aceitaTermos = false;

  /// `declara_idade` (§2.10): a data é uma declaração, e sem ela o servidor
  /// recusa (`422 declaracao_idade`). Desmarcada por omissão.
  bool _declaraIdade = false;
  bool _verPassword = false;

  /// A `mensagem` do servidor depois de pedir o registo; `null` = passo 1.
  String? _mensagemEnvio;
  bool _aEnviar = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_nome, _email, _password, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _executar(Future<void> Function() accao) async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      await accao();
    } on ApiException catch (e) {
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  Future<void> _registar() {
    if (_nascimento == null) {
      setState(() => _erro = 'Indique a data de nascimento.');
      return Future.value();
    }
    if (!_declaraIdade) {
      setState(() => _erro = 'Confirme que a data de nascimento é verdadeira.');
      return Future.value();
    }
    if (!_aceitaTermos) {
      setState(() => _erro = 'É preciso aceitar os termos e a política de privacidade.');
      return Future.value();
    }
    return _executar(() async {
      final mensagem = await ref
          .read(sessaoProvider.notifier)
          .registar(
            email: _email.text.trim(),
            password: _password.text,
            nome: _nome.text.trim(),
            dataNascimento: _nascimento!,
            comunicacoes: _comunicacoes,
          );
      setState(() => _mensagemEnvio = mensagem);
    });
  }

  // Com sucesso a sessão abre e o router leva para onde a pessoa ia.
  Future<void> _confirmar() => _executar(
    () => ref.read(sessaoProvider.notifier).confirmarRegisto(email: _email.text.trim(), codigo: _codigo.text),
  );

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 30),
      firstDate: DateTime(hoje.year - 110),
      // Sem limite de idade aqui: a app nunca calcula idades. Abaixo da mínima
      // o servidor responde `403 encarregado_necessario`, com a mensagem.
      lastDate: hoje,
      helpText: 'Data de nascimento',
    );
    if (escolhida != null) setState(() => _nascimento = escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final passo2 = _mensagemEnvio != null;
    final tema = Theme.of(context);
    final parametros = GoRouterState.of(context).uri.queryParameters;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(saidaDoLogin(parametros['voltar'])),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 8, Tema.margem + 4, 24),
              children: [
                Text(passo2 ? 'Verifique o email' : 'Criar conta', style: tema.textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  _mensagemEnvio ??
                      'A conta serve para bilhetes, notificações e inscrições. '
                          'Não é preciso ser sócio — e quem for pode associar a ficha depois.',
                  style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                if (passo2) ..._passoCodigo(tema) else ..._passoDados(tema),
                if (_erro != null) ...[const SizedBox(height: 16), AvisoErro(_erro!)],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _aEnviar ? null : (passo2 ? _confirmar : _registar),
                  child: _aEnviar ? const ProgressoBotao() : Text(passo2 ? 'Confirmar e entrar' : 'Criar conta'),
                ),
                if (passo2) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _aEnviar ? null : () => setState(() => _mensagemEnvio = null),
                    child: const Text('Corrigir os dados'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _passoDados(ThemeData tema) => [
    TextFormField(
      controller: _nome,
      decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline_rounded)),
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.name],
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o nome' : null,
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _email,
      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: (v) => (v == null || !v.contains('@')) ? 'Indique um email válido' : null,
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _password,
      decoration: InputDecoration(
        labelText: 'Palavra-passe',
        helperText: 'Pelo menos 8 caracteres',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _verPassword = !_verPassword),
        ),
      ),
      obscureText: !_verPassword,
      autofillHints: const [AutofillHints.newPassword],
      // O servidor tem a palavra final (`422 password_fraca`); isto evita a
      // ida e volta no caso óbvio.
      validator: (v) => (v == null || v.length < 8) ? 'Pelo menos 8 caracteres' : null,
    ),
    const SizedBox(height: 12),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cake_outlined),
      title: Text(
        _nascimento == null ? 'Data de nascimento' : DateFormat("d 'de' MMMM 'de' y", 'pt_PT').format(_nascimento!),
      ),
      subtitle: const Text('Decide o que a conta pode fazer'),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: _aEnviar ? null : _escolherData,
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _declaraIdade,
      onChanged: _aEnviar ? null : (v) => setState(() => _declaraIdade = v ?? false),
      title: const Text('Declaro que a data de nascimento que indiquei é verdadeira'),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _aceitaTermos,
      onChanged: _aEnviar ? null : (v) => setState(() => _aceitaTermos = v ?? false),
      title: const Text('Aceito os termos de utilização e a política de privacidade'),
      subtitle: const LinksLegais(),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _comunicacoes,
      onChanged: _aEnviar ? null : (v) => setState(() => _comunicacoes = v ?? false),
      title: const Text('Quero receber notícias e novidades do clube'),
      subtitle: const Text('Opcional, e muda-se quando quiser'),
    ),
  ];

  List<Widget> _passoCodigo(ThemeData tema) => [
    TextFormField(
      controller: _codigo,
      decoration: const InputDecoration(labelText: 'Código', prefixIcon: Icon(Icons.pin_outlined)),
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      onFieldSubmitted: (_) => _confirmar(),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o código que recebeu' : null,
    ),
  ];
}
