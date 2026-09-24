import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/links.dart';
import '../../core/tema/tema.dart';
import 'auth_widgets.dart';

/// Sair do login sem entrar: volta ao que se estava a fazer, desde que isso
/// não exija sessão — senão o router mandava logo de volta para aqui.
String saidaDoLogin(String? voltar) {
  final destino = Links.voltarSeguro(voltar);
  return destino == null || destino.startsWith('/socio') ? '/noticias' : destino;
}

/// Quem entra pode ser sócio ou não: a conta é que manda (§2.9).
///
/// O mesmo campo aceita **email ou número de sócio** porque o
/// `POST /api/v2/auth/login` aceita os dois, e obrigar a escolher antes de
/// escrever só criaria um passo a mais. Tudo dígitos = número de sócio.
({String? email, int? nrSocio}) identificador(String texto) {
  final t = texto.trim();
  final numero = int.tryParse(t);
  return numero != null ? (email: null, nrSocio: numero) : (email: t, nrSocio: null);
}

/// Entrar na conta (`POST /api/v2/auth/login`).
class EntrarPage extends ConsumerStatefulWidget {
  const EntrarPage({super.key});

  @override
  ConsumerState<EntrarPage> createState() => _EntrarPageState();
}

class _EntrarPageState extends ConsumerState<EntrarPage> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _aEnviar = false;
  bool _verPassword = false;
  String? _erro;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      final quem = identificador(_id.text);
      await ref
          .read(sessaoProvider.notifier)
          .entrar(email: quem.email, nrSocio: quem.nrSocio, password: _password.text);
      // O router leva para /socio quando a sessão muda.
    } on ApiException catch (e) {
      final restantes = e.erro == 'credenciais_invalidas' ? e.tentativasRestantes : null;
      setState(
        () => _erro = restantes == null
            ? e.message
            : '${e.message} ${restantes == 1 ? 'Resta 1 tentativa.' : 'Restam $restantes tentativas.'}',
      );
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Vindo de uma acção que exige conta (ex.: comprar bilhetes): diz porquê e,
    // depois de entrar, o router volta a essa acção (`?voltar=`).
    final parametros = GoRouterState.of(context).uri.queryParameters;
    final paraBilhetes = parametros['motivo'] == 'bilhetes';
    final paraComunidade = parametros['motivo'] == 'comunidade';

    return Scaffold(
      // O login não vive num separador da navegação (ver `router.dart`), por
      // isso traz a sua própria saída: entrar é opcional, e quem só quer ver
      // as notícias não pode ficar preso aqui.
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
                const MarcaClube(),
                const SizedBox(height: 28),
                Text(
                  paraBilhetes
                      ? 'Entre para comprar'
                      : paraComunidade
                      ? 'Entre na comunidade'
                      : 'A sua conta',
                  style: tema.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  paraBilhetes
                      ? 'Os bilhetes ficam na sua conta. Entre e volta à escolha que fez.'
                      : paraComunidade
                      ? 'Palpites, resultados e passatempos são para todos os adeptos, sócios ou não. '
                            'Entre com o email ou crie uma conta.'
                      : 'Entre com o email ou, se é sócio, com o seu número de sócio.',
                  style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'Email ou número de sócio',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o email ou o número de sócio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Palavra-passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                  obscureText: !_verPassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _entrar(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Indique a palavra-passe' : null,
                ),
                if (_erro != null) ...[const SizedBox(height: 16), AvisoErro(_erro!)],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _aEnviar ? null : _entrar,
                  child: _aEnviar ? const ProgressoBotao() : const Text('Entrar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _aEnviar
                      ? null
                      : () => context.go(
                          Uri(
                            path: '/entrar/codigo',
                            queryParameters: parametros.isEmpty ? null : parametros,
                          ).toString(),
                        ),
                  child: const Text('Primeiro acesso ou esqueci-me da palavra-passe'),
                ),
                const Divider(height: 32),
                Text(
                  'Ainda não tem conta?',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _aEnviar
                      ? null
                      : () => context.go(
                          Uri(path: '/entrar/registo', queryParameters: parametros.isEmpty ? null : parametros)
                              .toString(),
                        ),
                  child: const Text('Criar conta com email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
