import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/sessao.dart';
import '../../core/tema/tema.dart';
import 'auth_widgets.dart';
import 'entrar_page.dart' show saidaDoLogin;

/// Associar a ficha de sócio a uma conta que já existe (§2.9).
///
/// O código segue para o **email da ficha de sócio**, não para o da conta: é
/// isso que prova que quem está a pedir é mesmo aquele sócio. Feito isto, a
/// sessão volta já com sócio e a zona privada abre.
class AssociarSocioPage extends ConsumerStatefulWidget {
  const AssociarSocioPage({super.key});

  @override
  ConsumerState<AssociarSocioPage> createState() => _AssociarSocioPageState();
}

class _AssociarSocioPageState extends ConsumerState<AssociarSocioPage> {
  final _form = GlobalKey<FormState>();
  final _nr = TextEditingController();
  final _codigo = TextEditingController();

  String? _mensagemEnvio;
  bool _aEnviar = false;
  String? _erro;

  @override
  void dispose() {
    _nr.dispose();
    _codigo.dispose();
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

  Future<void> _pedir() => _executar(() async {
    final mensagem = await ref.read(sessaoProvider.notifier).pedirSocio(int.parse(_nr.text));
    setState(() => _mensagemEnvio = mensagem);
  });

  Future<void> _confirmar() => _executar(
    () => ref.read(sessaoProvider.notifier).confirmarSocio(nrSocio: int.parse(_nr.text), codigo: _codigo.text),
  );

  /// Sair sem associar. Chega-se aqui por redirecionamento (tocar em "Sócio"
  /// sem ficha), e aí não há nada para desempilhar — `pop()` não fazia nada.
  /// Volta-se ao que se estava a fazer, ou à zona pública.
  void _agoraNao() {
    final voltar = GoRouterState.of(context).uri.queryParameters['voltar'];
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(saidaDoLogin(voltar));
    }
  }

  @override
  Widget build(BuildContext context) {
    final passo2 = _mensagemEnvio != null;
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha de sócio'),
        // Chegando aqui por redirecionamento não há seta de voltar: sem isto,
        // o ecrã não teria saída nenhuma no topo.
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close_rounded),
          onPressed: _aEnviar ? null : _agoraNao,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 8, Tema.margem + 4, 24),
            children: [
              Text(passo2 ? 'Verifique o email da ficha' : 'É sócio do clube?', style: tema.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                _mensagemEnvio ??
                    'Associe a sua ficha à conta para ver o cartão, as quotas e os pagamentos. '
                        'Enviamos um código para o email que consta na ficha.',
                style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nr,
                enabled: !passo2,
                decoration: const InputDecoration(
                  labelText: 'Número de sócio',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.isEmpty) ? 'Indique o número de sócio' : null,
              ),
              if (passo2) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codigo,
                  decoration: const InputDecoration(labelText: 'Código', prefixIcon: Icon(Icons.pin_outlined)),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onFieldSubmitted: (_) => _confirmar(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o código que recebeu' : null,
                ),
              ],
              if (_erro != null) ...[const SizedBox(height: 16), AvisoErro(_erro!)],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _aEnviar ? null : (passo2 ? _confirmar : _pedir),
                child: _aEnviar ? const ProgressoBotao() : Text(passo2 ? 'Associar' : 'Enviar código'),
              ),
              if (passo2) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _aEnviar ? null : () => setState(() => _mensagemEnvio = null),
                  child: const Text('Usar outro número'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _aEnviar ? null : _agoraNao,
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
