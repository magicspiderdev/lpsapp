import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/clientes.dart';
import '../../../core/rede/ligacao.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../../../core/widgets/imagem_rede.dart';
import '../inicio_page.dart';
import 'suporte.dart';
import 'suporte_page.dart' show mudarArquivo;

/// Um ficheiro escolhido para enviar.
typedef _Anexo = ({String caminho, String nome, bool pdf});

/// Uma conversa com a secretaria, ou uma nova (`id == null`) que só nasce ao
/// enviar a primeira mensagem.
class ConversaPage extends ConsumerStatefulWidget {
  const ConversaPage({super.key, this.id});

  final int? id;

  @override
  ConsumerState<ConversaPage> createState() => _ConversaPageState();
}

class _ConversaPageState extends ConsumerState<ConversaPage> {
  /// Sem push ainda, as respostas chegam por consulta enquanto a conversa está aberta.
  static const _intervalo = Duration(seconds: 10);

  final _texto = TextEditingController();
  Timer? _consulta;
  _Anexo? _anexo;
  bool _aEnviar = false;
  bool _marcouLidas = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _consulta = Timer.periodic(_intervalo, (_) {
        if (mounted && !_aEnviar && ref.read(ligacaoProvider)) ref.invalidate(mensagensProvider(widget.id!));
      });
    }
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _escolherAnexo() async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar fotografia'),
              onTap: () => Navigator.pop(c, 'camara'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Imagem da galeria'),
              onTap: () => Navigator.pop(c, 'galeria'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Documento PDF'),
              onTap: () => Navigator.pop(c, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (opcao == null) return;

    if (opcao == 'pdf') {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
      if (f?.path == null) return;
      if (await File(f!.path!).length() > 10 * 1024 * 1024) {
        _mensagem('O ficheiro não pode ter mais de 10 MB.');
        return;
      }
      setState(() => _anexo = (caminho: f.path!, nome: f.name, pdf: true));
    } else {
      // Fotografias comprimidas antes de enviar, como pede o guia.
      final img = await ImagePicker().pickImage(
        source: opcao == 'camara' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (img == null) return;
      setState(() => _anexo = (caminho: img.path, nome: img.name, pdf: false));
    }
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    final anexo = _anexo;
    if (texto.isEmpty && anexo == null) return;

    setState(() => _aEnviar = true);
    final dio = ref.read(dioSocioProvider);
    try {
      var id = widget.id;
      if (id == null) {
        // Conversa nova: a primeira mensagem tem de ter texto; o anexo segue a seguir.
        id = await dio.criarConversa(texto.isEmpty ? 'Envio um anexo.' : texto);
        if (anexo != null) await dio.enviarAnexo(id, anexo.caminho, nome: anexo.nome);
      } else if (anexo != null) {
        await dio.enviarAnexo(id, anexo.caminho, nome: anexo.nome, texto: texto);
      } else {
        await dio.responder(id, texto);
      }
      _texto.clear();
      setState(() => _anexo = null);
      // Uma mensagem nova tira a conversa do arquivo no servidor.
      ref
        ..invalidate(conversasProvider)
        ..invalidate(conversasArquivadasProvider);
      if (!mounted) return;
      if (widget.id == null) {
        context.pushReplacement('/socio/suporte/$id');
      } else {
        ref.invalidate(mensagensProvider(id));
      }
    } on ApiException catch (e) {
      if (e.erro == 'conversa_fechada') ref.invalidate(mensagensProvider(widget.id!));
      _mensagem(e.message);
    } finally {
      if (mounted) setState(() => _aEnviar = false);
    }
  }

  void _mensagem(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final online = ref.watch(ligacaoProvider);

    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nova conversa')),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Escreva a sua dúvida. A secretaria responde aqui e no portal.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            _Compositor(
              texto: _texto,
              anexo: _anexo,
              aEnviar: _aEnviar,
              online: online,
              onAnexar: _escolherAnexo,
              onRemoverAnexo: () => setState(() => _anexo = null),
              onEnviar: _enviar,
            ),
          ],
        ),
      );
    }

    final estado = ref.watch(mensagensProvider(id));
    // Abrir a conversa marca as mensagens da secretaria como lidas: o contador do início baixa.
    ref.listen(mensagensProvider(id), (_, s) {
      if (!_marcouLidas && (s.valueOrNull?.actuais ?? false)) {
        _marcouLidas = true;
        ref.invalidate(resumoProvider);
        ref.invalidate(conversasProvider);
      }
    });
    // Pode vir de qualquer das listas: abre-se também a partir das arquivadas.
    final listas = listasDeConversas(
      activas: ref.watch(conversasProvider).valueOrNull,
      arquivadas: ref.watch(conversasArquivadasProvider).valueOrNull,
      pendentes: ref.watch(arquivoConversasProvider),
    );
    final arquivadaEm = listas.arquivadas.where((c) => c.id == id).firstOrNull;
    final conversa = listas.activas.where((c) => c.id == id).firstOrNull ?? arquivadaEm;
    final fechada = conversa?.fechada ?? false;
    final arquivada = arquivadaEm != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Secretaria'),
            Text('Conversa n.º $id', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (conversa != null)
            IconButton(
              tooltip: arquivada ? 'Desarquivar' : 'Arquivar',
              icon: Icon(arquivada ? Icons.unarchive_outlined : Icons.archive_outlined),
              onPressed: () {
                final avisos = ScaffoldMessenger.of(context);
                final arquivo = ref.read(arquivoConversasProvider.notifier);
                // Arquivar volta à lista, onde se vê o resultado e se pode desfazer.
                if (!arquivada && context.canPop()) context.pop();
                mudarArquivo(avisos, arquivo, conversa, arquivar: !arquivada);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: estado.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(mensagensProvider(id))),
              data: (d) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Tema.margem, 0, Tema.margem, 0),
                    child: AvisoDesactualizado(d, margem: const EdgeInsets.only(top: 8)),
                  ),
                  Expanded(child: _Mensagens(d.valor)),
                ],
              ),
            ),
          ),
          if (fechada)
            _ConversaFechada(onNova: () => context.pushReplacement('/socio/suporte/nova'))
          else
            _Compositor(
              texto: _texto,
              anexo: _anexo,
              aEnviar: _aEnviar,
              online: online,
              onAnexar: _escolherAnexo,
              onRemoverAnexo: () => setState(() => _anexo = null),
              onEnviar: _enviar,
            ),
        ],
      ),
    );
  }
}

class _Mensagens extends StatelessWidget {
  const _Mensagens(this.mensagens);

  final List<Mensagem> mensagens;

  @override
  Widget build(BuildContext context) {
    // Lista invertida: a mais recente fica junto ao campo de escrita.
    final lista = mensagens.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Tema.margem, 12, Tema.margem, 12),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final m = lista[i];
        final anterior = i + 1 < lista.length ? lista[i + 1] : null;
        final novoDia =
            m.enviadaEm != null &&
            (anterior?.enviadaEm == null || !DateUtils.isSameDay(anterior!.enviadaEm, m.enviadaEm));
        return Column(children: [if (novoDia) _SeparadorDia(m.enviadaEm!), _Bolha(m)]);
      },
    );
  }
}

class _SeparadorDia extends StatelessWidget {
  const _SeparadorDia(this.dia);

  final DateTime dia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hoje = DateUtils.dateOnly(DateTime.now());
    final texto = DateUtils.isSameDay(dia, hoje)
        ? 'Hoje'
        : DateUtils.isSameDay(dia, hoje.subtract(const Duration(days: 1)))
        ? 'Ontem'
        : DateFormat("d 'de' MMMM", 'pt_PT').format(dia);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: t.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(100)),
          child: Text(texto, style: t.textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha(this.m);

  final Mensagem m;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final meu = !m.doClube;
    final fundo = meu ? t.colorScheme.primary : t.colorScheme.surfaceContainerLowest;
    final frente = meu ? t.colorScheme.onPrimary : t.colorScheme.onSurface;
    const r = Radius.circular(20);

    return Align(
      alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.only(
              topLeft: r,
              topRight: r,
              bottomLeft: meu ? r : const Radius.circular(6),
              bottomRight: meu ? const Radius.circular(6) : r,
            ),
          ),
          // Largura pelo conteúdo: sem isto a hora alinhada à direita estica a bolha ao máximo.
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!meu)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      'Secretaria',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: t.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (m.temAnexo) _AnexoMensagem(m, frente: frente),
                if (m.texto.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: m.temAnexo ? 8 : 0),
                    // Texto simples: mostra-se tal como vem, e pode copiar-se.
                    child: SelectableText(
                      m.texto,
                      style: t.textTheme.bodyMedium?.copyWith(color: frente, height: 1.35),
                    ),
                  ),
                if (m.enviadaEm != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        DateFormat('HH:mm').format(m.enviadaEm!),
                        style: TextStyle(fontSize: 11, color: frente.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnexoMensagem extends StatelessWidget {
  const _AnexoMensagem(this.m, {required this.frente});

  final Mensagem m;
  final Color frente;

  void _abrir() => launchUrl(Uri.parse(m.anexoUrl!), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    // Anexo da app anterior que não foi trazido: diz-se que existiu, sem o abrir.
    if (m.anexoIndisponivel) {
      return _Ficheiro(
        icone: switch (m.anexoTipo) {
          TipoAnexo.imagem => Icons.hide_image_outlined,
          _ => Icons.link_off_rounded,
        },
        texto: 'Anexo indisponível',
        frente: frente,
        abre: false,
      );
    }
    if (m.anexoTipo == TipoAnexo.imagem) {
      return GestureDetector(
        onTap: _abrir,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, minWidth: 160),
            child: ImagemRede(
              m.anexoUrl!,
              fit: BoxFit.cover,
              falha: (_) => _Ficheiro(icone: Icons.image_outlined, texto: 'Imagem', frente: frente),
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _abrir,
      child: _Ficheiro(
        icone: m.anexoTipo == TipoAnexo.pdf ? Icons.picture_as_pdf_outlined : Icons.attach_file_rounded,
        texto: m.anexoTipo == TipoAnexo.pdf ? 'Documento PDF' : 'Ficheiro',
        frente: frente,
      ),
    );
  }
}

class _Ficheiro extends StatelessWidget {
  const _Ficheiro({required this.icone, required this.texto, required this.frente, this.abre = true});

  final IconData icone;
  final String texto;
  final Color frente;

  /// Mostra o sinal de que se abre fora da app.
  final bool abre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: frente.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: frente),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(color: frente, fontWeight: FontWeight.w600),
          ),
          if (abre) ...[
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, size: 16, color: frente.withValues(alpha: 0.7)),
          ],
        ],
      ),
    );
  }
}

class _Compositor extends StatelessWidget {
  const _Compositor({
    required this.texto,
    required this.anexo,
    required this.aEnviar,
    required this.online,
    required this.onAnexar,
    required this.onRemoverAnexo,
    required this.onEnviar,
  });

  final TextEditingController texto;
  final _Anexo? anexo;
  final bool aEnviar, online;
  final VoidCallback onAnexar, onRemoverAnexo, onEnviar;

  @override
  Widget build(BuildContext context) {
    final anexo = this.anexo;
    final t = Theme.of(context);
    final podeEnviar = online && !aEnviar && (texto.text.trim().isNotEmpty || anexo != null);

    return Material(
      color: t.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anexo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      Icon(anexo.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(anexo.nome, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        tooltip: 'Remover anexo',
                        onPressed: aEnviar ? null : onRemoverAnexo,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Anexar',
                    onPressed: online && !aEnviar ? onAnexar : null,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: texto,
                      enabled: !aEnviar,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [LengthLimitingTextInputFormatter(tamanhoMaximoMensagem)],
                      decoration: InputDecoration(
                        hintText: online ? 'Escreva uma mensagem' : 'Sem ligação',
                        fillColor: t.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: t.colorScheme.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: podeEnviar ? onEnviar : null,
                    icon: aEnviar
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: t.colorScheme.onPrimary),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversaFechada extends StatelessWidget {
  const _ConversaFechada({required this.onNova});

  final VoidCallback onNova;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Tema.margem),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A secretaria fechou esta conversa.', style: t.textTheme.bodyMedium),
              const SizedBox(height: 10),
              FilledButton(onPressed: onNova, child: const Text('Abrir nova conversa')),
            ],
          ),
        ),
      ),
    );
  }
}
