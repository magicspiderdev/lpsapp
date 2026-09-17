import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/auth/sessao.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../auth/auth_widgets.dart';
import '../inicio_page.dart';
import 'perfil.dart';

/// Dados pessoais: contactos editáveis, o resto só de leitura, e a segurança da conta.
class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(perfilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dados pessoais')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(perfilProvider)),
        // A chave muda com os dados do servidor: o formulário recomeça a partir deles.
        data: (d) =>
            _Formulario(key: ValueKey(d.obtidoEm), perfil: d.valor, aviso: AvisoDesactualizado(d), actual: d.actuais),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({super.key, required this.perfil, required this.aviso, required this.actual});

  final Perfil perfil;
  final Widget aviso;

  /// Só se grava com os dados vindos agora do servidor, não da cache.
  final bool actual;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _campos;
  late bool _newsletter;
  bool _aGravar = false;
  bool _aEnviarFoto = false;
  String? _erro;

  Perfil get p => widget.perfil;

  @override
  void initState() {
    super.initState();
    _campos = {
      'email': TextEditingController(text: p.email ?? ''),
      'telefone_1': TextEditingController(text: p.telefone1 ?? ''),
      'telefone_2': TextEditingController(text: p.telefone2 ?? ''),
      'endereco': TextEditingController(text: p.endereco ?? ''),
      'cp_1': TextEditingController(text: p.cp1 ?? ''),
      'localidade': TextEditingController(text: p.localidade ?? ''),
    };
    for (final c in _campos.values) {
      c.addListener(() => setState(() {}));
    }
    _newsletter = p.recebeNewsletter;
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _original(String campo) => switch (campo) {
    'email' => p.email,
    'telefone_1' => p.telefone1,
    'telefone_2' => p.telefone2,
    'endereco' => p.endereco,
    'cp_1' => p.cp1,
    'localidade' => p.localidade,
    _ => null,
  };

  /// Só vai para o servidor o que mudou.
  Map<String, Object?> get _alteracoes => {
    for (final e in _campos.entries)
      if (e.value.text.trim() != (_original(e.key) ?? '')) e.key: e.value.text.trim(),
    if (_newsletter != p.recebeNewsletter) 'recebe_newsletter': _newsletter,
  };

  Future<void> _gravar() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _aGravar = true;
      _erro = null;
    });
    try {
      final r = await guardarPerfil(ref.read(dioSocioProvider), _alteracoes);
      ref.invalidate(perfilProvider);
      ref.invalidate(resumoProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(r.atualizado.isEmpty ? 'Nada foi alterado.' : 'Dados guardados.')));
      }
    } on ApiException catch (e) {
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aGravar = false);
    }
  }

  Future<void> _mudarFoto() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar fotografia'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null) return;

    // Reduzida no telemóvel: o limite do servidor é 8 MB e a foto é um avatar.
    final imagem = await ImagePicker().pickImage(source: origem, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
    if (imagem == null || !mounted) return;

    setState(() => _aEnviarFoto = true);
    final mensagens = ScaffoldMessenger.of(context);
    try {
      await enviarFoto(ref.read(dioSocioProvider), imagem.path, nome: imagem.name);
      ref.invalidate(perfilProvider);
      ref.invalidate(resumoProvider);
      mensagens.showSnackBar(const SnackBar(content: Text('Fotografia actualizada.')));
    } on ApiException catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _aEnviarFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final mudou = _alteracoes.isNotEmpty;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 40),
        children: [
          widget.aviso,
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: widget.actual && !_aEnviarFoto ? _mudarFoto : null,
              child: Stack(
                children: [
                  Avatar(nome: p.nomeCompleto, url: p.fotoUrl, tamanho: 96),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.colorScheme.surface, width: 2),
                      ),
                      child: _aEnviarFoto
                          ? SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: t.colorScheme.onPrimary),
                            )
                          : Icon(Icons.photo_camera_rounded, size: 16, color: t.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(p.nomeCompleto, textAlign: TextAlign.center, style: t.textTheme.titleLarge),
          Text('Sócio n.º ${p.nrSocio} · ${p.estadoLabel}', textAlign: TextAlign.center, style: t.textTheme.bodySmall),

          const TituloSeccao('Contactos'),
          _Campo(
            _campos['email']!,
            'Email',
            teclado: TextInputType.emailAddress,
            validar: (v) => v.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Email inválido',
          ),
          _Campo(_campos['telefone_1']!, 'Telemóvel', teclado: TextInputType.phone),
          _Campo(_campos['telefone_2']!, 'Outro telefone', teclado: TextInputType.phone),

          const TituloSeccao('Morada'),
          _Campo(_campos['endereco']!, 'Morada'),
          Row(
            children: [
              Expanded(flex: 2, child: _Campo(_campos['cp_1']!, 'Código postal', teclado: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _Campo(_campos['localidade']!, 'Localidade')),
            ],
          ),
          Bloco(
            child: SwitchListTile(
              title: const Text('Receber a newsletter do clube'),
              value: _newsletter,
              onChanged: (v) => setState(() => _newsletter = v),
            ),
          ),
          if (_erro != null) ...[const SizedBox(height: 12), AvisoErro(_erro!)],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: mudou && widget.actual && !_aGravar ? _gravar : null,
            child: _aGravar
                ? const ProgressoBotao()
                : Text(widget.actual ? 'Guardar alterações' : 'Sem ligação para guardar'),
          ),

          const TituloSeccao('Dados do clube'),
          Bloco(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Leitura('NIF', p.nif),
                _Leitura('Data de nascimento', p.dataNascimento == null ? null : dataCurta(p.dataNascimento!)),
                _Leitura('Sócio desde', p.dataSocio == null ? null : dataCurta(p.dataSocio!)),
                if (p.modalidade != null) _Leitura('Modalidade', p.modalidade),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text('Nome, NIF e datas são alterados pela secretaria.', style: t.textTheme.bodySmall),
          ),

          const TituloSeccao('Segurança'),
          Bloco(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const IconePastilha(Icons.password_rounded),
                  title: const Text('Alterar palavra-passe'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/socio/perfil/password'),
                ),
                const Divider(indent: 72),
                ListTile(
                  leading: IconePastilha(Icons.delete_outline_rounded, cor: t.colorScheme.error),
                  title: Text('Eliminar conta da app', style: TextStyle(color: t.colorScheme.error)),
                  onTap: () => confirmarEliminarConta(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo(this.controlador, this.rotulo, {this.teclado, this.validar});

  final TextEditingController controlador;
  final String rotulo;
  final TextInputType? teclado;
  final String? Function(String)? validar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        decoration: InputDecoration(labelText: rotulo),
        validator: validar == null ? null : (v) => validar!((v ?? '').trim()),
      ),
    );
  }
}

class _Leitura extends StatelessWidget {
  const _Leitura(this.rotulo, this.valor);

  final String rotulo;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(rotulo, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
          Text(valor ?? '—', style: t.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Eliminar a conta da app (exigido pelas lojas, guia §2.3.3).
Future<void> confirmarEliminarConta(BuildContext context, WidgetRef ref) async {
  final password = TextEditingController();
  String? erro;
  var aEnviar = false;

  await showDialog<void>(
    context: context,
    builder: (dialogo) => StatefulBuilder(
      builder: (dialogo, setState) => AlertDialog(
        title: const Text('Eliminar conta da app?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deixa de poder entrar na app e de receber notificações. '
              'A ficha de sócio, as quotas e os pagamentos mantêm-se no clube.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Palavra-passe', errorText: erro),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: aEnviar ? null : () => Navigator.pop(dialogo), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogo).colorScheme.error),
            onPressed: aEnviar
                ? null
                : () async {
                    setState(() {
                      aEnviar = true;
                      erro = null;
                    });
                    try {
                      final mensagem = await ref.read(sessaoProvider.notifier).eliminarConta(password.text);
                      if (dialogo.mounted) Navigator.pop(dialogo);
                      // O router já saiu da área de sócio: a mensagem vai pelo mensageiro global.
                      mensagensGlobais.currentState?.showSnackBar(
                        SnackBar(content: Text(mensagem), duration: const Duration(seconds: 8)),
                      );
                    } on ApiException catch (e) {
                      setState(() {
                        aEnviar = false;
                        erro = e.message;
                      });
                    }
                  },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ),
  );
  password.dispose();
}

/// Alterar a palavra-passe (guia §2.3.2).
class AlterarPasswordPage extends ConsumerStatefulWidget {
  const AlterarPasswordPage({super.key});

  @override
  ConsumerState<AlterarPasswordPage> createState() => _AlterarPasswordPageState();
}

class _AlterarPasswordPageState extends ConsumerState<AlterarPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nova = TextEditingController();
  final _repetir = TextEditingController();
  bool _aEnviar = false;
  String? _erro;

  @override
  void dispose() {
    _actual.dispose();
    _nova.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _alterar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _aEnviar = true;
      _erro = null;
    });
    try {
      await ref.read(sessaoProvider.notifier).alterarPassword(actual: _actual.text, nova: _nova.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Palavra-passe alterada. A sessão noutros aparelhos terminou.')));
      context.pop();
    } on ApiException catch (e) {
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Tema.margem + 4, 8, Tema.margem + 4, 24),
            children: [
              Text('Alterar palavra-passe', style: t.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'É só a da app: a do portal web não muda.',
                style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _actual,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Palavra-passe actual'),
                validator: (v) => (v ?? '').isEmpty ? 'Indique a palavra-passe actual' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nova,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s$'))],
                decoration: const InputDecoration(labelText: 'Palavra-passe nova', helperText: 'Mínimo 8 caracteres'),
                validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repetir,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repetir palavra-passe nova'),
                validator: (v) => v != _nova.text ? 'As palavras-passe não coincidem' : null,
              ),
              if (_erro != null) ...[const SizedBox(height: 16), AvisoErro(_erro!)],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _aEnviar ? null : _alterar,
                child: _aEnviar ? const ProgressoBotao() : const Text('Alterar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
