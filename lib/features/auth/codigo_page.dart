import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';

/// Primeiro acesso e "esqueci-me da palavra-passe" (guia §2.3.1): o mesmo fluxo.
/// 1) pedir o código com o número de sócio; 2) código + palavra-passe nova.
class CodigoPage extends ConsumerStatefulWidget {
  const CodigoPage({super.key});

  @override
  ConsumerState<CodigoPage> createState() => _CodigoPageState();
}

class _CodigoPageState extends ConsumerState<CodigoPage> {
  final _form = GlobalKey<FormState>();
  final _nr = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmacao = TextEditingController();

  /// A `mensagem` do servidor depois de pedir o código; `null` = ainda no passo 1.
  String? _mensagemEnvio;
  bool _aEnviar = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_nr, _codigo, _password, _confirmacao]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _executar(Future<void> Function() accao) async {
    if (!_form.currentState!.validate()) return;
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

  Future<void> _pedirCodigo() => _executar(() async {
        final mensagem = await ref.read(sessaoProvider.notifier).pedirCodigo(int.parse(_nr.text));
        setState(() => _mensagemEnvio = mensagem);
      });

  // Com sucesso a sessão abre e o router leva para /socio.
  Future<void> _confirmar() => _executar(() => ref.read(sessaoProvider.notifier).confirmarCodigo(
        nrSocio: int.parse(_nr.text),
        codigo: _codigo.text,
        password: _password.text,
      ));

  @override
  Widget build(BuildContext context) {
    final passo2 = _mensagemEnvio != null;
    final campo = const InputDecoration(border: OutlineInputBorder());

    return Scaffold(
      appBar: AppBar(title: const Text('Código de acesso')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(passo2
                  ? _mensagemEnvio!
                  : 'Vamos enviar um código de 6 dígitos para o email da sua ficha de sócio. '
                      'Serve para o primeiro acesso à app e para definir uma palavra-passe nova.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nr,
                enabled: !passo2,
                decoration: campo.copyWith(labelText: 'Número de sócio'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.isEmpty) ? 'Indique o número de sócio' : null,
              ),
              if (passo2) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codigo,
                  decoration: campo.copyWith(labelText: 'Código recebido'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  validator: (v) => (v == null || v.length != 6) ? 'O código tem 6 dígitos' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  decoration: campo.copyWith(labelText: 'Palavra-passe nova', helperText: 'Mínimo 8 caracteres'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmacao,
                  decoration: campo.copyWith(labelText: 'Repetir palavra-passe'),
                  obscureText: true,
                  validator: (v) => v != _password.text ? 'As palavras-passe não coincidem' : null,
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 16),
                Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _aEnviar ? null : (passo2 ? _confirmar : _pedirCodigo),
                child: _aEnviar
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(passo2 ? 'Confirmar e entrar' : 'Enviar código'),
              ),
              if (passo2)
                TextButton(
                  onPressed: _aEnviar ? null : _pedirCodigo,
                  child: const Text('Não recebi — enviar outro código'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
