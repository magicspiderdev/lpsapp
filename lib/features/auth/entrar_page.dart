import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';

/// Login de sócio pelo número de sócio (`POST /auth/login`).
class EntrarPage extends ConsumerStatefulWidget {
  const EntrarPage({super.key});

  @override
  ConsumerState<EntrarPage> createState() => _EntrarPageState();
}

class _EntrarPageState extends ConsumerState<EntrarPage> {
  final _form = GlobalKey<FormState>();
  final _nr = TextEditingController();
  final _password = TextEditingController();
  bool _aEnviar = false;
  bool _verPassword = false;
  String? _erro;

  @override
  void dispose() {
    _nr.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      await ref.read(sessaoProvider.notifier).entrar(
            nrSocio: int.parse(_nr.text),
            password: _password.text,
          );
      // O router leva para /socio quando a sessão muda.
    } on ApiException catch (e) {
      final restantes = e.erro == 'credenciais_invalidas' ? e.tentativasRestantes : null;
      setState(() => _erro = restantes == null
          ? e.message
          : '${e.message} (${restantes == 1 ? 'resta 1 tentativa' : 'restam $restantes tentativas'})');
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Área de sócio')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Entre com o seu número de sócio para ver as quotas, o cartão e os pagamentos.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nr,
                decoration: const InputDecoration(labelText: 'Número de sócio', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => (v == null || v.isEmpty) ? 'Indique o número de sócio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Palavra-passe',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPassword = !_verPassword),
                  ),
                ),
                obscureText: !_verPassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _entrar(),
                validator: (v) => (v == null || v.isEmpty) ? 'Indique a palavra-passe' : null,
              ),
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _aEnviar ? null : _entrar,
                child: _aEnviar
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _aEnviar ? null : () => context.go('/entrar/codigo'),
                child: const Text('Primeiro acesso ou esqueci-me da palavra-passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
