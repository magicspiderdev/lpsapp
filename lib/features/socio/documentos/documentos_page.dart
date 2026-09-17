import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/formatos.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/erro_view.dart';
import '../../../core/widgets/estado_dados.dart';
import '../pagamentos/dados.dart';
import 'documentos.dart';

class DocumentosPage extends ConsumerWidget {
  const DocumentosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(documentosProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Documentos')),
      body: estado.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErroView(erro: e, tentarDeNovo: () => ref.invalidate(documentosProvider)),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(documentosProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(Tema.margem, 8, Tema.margem, 32),
            children: [
              AvisoDesactualizado(d),
              if (d.valor.isEmpty)
                const Bloco(padding: EdgeInsets.all(20), child: Text('Ainda não há documentos de inscrições.')),
              for (final i in d.valor) ...[
                TituloSeccao(
                  [if (i.modalidade != null) _capital(i.modalidade!), if (i.epoca != null) i.epoca!].join(' · '),
                ),
                Bloco(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      if (i.documentos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Sem documentos nesta inscrição.', style: t.textTheme.bodySmall),
                        ),
                      for (final (n, doc) in i.documentos.indexed) ...[
                        if (n > 0) const Divider(indent: 72),
                        _LinhaDocumento(doc),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _LinhaDocumento extends ConsumerStatefulWidget {
  const _LinhaDocumento(this.doc);

  final Documento doc;

  @override
  ConsumerState<_LinhaDocumento> createState() => _LinhaDocumentoState();
}

class _LinhaDocumentoState extends ConsumerState<_LinhaDocumento> {
  bool _aAbrir = false;

  Future<void> _abrir() async {
    setState(() => _aAbrir = true);
    final mensagens = ScaffoldMessenger.of(context);
    try {
      final ficheiro = await obterDocumento(ref.read(pedidosNaContaProvider), widget.doc);
      final r = await OpenFilex.open(ficheiro.path, type: 'application/pdf');
      if (r.type == ResultType.noAppToOpen) {
        mensagens.showSnackBar(const SnackBar(content: Text('Não há nenhuma app para abrir PDFs neste telemóvel.')));
      }
    } on ApiException catch (e) {
      mensagens.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      mensagens.showSnackBar(const SnackBar(content: Text('Não foi possível abrir o documento.')));
    } finally {
      if (mounted) setState(() => _aAbrir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return ListTile(
      enabled: d.disponivel,
      onTap: d.disponivel && !_aAbrir ? _abrir : null,
      leading: IconePastilha(
        Icons.picture_as_pdf_rounded,
        cor: d.disponivel ? null : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(d.titulo),
      subtitle: Text(
        !d.disponivel
            ? 'Ainda não disponível'
            : [
                if (d.assinadoEm != null) 'assinado a ${dataCurta(d.assinadoEm!)}',
                if (d.assinanteNome != null) d.assinanteNome!,
              ].join(' · '),
      ),
      trailing: _aAbrir
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}
