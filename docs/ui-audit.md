# Auditoria de UI/UX — LPS Neo

**Data:** 2026-09-19 · **Âmbito:** todos os ecrãs em `lib/` (27 ecrãs e folhas, 64 ficheiros Dart) · **Código alterado:** nenhum

**Como foi feita**

- Leitura integral de todos os ecrãs, do tema (`lib/core/tema/tema.dart`) e dos widgets partilhados.
- Critérios das skills *mobile-app-ui-design* (hierarquia, grelha de 8 pt, 60/30/10, estados vazios, momento de pico) e *ui-ux-pro-max* (prioridades: acessibilidade → toque → desempenho → estilo → layout → tipografia/cor), incluindo a base `--stack flutter`.
- Não há nenhuma skill oficial do Flutter instalada. A parte técnica segue as boas práticas publicadas em docs.flutter.dev (âmbito dos rebuilds, `Semantics`, `TextScaler`, `const`).
- Os contrastes foram **calculados** (fórmula WCAG 2.x) a partir das cores reais do tema, e não estimados.
- As contagens (cores fixas, `Semantics`, `tooltip`, …) saem de `grep` sobre `lib/`.

> A sugestão automática de design system do ui-ux-pro-max ("Vibrant & Block-based", vermelho `#DC2626`, Bebas Neue) **não foi usada**. É um molde genérico de "clube desportivo" que ignora a identidade verde do clube e a Inter já incluída na app. A proposta da secção 6 parte da linguagem visual que a app já tem.

---

## Resumo

A base é boa. O tema está centralizado, há modo escuro, a tipografia Inter vem incluída na app, a cache mostra logo a última informação e os ecrãs de dinheiro são cuidadosos. Os problemas concentram-se em três frentes:

1. **Acessibilidade quase ausente.** Há **0** `Semantics` e **0** `semanticLabel` em toda a app, e só **5** `tooltip`. Há 11 botões só com ícone e 7 `GestureDetector` sem nome para o leitor de ecrã. Vários pares de cor falham o AA: o texto secundário fica em 4,10:1, as etiquetas de estado entre 2,9 e 3,4:1 e os campos de formulário em 1,09:1.
2. **Um defeito funcional visível.** As imagens no corpo das notícias nunca aparecem, porque a app exige um `uid` que o contrato actual já não envia.
3. **Os tokens ficam a meio caminho.** Há 11 cores fixas fora do tema (uma delas ilegível no modo escuro), 21 `fontSize` literais com 11 valores diferentes, raios em 10 valores diferentes e seis pares de widgets duplicados.

---

## 1. Problemas de design por ecrã

Legenda: **[C]** crítico · **[I]** importante · **[K]** cosmético. O identificador remete para a lista priorizada da secção 5.

### Estrutura comum

| Problema | Onde | Prioridade |
|---|---|---|
| O cabeçalho das zonas públicas tem margens assimétricas: `margem + 4` à esquerda e `margem` à direita. O conteúdo por baixo usa `margem` dos dois lados, e o título fica 4 px desalinhado da lista | [noticias_page.dart:42](../lib/features/publico/noticias/noticias_page.dart#L42), agenda, bilheteira | K4 |
| O mesmo bloco "sobretítulo verde + título grande" está copiado em três ecrãs (Notícias, Agenda, Bilhetes) | idem | K2 |
| As legendas da barra de navegação têm 11 px, abaixo do mínimo de 12 px recomendado | [tema.dart:165](../lib/core/tema/tema.dart#L165) | I7 |
| A faixa "Sem ligação" usa uma cor fixa `#16181C` e 12,5 px. No modo escuro fica quase igual ao fundo `#000` | [shell_page.dart:108](../lib/features/shell/shell_page.dart#L108) | K1 |
| O ecrã de arranque é só um spinner sobre o fundo. Não há problema, mas uma espera longa no `/ping` fica sem contexto nenhum | [arranque_page.dart](../lib/features/arranque/arranque_page.dart) | K9 |

### Zona pública

**Notícias** ([noticias_page.dart](../lib/features/publico/noticias/noticias_page.dart), [noticia_page.dart](../lib/features/publico/noticias/noticia_page.dart))

- **[C] C1. As imagens do corpo nunca aparecem.** O `switch` só aceita `'imagem' when b['uid'] is String` ([noticia_page.dart:114](../lib/features/publico/noticias/noticia_page.dart#L114)). O contrato publicado (`openapi-v2.yaml`, esquema `Noticia`) envia `{tipo: imagem, url, largura, altura, credito, legenda}` sem `uid`. Os blocos `video` também são ignorados. Quando isto se corrigir, convém usar `largura`/`altura` num `AspectRatio` para a página não saltar enquanto a imagem carrega, e mostrar o `credito` e a `legenda`.
- **[I] I9.** O destaque é um `GestureDetector` ([noticias_page.dart:140](../lib/features/publico/noticias/noticias_page.dart#L140)). Não tem efeito de toque e não é anunciado como botão.
- **[I] C2.** O botão "voltar" da notícia é um `IconButton.filled` sem `tooltip` ([noticia_page.dart:49](../lib/features/publico/noticias/noticia_page.dart#L49)). O leitor de ecrã diz só "botão".
- **[K] K10.** Nos estados de carregamento e de erro há um `Scaffold` dentro de outro `Scaffold` ([noticia_page.dart:25](../lib/features/publico/noticias/noticia_page.dart#L25)).
- **[K].** O texto do corpo é HTML reduzido a texto simples. Perdem-se negritos e ligações, o que é aceitável por agora mas deve ficar registado.

**Agenda** ([agenda_page.dart](../lib/features/publico/agenda/agenda_page.dart))

- **[I] I4.** O estado vazio de um filtro ("Nada marcado") reutiliza o `PainelEmPreparacao`, que fora do modo demonstração mostra a pastilha **"Brevemente"** ([agenda_page.dart:113](../lib/features/publico/agenda/agenda_page.dart#L113)). Quando a API ligar, um filtro vazio vai dizer que a funcionalidade está "brevemente".
- **[I].** Não há *pull-to-refresh*, ao contrário de Notícias e de toda a zona do sócio.
- **[I] C2.** Os filtros são um `Material + InkWell` feito à mão. O leitor de ecrã não sabe qual está seleccionado. `FilterChip` ou `ChoiceChip` dão isso de graça, e também a altura mínima.
- **[K].** O cartão só é tocável quando tem bilhetes, e a etiqueta "Bilhetes" só aparece se houver `local`. Um jogo com bilhetes e sem local fica tocável mas sem pista visual nenhuma.
- **[K] K8.** O resultado escreve-se `2 - 1` com hífen ([agenda_page.dart:292](../lib/features/publico/agenda/agenda_page.dart#L292)). Deve ser um travessão `–`, com uma etiqueta semântica do tipo "2 a 1".
- **[K].** Os filtros usam 13,5 px, um tamanho fora de qualquer escala.

**Bilheteira** ([bilheteira_page.dart](../lib/features/publico/bilheteira/bilheteira_page.dart), [meus_bilhetes_page.dart](../lib/features/publico/bilheteira/meus_bilhetes_page.dart))

- **[I] I5.** Não há estado vazio para a lista de sessões. Com a lista vazia, o ecrã mostra só o cartão "Os meus bilhetes" ([bilheteira_page.dart:60](../lib/features/publico/bilheteira/bilheteira_page.dart#L60)).
- **[I] I5.** O botão "Continuar" fica activo e leva a uma snackbar a dizer "ainda não está disponível" ([bilheteira_page.dart:367](../lib/features/publico/bilheteira/bilheteira_page.dart#L367)). É um beco sem saída. Enquanto não houver compra, o melhor é desactivá-lo e pôr a explicação por baixo.
- **[C] C2.** Os botões − e + da quantidade não têm `tooltip` nem `Semantics` ([bilheteira_page.dart:314](../lib/features/publico/bilheteira/bilheteira_page.dart#L314)). O leitor de ecrã diz "botão, botão, 0".
- **[I] I1.** O bilhete aberto mostra o QR, mas não põe o ecrã no brilho máximo.
- **[I] C4.** Um bilhete usado leva `Opacity(0.6)` ([meus_bilhetes_page.dart:73](../lib/features/publico/bilheteira/meus_bilhetes_page.dart#L73)). O texto secundário desce para **2,24:1**, e as meias-luas do picotado ficam translúcidas.
- **[K].** Num cartão de sessão esgotado, o botão fica desactivado mas o cartão continua tocável, e há dois alvos para o mesmo destino.

**O clube** ([clube_page.dart](../lib/features/publico/clube/clube_page.dart))

- **[C] C2.** Os ícones das redes sociais são círculos só com ícone e sem nome ([clube_page.dart:238](../lib/features/publico/clube/clube_page.dart#L238)).
- **[K] K7.** O Instagram é representado por uma câmara fotográfica, e todas as modalidades usam o mesmo ícone de andebol.
- **[K] K6.** A marca aparece como o texto "LPS" num quadrado ([clube_page.dart:122](../lib/features/publico/clube/clube_page.dart#L122), repetido em [auth_widgets.dart:19](../lib/features/auth/auth_widgets.dart#L19)). A app já tem o brasão no ícone: seria esse o elemento de identidade.
- **[K] K14.** Ver a secção 4 sobre o `FutureBuilder(PackageInfo.fromPlatform())` ([clube_page.dart:254](../lib/features/publico/clube/clube_page.dart#L254)).

### Entrada

**Entrar, código e desbloquear** ([entrar_page.dart](../lib/features/auth/entrar_page.dart), [codigo_page.dart](../lib/features/auth/codigo_page.dart), [desbloquear_page.dart](../lib/features/auth/desbloquear_page.dart))

- **[C] C3.** Os campos são brancos sobre o fundo `#F4F5F7` e não têm contorno. O contraste do limite do campo é **1,09:1**, e o mínimo para componentes (WCAG 1.4.11) é 3:1. Em ecrãs com pouco brilho e ao sol, os campos praticamente não se vêem.
- **[C] C2.** O botão de mostrar a palavra-passe não tem `tooltip` ([entrar_page.dart:95](../lib/features/auth/entrar_page.dart#L95)). O botão grande da biometria é um `InkWell` num círculo, com um ícone sem etiqueta ([desbloquear_page.dart:63](../lib/features/auth/desbloquear_page.dart#L63)).
- **[I].** Os campos de palavra-passe nova em Código ([codigo_page.dart:112](../lib/features/auth/codigo_page.dart#L112)) e em Alterar palavra-passe não têm o botão de mostrar/ocultar que existe em Entrar.
- **[K].** A hierarquia está correcta: um título, um parágrafo e a acção principal com 56 px de altura. Mas o botão principal fica no meio do ecrã e não na zona do polegar. Nos formulários curtos é aceitável.

### Zona do sócio

**Início** ([inicio_page.dart](../lib/features/socio/inicio_page.dart))

- **[I] I3.** Em erro sem cache, o ecrã mostra só o `ErroView` ([inicio_page.dart:107](../lib/features/socio/inicio_page.dart#L107)). Não há cabeçalho, perfil nem forma de **terminar a sessão** ou mudar de conta. Com as Contas v2, um `403 conta_sem_socio` deixa o utilizador preso aqui.
- **[I] I6.** Os botões do sino e do chat têm **40×40 dp** ([inicio_page.dart:308](../lib/features/socio/inicio_page.dart#L308)), abaixo dos 48 dp do Material. Não têm `tooltip`, e a marca de "novo" é só um ponto vermelho.
- **[I] C2.** O avatar e o nome (que abre o selector de conta) são `GestureDetector` sem semântica. Nada diz que o nome é tocável além de uma seta de 22 px.
- **[K] K5.** A acção "Pagar" usa o ícone `+` ([inicio_page.dart:257](../lib/features/socio/inicio_page.dart#L257)), que se lê como "adicionar". A acção "Mais" abre a mesma folha que o avatar: dois caminhos para o mesmo sítio ocupam uma das quatro acções rápidas.
- **[K].** O valor em dívida tem 44 px fixos ([inicio_page.dart:241](../lib/features/socio/inicio_page.dart#L241)) e o `CabecalhoValor` tem 40 px. O mesmo papel está em dois tamanhos.
- **[K].** A legenda "Sócio n.º …" usa branco a 72 %, que dá **2,78:1** sobre o início claro do gradiente (`#14935A`).
- **[K] K9.** O carregamento é um bloco verde de 360 px fixos com um spinner. Um esqueleto do cabeçalho e do cartão evitaria o salto quando os dados chegam.
- **Bom:** a hierarquia está clara ("Tudo em dia" → valor → pastilha → acções). O valor domina e os rótulos não competem com ele, como pede a skill.

**Cartão de sócio** ([cartao_page.dart](../lib/features/socio/cartao/cartao_page.dart))

- **[I] I1.** O ecrã pede ao sócio "Aumente o brilho do ecrã se o leitor tiver dificuldade" ([cartao_page.dart:84](../lib/features/socio/cartao/cartao_page.dart#L84)). Na portaria isso é trabalho a mais. A app deve pôr o brilho no máximo enquanto o QR está visível (por exemplo com `screen_brightness`) e repô-lo ao sair.
- **[I] I8.** O cartão vira ao toque com uma animação 3D de 500 ms ([cartao_page.dart:309](../lib/features/socio/cartao/cartao_page.dart#L309)). A animação não respeita `MediaQuery.disableAnimationsOf`, e o gesto não é anunciado ("Toque no cartão para o virar" é só texto).
- **[I] C5.** O aviso de cartão inválido usa `#B7791F` fixo sobre uma tinta de 10 %, com **~3,2:1** ([cartao_page.dart:53](../lib/features/socio/cartao/cartao_page.dart#L53)).
- **[K].** As cores do estado no cartão (`#3DD68C`, `#FFB224`) são fixas. Neste caso é correcto, porque o cartão tem sempre fundo escuro, mas deviam ser tokens com nome.

**Quotas, faturas, mensalidades, conta corrente e histórico** ([pagamentos/](../lib/features/socio/pagamentos/))

- **[C] C5.** A caixa "Tem um pagamento de quotas por concluir…" usa o texto `#8A5A12` fixo ([pagar_sheet.dart:250](../lib/features/socio/pagamentos/pagar_sheet.dart#L250)). No modo escuro fica **2,68:1**. É um aviso sobre dinheiro que diz ao sócio que um pagamento vai deixar de valer.
- **[C] C4.** As `EtiquetaEstado` ("Pago", "Em dívida", "Por pagar") têm 12 px sobre uma tinta de 12 %, com **2,93:1** (pago), **3,35:1** (pendente) e **3,19:1** (a aguardar). Falham o AA.
- **[C] C2.** Os botões − e + dos meses na folha de pagar não têm nome ([pagar_sheet.dart:222](../lib/features/socio/pagamentos/pagar_sheet.dart#L222)).
- **[I] I12. A terminologia e a cor dos estados não batem entre si:**
  - na caderneta, um mês pendente é "Em dívida", a vermelho ([quotas_page.dart:253](../lib/features/socio/pagamentos/quotas_page.dart#L253));
  - no histórico, um pagamento `PENDENTE` é "Por pagar", a âmbar ([widgets.dart:34](../lib/features/socio/pagamentos/widgets.dart#L34));
  - numa mensalidade, `pendente` é "Por pagar", a vermelho;
  - nas faturas, o cabeçalho diz "Por pagar", a vermelho.

  Na prática há duas palavras e duas cores para o mesmo conceito.
- **[I] I2. Resultado do pagamento** ([resultado_page.dart](../lib/features/socio/pagamentos/resultado_page.dart)):
  - a referência (`N.º do pedido`, [resultado_page.dart:132](../lib/features/socio/pagamentos/resultado_page.dart#L132)) não se pode copiar;
  - a contagem de tempo do MB WAY está escondida a meio do parágrafo ([resultado_page.dart:173](../lib/features/socio/pagamentos/resultado_page.dart#L173)) e devia ser o número em destaque;
  - quando o pagamento fica "recebido", nada é anunciado ao leitor de ecrã (falta um `liveRegion` ou `SemanticsService.announce`), e não há *haptic* nem animação.

  É o momento de pico da app (regra pico-fim) e está desenhado como um estado neutro. O botão de fechar também não tem `tooltip` ([resultado_page.dart:108](../lib/features/socio/pagamentos/resultado_page.dart#L108)).
- **[I] I9.** Os estados vazios aqui são um `Bloco` só com texto ("Ainda não há faturas."), sem ícone nem próximo passo.
- **[K] K11.** A `WalletPage` vive em `mensalidades_page.dart` ([linha 147](../lib/features/socio/pagamentos/mensalidades_page.dart#L147)) e a `HistoricoPagamentosPage` em `faturas_page.dart` ([linha 224](../lib/features/socio/pagamentos/faturas_page.dart#L224)). Isto dificulta encontrar os ecrãs.
- **Bom:** o botão de pagar fica fixo em baixo (zona do polegar), fica desactivado com dados da cache ("Sem ligação para pagar"), e o total mostrado é o do servidor. Tudo correcto.

**Dados pessoais e palavra-passe** ([perfil_page.dart](../lib/features/socio/perfil/perfil_page.dart))

- **[I] I10.** "Guardar alterações" fica a meio de um formulário longo, entre a newsletter e "Dados do clube" ([perfil_page.dart:248](../lib/features/socio/perfil/perfil_page.dart#L248)). Com o teclado aberto, não se vê. Devia ser uma barra fixa em baixo que aparece quando há alterações.
- **[I] I10.** Os campos não têm `autofillHints` (email, telefone, morada, código postal) nem `textInputAction`. O código postal não tem máscara nem validação `NNNN-NNN`, e o telefone não é validado.
- **[C] C2.** A fotografia é um `GestureDetector` sem semântica: o leitor de ecrã não sabe que ali se muda a foto.
- **Bom:** "Eliminar conta" é vermelho, está isolado e pede confirmação com a palavra-passe.

**Selector de conta** ([seletor_conta.dart](../lib/features/socio/conta/seletor_conta.dart))

- **[I] C2.** A conta activa distingue-se por um contorno e um visto. Falta `Semantics(selected: true)`, e o leitor de ecrã não sabe qual está activa.

**Notificações** ([notificacoes_page.dart](../lib/features/socio/notificacoes/notificacoes_page.dart))

- **[I] I15.** O estado "nova" é um ponto vermelho de 11 px mais uma diferença de peso (700 contra 600). O leitor de ecrã não o anuncia.
- **[K] I9.** O estado vazio usa um `Icon` de 56 px solto, diferente da `IconePastilha` usada nos outros sítios.
- **Bom:** a permissão de push é pedida aqui, no contexto certo, e não no arranque.

**Documentos** ([documentos_page.dart](../lib/features/socio/documentos/documentos_page.dart))

- **[K] I9.** O estado vazio é só texto num `Bloco` ([documentos_page.dart:36](../lib/features/socio/documentos/documentos_page.dart#L36)).
- **Bom:** um documento indisponível aparece desactivado e com o motivo, e há um spinner por linha enquanto abre.

**Secretaria (lista e conversa)** ([suporte_page.dart](../lib/features/socio/suporte/suporte_page.dart), [conversa_page.dart](../lib/features/socio/suporte/conversa_page.dart))

- **[I] I11.** Uma mensagem com um anexo que ficou no servidor antigo (`anexo_url: null`) e sem texto dá uma **bolha vazia**, só com a hora ([conversa_page.dart:370](../lib/features/socio/suporte/conversa_page.dart#L370)). O contrato já prevê este caso, e devia aparecer algo como "Anexo indisponível".
- **[K].** Arquivar na lista faz-se só a deslizar (`Dismissible`, [suporte_page.dart:133](../lib/features/socio/suporte/suporte_page.dart#L133)). Há alternativa dentro da conversa, mas o `Dismissible` não expõe uma acção semântica.
- **[K].** A hora na bolha tem 11 px.
- **Bom:** a lista está invertida com o campo em baixo, os separadores de dia, o texto pode seleccionar-se e o envio fica desactivado sem rede.

---

## 2. Acessibilidade

### 2.1 Contraste (calculado)

| Par | Contraste | Mínimo | Onde |
|---|---|---|---|
| Limite do campo (branco sobre `#F4F5F7`, sem contorno) | **1,09:1** | 3:1 | todos os formulários |
| Texto de bilhete usado (`#75777D` a 60 % sobre branco) | **2,24:1** | 4,5:1 | Os meus bilhetes |
| Aviso das ordens pendentes (`#8A5A12`), **modo escuro** | **2,68:1** | 4,5:1 | folha de pagar |
| Branco a 72 % sobre o início do gradiente `#14935A` | **2,78:1** | 4,5:1 | cabeçalho do início |
| Etiqueta "Pago" `#12A15F` sobre tinta a 12 % | **2,93:1** | 4,5:1 | caderneta, histórico |
| `AvisoErro` `#E5484D` sobre tinta a 10 % | **3,17:1** | 4,5:1 | entrada, perfil, pagar |
| Etiqueta "a aguardar" `#B7791F` sobre tinta a 12 % | **3,19:1** | 4,5:1 | quotas, resultado |
| Etiqueta "Em dívida" `#E5484D` sobre tinta a 12 % | **3,35:1** | 4,5:1 | caderneta |
| Vermelho `#E5484D` sobre branco (valores em dívida, "Esgotado") | **3,91:1** | 4,5:1 | cabeçalhos de valor, bilheteira |
| `onSurfaceVariant` `#75777D` sobre fundo `#F4F5F7` | **4,10:1** | 4,5:1 | **todo o `bodySmall`**: legendas, subtítulos |
| `onSurfaceVariant` sobre branco (dentro de `Bloco`) | 4,48:1 | 4,5:1 | idem (no limite) |
| Verde `#0B5D3B` sobre `#F4F5F7` | 7,28:1 | ✓ | |
| Modo escuro: `#8E9197` sobre `#000` e sobre `#16181B` | 6,65 e 5,63:1 | ✓ | |
| Hora na bolha própria (branco a 70 % sobre verde) | 4,77:1 | ✓ | |

O `onSurfaceVariant` é o ponto mais extenso, porque passa por todo o `bodySmall` da app. A correcção faz-se num token só: `#62656B` dá 5,36:1 sobre o fundo e 5,84:1 sobre branco.

### 2.2 Leitor de ecrã (TalkBack e VoiceOver)

- **0** `Semantics`, **0** `semanticLabel`, **5** `tooltip`.
- **Botões só com ícone e sem nome** (11): sete `IconButton` sem `tooltip` (mostrar palavra-passe, voltar da notícia, −/+ dos bilhetes, −/+ dos meses, fechar o resultado) e quatro botões feitos à mão (sino, chat, redes sociais, biometria). Os 5 `tooltip` que existem estão em "O clube" e no chat (arquivar, anexar, remover anexo, enviar).
- **`GestureDetector` sem semântica** (7): destaque da notícia, cartão (início e ecrã do cartão), avatar do início, nome do início, foto do perfil e imagem anexada no chat. Trocar por `InkWell` dentro de `Material` dá efeito de toque e o papel de botão. Onde a forma não o permita, envolver em `Semantics(button: true, label: …)`.
- **Informação só por cor ou forma:** o ponto "novo" (sino, chat, notificações), a conta activa no selector, os filtros activos da agenda e os estados dos pagamentos (neste caso com texto, mas a cor é o sinal mais forte).
- **Imagens informativas sem descrição:** os emblemas das equipas na agenda (o nome está ao lado, por isso são decorativos e deviam ter `excludeFromSemantics`), o QR (precisa de "Código QR do cartão de sócio n.º …") e as capas das notícias (decorativas).
- **Estados que mudam e ninguém anuncia:** pagamento recebido, MB WAY expirado, mensagem enviada e ligação perdida ou recuperada.

### 2.3 Tamanho de texto

- Os textos usam o `textTheme` na maior parte dos sítios, por isso escalam com a letra do sistema. **Bom.**
- O cartão limita o crescimento da letra a 1,15× com `withClampedTextScaling` e escala tudo pela largura. É uma decisão consciente e bem testada (`test/widgets/cartao_visual_test.dart`).
- Há textos fixos abaixo de 12 px: a navegação (11), a hora do chat (11), o cartão (`11 × u`, pode descer para ~8,5 px num ecrã de 280 px) e a faixa "Sem ligação" (12,5).
- `AccaoRedonda` (`maxWidth: 76`, uma linha, reticências): com a letra a 200 %, "Faturas" e "Quotas" ficam cortadas. Com a letra grande, pode passar a duas linhas.
- `_BotaoVidro` e as pastilhas têm tamanho fixo. O ícone não cresce, o que está correcto, mas o alvo também não.

### 2.4 Alvos de toque

| Elemento | Tamanho | Material (48 dp) |
|---|---|---|
| Sino e chat do início | 40×40 | ✗ |
| Avatar do início | 42×42 | ✗ |
| Filtros da agenda | ~36 de altura, dentro de uma faixa de 40 | ✗ |
| `AccaoRedonda` | 52×52 + legenda | ✓ |
| Redes sociais | 52×52 | ✓ |
| Botões principais | 56 de altura | ✓ |
| `TextButton` e `OutlinedButton` | 48 de altura | ✓ |

### 2.5 Movimento

- Nenhum sítio lê `MediaQuery.disableAnimationsOf`. A rotação 3D do cartão (500 ms), o `InkSparkle` e o `AnimatedSize` da faixa de ligação correm sempre.

---

## 3. Inconsistências entre ecrãs

### 3.1 Cores fixas fora do tema (11)

| Cor | Onde | Problema |
|---|---|---|
| `#B7791F` (âmbar) | [widgets.dart:28](../lib/features/socio/pagamentos/widgets.dart#L28), [cartao_page.dart:53](../lib/features/socio/cartao/cartao_page.dart#L53), [pagar_sheet.dart](../lib/features/socio/pagamentos/pagar_sheet.dart) | Não muda no modo escuro, e o contraste é baixo no claro |
| `#8A5A12` (texto âmbar) | [pagar_sheet.dart:250](../lib/features/socio/pagamentos/pagar_sheet.dart#L250) | Ilegível no escuro (2,68:1) |
| `#12A15F` (verde "pago") | [widgets.dart:26](../lib/features/socio/pagamentos/widgets.dart#L26) | É o `verdeVivo` do tema repetido com outro nome |
| `#3DD68C`, `#FFB224` | [cartao_page.dart:336](../lib/features/socio/cartao/cartao_page.dart#L336) | O primeiro repete o `primary` escuro; nenhum tem nome |
| `#16181C` | [shell_page.dart:108](../lib/features/shell/shell_page.dart#L108) | Repete o `onSurface` claro; no escuro não se distingue |
| `#0B0D10` (QR, ×4) | cartão e bilhete | Correcto (o QR tem de ser escuro sobre branco), mas devia ser uma constante `Tema.qr` |
| `Colors.white` (43 usos) | gradientes, cartão, bilhetes | Aceitável sobre o gradiente, mas as opacidades (0,16 / 0,5 / 0,7 / 0,72 / 0,75 / 0,8 / 0,85) são sete valores para dois papéis |

`CoresEstado` é, na prática, um segundo tema paralelo e só para o modo claro. Os estados devem passar a ser `ThemeExtension` (secção 6).

### 3.2 Tamanhos de letra literais (21 usos, 11 valores)

`11 ×5 · 12 ×4 · 12,5 · 13 ×4 · 13,5 · 15 · 16 · 17 ×2 · 40 ×2 · 44`, mais alguns calculados. O `textTheme` já cobre quase todos estes papéis: o 13 é o `bodySmall`, o 40/44 é o `displaySmall`, o 12 é o `labelMedium`.

### 3.3 Raios (10 valores)

Tokens existentes: `raio = 24` e `raioPequeno = 16`. Valores literais (`BorderRadius.circular` e `Radius.circular`): `6 ×2 · 10 ×2 · 12 ×8 · 14 ×2 · 18 ×4 · 20 · 24 ×6 (repete Tema.raio) · 32 ×2 · 100 ×16`. O 100 é "pílula" e devia usar `StadiumBorder`. Os valores 10, 14, 18 e 20 são variações sem papel próprio.

### 3.4 Espaçamentos

- A grelha é quase toda de 8 e 4. Fogem-lhe `6`, `10` e `14` (paddings de 14 em `Bloco`, `AvisoErro`, cartões da agenda e notificações). Não é grave, mas `14` e `16` convivem sem critério.
- As margens horizontais do ecrã alternam entre `Tema.margem` (16) e `Tema.margem + 4` (20). O 20 aparece nos ecrãs de formulário e nos cabeçalhos públicos, e o 16 nas listas. Ao mudar de separador, o texto salta 4 px.

### 3.5 Widgets duplicados

| Papel | Cópias | Proposta |
|---|---|---|
| Linha "rótulo … valor" | `_Leitura` ([perfil_page.dart:316](../lib/features/socio/perfil/perfil_page.dart#L316)), `_Detalhe` ([meus_bilhetes_page.dart:301](../lib/features/publico/bilheteira/meus_bilhetes_page.dart#L301)), `_Linha` ([resultado_page.dart:223](../lib/features/socio/pagamentos/resultado_page.dart#L223)), a linha do detalhe da fatura, `_Linha` da bilheteira | `LinhaValor` em `core/widgets` |
| Caixa de aviso colorida | `AvisoErro` ([auth_widgets.dart](../lib/features/auth/auth_widgets.dart)), `_Aviso` ([cartao_page.dart:359](../lib/features/socio/cartao/cartao_page.dart#L359)), a caixa âmbar da folha de pagar, `AvisoDesactualizado` | `CaixaAviso(tom: erro/aviso/info/neutro)` |
| Pílula sobre o gradiente | `_Pastilha` ([inicio_page.dart:330](../lib/features/socio/inicio_page.dart#L330)), "Desde …" no clube, a categoria na notícia, o separador de dia no chat | `Pilula` |
| Estado vazio | `PainelEmPreparacao`, `_Vazio` (notícias), `_Vazio` (notificações), `_SemCartao`, o vazio da secretaria, `Bloco(Text(…))` ×5 | `EstadoVazio(icone, titulo, texto, accao?)`, separado do "em preparação" |
| Cabeçalho de zona | Notícias, Agenda, Bilhetes | `CabecalhoZona(sobretitulo, titulo, accao?)` |
| Marca "LPS" | `MarcaClube`, `_Cabecalho` do clube | um só widget, com o brasão |
| Formatador de euros | [formatos.dart](../lib/core/formatos.dart), [inicio_page.dart:84](../lib/features/socio/inicio_page.dart#L84), [seletor_conta.dart:10](../lib/features/socio/conta/seletor_conta.dart#L10) | usar só `euros()` |
| Mês abreviado | `_mesAno` manual ([quotas_page.dart:108](../lib/features/socio/pagamentos/quotas_page.dart#L108)) | `DateFormat('MMM y', 'pt_PT')` em `formatos.dart` |
| Primeira letra maiúscula | `_capital` ×3 | `capitalizar()` em `formatos.dart` |

### 3.6 Padrões de interacção

- **Erro:** o `ErroView` não tem ícone e não distingue "sem rede" de "erro do servidor". Tem pouco peso face aos estados vazios, que são mais cuidados.
- **Carregamento:** só spinners centrados. Com a cache, a espera é rara, mas o primeiro arranque de cada ecrã é sempre um spinner sobre o fundo.
- **Navegação para o detalhe:** as notícias usam `context.go`, e o resto da app usa `context.push`. Funciona porque a notícia é uma sub-rota, mas convém uniformizar.

---

## 4. Problemas técnicos de Flutter

| # | Problema | Onde | Efeito | Proposta |
|---|---|---|---|---|
| T1 | `addListener(() => setState(() {}))` em cada controlador | [perfil_page.dart:77](../lib/features/socio/perfil/perfil_page.dart#L77), [conversa_page.dart:55](../lib/features/socio/suporte/conversa_page.dart#L55) | Cada tecla reconstrói o formulário inteiro ou, no chat, a lista de mensagens | `ValueListenableBuilder` (ou `ListenableBuilder`) só à volta do botão que depende do texto |
| T2 | `IntrinsicWidth` em cada bolha | [conversa_page.dart:355](../lib/features/socio/suporte/conversa_page.dart#L355) | Duas passagens de layout por mensagem, O(n) mais caro em conversas longas | `Wrap` ou `Row(mainAxisSize: min)` com a hora em `Align`, ou um `Stack` com a hora posicionada |
| T3 | Efeitos laterais no `build` (oferecer a biometria, marcar notificações como vistas, abrir a folha de pagar) | [inicio_page.dart:96](../lib/features/socio/inicio_page.dart#L96), [notificacoes_page.dart:36](../lib/features/socio/notificacoes/notificacoes_page.dart#L36), `quotas_page.dart` | Dependem de *guards* manuais. Um rebuild a mais repete a acção se o *guard* falhar | `ref.listen` (ou `listenManual` no `initState`) em vez de fazer isto dentro do `build` |
| T4 | `FutureBuilder(future: PackageInfo.fromPlatform())` no `build` | [clube_page.dart:254](../lib/features/publico/clube/clube_page.dart#L254) | Um `Future` novo a cada rebuild | Um `FutureProvider` (já existe `versao_app.dart`) |
| T5 | `Scaffold` dentro de `Scaffold` | [noticia_page.dart:25](../lib/features/publico/noticias/noticia_page.dart#L25) | Dois `ScaffoldMessenger`/`AppBar` e insets em duplicado | `Scaffold` único, com o `appBar` condicional |
| T6 | `Opacity` sobre subárvores inteiras | bilhete usado, QR inválido | Camada extra de composição e perda de contraste | Cores com alfa nos filhos, ou um estado visual próprio (etiqueta "Usado" e texto normal) |
| T7 | `ListView(children: [...])` para listas que crescem (notificações e notícias paginadas, caderneta) | vários | Constrói tudo de uma vez. Hoje as listas são curtas, mas o histórico de notificações pagina | `ListView.builder` ou `SliverList.builder` nas listas paginadas |
| T8 | `NotificationListener` chama `carregar()` em cada evento de scroll | notícias e notificações | Tem *guard* (`aCarregar`), mas corre dezenas de vezes por segundo | Aceitável. Opcionalmente, reagir só a `ScrollEndNotification` ou usar um limiar |
| T9 | Cores e tamanhos que não vêm do `Theme` | secção 3.1 | O modo escuro parte-se nos sítios com cores fixas (C5) | `ThemeExtension<CoresLps>` |
| T10 | Nenhum `MediaQuery.disableAnimationsOf` | cartão, faixa | Ignora o "remover animações" do sistema | Duração `Duration.zero` quando o sistema o pedir |
| T11 | `3.14159265` literal | [cartao_page.dart:302](../lib/features/socio/cartao/cartao_page.dart#L302) | Legibilidade | `math.pi` |
| T12 | `MediaQuery.sizeOf(context).width * 0.8` para a altura da capa, e `0.78` para a largura da bolha | notícia, chat | Em tablets (a app pode correr num iPad) a capa fica enorme e as bolhas larguíssimas | Limitar com `min(…, 480)` e pôr o conteúdo em `ConstrainedBox(maxWidth: 600)` |
| T13 | Um ecrã por ficheiro não é seguido | `WalletPage`, `HistoricoPagamentosPage`, `AlterarPasswordPage`, `SessaoPage`, `BilhetePage` | Os ecrãs são difíceis de encontrar | Um ficheiro `*_page.dart` por ecrã |

**O que está bem:** `const` usado com consistência, `select` do Riverpod onde importa (`biometriaProvider.select`), `skipLoadingOnReload` para não piscar, `withClampedTextScaling` no cartão, `SafeArea` e `viewInsets` na folha de pagar, `PredictiveBackPageTransitionsBuilder` no Android, e imagens sempre por `ImagemRede`.

**Layouts responsivos:** a app está fixada na vertical ([orientacao.dart](../lib/core/orientacao.dart)) e os ecrãs são uma coluna. Em telemóveis está bem (o cartão foi testado de 280 a 430 px). O risco está nos **iPads**: a app é publicada no iOS e, sem `UIRequiresFullScreen` nem limite de largura, corre em ecrã inteiro, com linhas de 1000 px e a capa das notícias com 800 px de altura. A solução mínima é um `ConstrainedBox(maxWidth: 600)` centrado no `ShellPage`.

---

## 5. Lista priorizada

### Crítico (bloqueia utilizadores ou mostra conteúdo errado)

| ID | Problema | Esforço |
|---|---|---|
| **C1** | As imagens no corpo das notícias nunca aparecem (a app exige um `uid` que o contrato já não envia). Ao corrigir, mostrar também os blocos `video` | P |
| **C2** | Leitor de ecrã: 11 botões só com ícone sem nome e 7 `GestureDetector` sem semântica. Os pontos principais: o −/+ dos pagamentos e dos bilhetes, o sino e o chat, a biometria e as redes sociais | M |
| **C3** | Campos de formulário sem limite visível (1,09:1). Contorno `#84878D` (3,30:1) no estado normal | P |
| **C4** | Texto secundário a 4,10:1 em toda a app; etiquetas de estado a 2,9–3,4:1; `AvisoErro` a 3,17:1; bilhete usado a 2,24:1 | P (tokens) |
| **C5** | O aviso sobre dinheiro na folha de pagar fica ilegível no modo escuro (2,68:1), por causa de uma cor fixa | P |

### Importante (degrada a experiência ou a confiança)

| ID | Problema | Esforço |
|---|---|---|
| I1 | QR do cartão e do bilhete sem brilho máximo automático | P |
| I2 | Resultado do pagamento: referência sem botão de copiar, contagem do MB WAY escondida, "pago" sem anúncio, *haptic* nem celebração | M |
| I3 | Início do sócio em erro sem saída: não há como terminar a sessão (fica crítico com o `403 conta_sem_socio` das Contas v2) | P |
| I4 | Filtro vazio na agenda mostra "Brevemente" | P |
| I5 | Bilheteira: sem estado vazio das sessões, e o botão "Continuar" leva a um beco sem saída | P |
| I6 | Alvos de toque abaixo de 48 dp (sino, chat, avatar, filtros) | P |
| I7 | Texto abaixo de 12 px (navegação, hora do chat, cartão em ecrãs estreitos) | P |
| I8 | Animações sem respeito por "remover animações"; o gesto de virar o cartão não é anunciado | P |
| I9 | Cinco padrões diferentes de estado vazio; o `ErroView` sem ícone e sem distinguir "sem rede" | M |
| I10 | Perfil: botão de guardar escondido a meio do formulário; sem *autofill*; código postal e telefone sem validação | M |
| I11 | Chat: bolha vazia para anexos antigos (`anexo_url: null`); rebuild da página a cada tecla | P |
| I12 | Os estados de dívida têm duas palavras e duas cores ("Em dívida"/"Por pagar", vermelho/âmbar) | P |
| I13 | Efeitos laterais no `build` (T3) | M |
| I14 | Sem limite de largura em tablets (T12) | P |
| I15 | "Novo" e "activo" indicados só por cor ou forma | P |

### Cosmético (polimento e manutenção)

| ID | Problema |
|---|---|
| K1 | 11 cores e 21 tamanhos de letra fixos; 10 valores de raio (secção 3) |
| K2 | Widgets duplicados (secção 3.5) |
| K3 | Três formatadores de euros; o mês formatado à mão; `_capital` ×3 |
| K4 | Margens de 16 e de 20 alternadas; cabeçalhos assimétricos |
| K5 | "Pagar" com o ícone `+`; "Mais" repete o avatar |
| K6 | Marca "LPS" em texto em vez do brasão |
| K7 | Ícones das redes (Instagram) e das modalidades genéricos |
| K8 | O resultado com hífen (`2 - 1`) |
| K9 | Spinners em vez de esqueletos no primeiro carregamento (início, listas) |
| K10 | `Scaffold` aninhado na notícia (T5) |
| K11 | Ecrãs escondidos noutros ficheiros (T13) |
| K12 | `pi` literal (T11), `Opacity` (T6) |
| K13 | `Dismissible` sem acção semântica (há alternativa na conversa) |
| K14 | `FutureBuilder` com um `Future` criado no `build` (T4) |

**Ordem sugerida:** C1 → C3 + C4 + C5 (juntos: são os tokens da secção 6) → C2 → I3 → I2 → I1 → o resto dos importantes → os cosméticos à medida que se mexe em cada ecrã.

---

## 6. Design system proposto

**Enquadramento.** A app é de um clube: tem uma zona pública de conteúdo (notícias, agenda, bilhetes) e uma área pessoal que mexe em dinheiro (quotas, pagamentos). O público vai de miúdos das modalidades a sócios idosos. As consequências são:

- **Confiança antes de efeitos.** A superfície plana e a tipografia forte que a app já tem estão certas. O gradiente fica para os momentos de identidade (cabeçalho do sócio, cartão, bilhetes) e não para a interface em geral.
- **Legibilidade acima da média.** O corpo de texto começa em 16 px, o texto secundário cumpre sempre o AA e os alvos têm 48 dp.
- **Verde do clube a 10 %.** O verde aparece na acção principal, no item activo e nos sinais de marca. Os neutros ficam com os 60 % e o texto escuro com os 30 %.

> **Implementado** em `lib/core/theme/` a 2026-09-19 e ligado à app, sem alterar os ecrãs. A tabela da §6.2 ganhou os papéis que os ecrãs já usam: `headlineLarge` 30 (título de ecrã), `headlineSmall` 22, `titleSmall` 15 e `labelLarge` 15. A fonte de verdade é `app_typography.dart`.

A proposta **mantém** a linguagem actual (cores de marca, Inter, cartões arredondados sobre o fundo cinza-claro) e **corrige-a** em tokens.

### 6.1 Cor

**Marca**

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `marca` / `primary` | `#0B5D3B` | `#3DD68C` | Acção principal, item activo, sobretítulos |
| `marcaContainer` | `#DDF3E7` | `#0F3D27` | Fundo de pastilhas e de avatares |
| `gradienteClube` | `#0F7A4A → #0B5D3B → #06341F` | igual | Só no cabeçalho do sócio, no cartão, nos bilhetes e no destaque sem capa. O início **escurece** de `#14935A` para `#0F7A4A`: o branco passa de 3,92:1 para 5,38:1 |
| `sobreMarca` | branco 100 % (principal) e 90 % (secundário) | igual | Texto sobre o gradiente. **Opacidade mínima de 90 %** (4,69:1 no ponto mais claro) |

**Neutros**

| Token | Claro | Escuro | Nota |
|---|---|---|---|
| `fundo` (`surface`) | `#F4F5F7` | `#000000` | Os 60 % |
| `superficie` (`surfaceContainerLowest`) | `#FFFFFF` | `#16181B` | `Bloco`, folhas e campos |
| `texto` (`onSurface`) | `#16181C` | `#F2F3F5` | |
| `textoSecundario` (`onSurfaceVariant`) | **`#62656B`** (era `#75777D`) | `#8E9197` | 5,36:1 sobre o fundo e 5,84:1 sobre branco. No escuro: 5,63:1 |
| `contornoCampo` (`outline`) | **`#84878D`** (era `#D5D8DD`) | `#6B6F76` | 3,30:1 e 3,52:1. Só no limite dos componentes |
| `divisoria` (`outlineVariant`) | `#E8EAEE` | `#26292D` | Decorativo, sem mínimo |

**Estados** — um `ThemeExtension<CoresEstado>` que substitui o `abstract final class CoresEstado`. O texto ou ícone usa a cor `base` sobre o `container` (a base com alfa de 12 % no claro e 16 % no escuro).

| Estado | Claro | Contraste | Escuro | Contraste | Palavra única |
|---|---|---|---|---|---|
| `sucesso` | `#0F7A45` | 4,56:1 | `#3DD68C` | 6,93:1 | "Pago" |
| `aviso` | `#8F5B00` | 4,84:1 | `#FFB224` | 7,09:1 | "A aguardar" (ordem criada, MB WAY pendente) |
| `erro` | `#C4323A` | 4,52:1 | `#FF6369` | 4,93:1 | "Em dívida" (há valor por pagar) |
| `info` | `#1F5FBF` | 5,12:1 | `#7AB0FF` | 6,01:1 | Avisos neutros e "desactualizado" |
| `neutro` | `textoSecundario` | 5,36:1 | | | "Por vencer", "Isento", "Previsto", "Cancelado" |

Estas duas regras resolvem o I12:

- **"Em dívida"** (vermelho) é sempre um valor devido.
- **"A aguardar"** (âmbar) é sempre um pagamento iniciado e ainda não confirmado.

A expressão "Por pagar" deixa de existir como estado.

**Especiais:** `qr = #0B0D10` sobre branco em qualquer tema. A faixa "Sem ligação" usa `inverseSurface`/`onInverseSurface` do `ColorScheme`, e não um hex.

### 6.2 Tipografia

Uma família, **Inter** (já incluída). **Três pesos:** 400 corpo, 600 títulos e rótulos, 800 números grandes e títulos de ecrã. O 500 e o 700 saem: hoje há cinco pesos. Algarismos tabulares (`FontFeature.tabularFigures()`) em todos os valores em euros e contagens, para as colunas alinharem.

| Papel (`textTheme`) | Tamanho / altura de linha | Peso | Uso |
|---|---|---|---|
| `displaySmall` | 40/44 | 800, −1,2 | O valor em dívida ou o total. **Um só tamanho** (acaba o 40 contra 44) |
| `headlineMedium` | 28/34 | 800, −0,8 | Título de ecrã (Notícias, Área de sócio) |
| `titleLarge` | 20/26 | 600, −0,4 | Título de folha e de detalhe, `AppBar` |
| `titleMedium` | 17/24 | 600, −0,2 | Título de secção e de cartão |
| `bodyLarge` | 16/24 | 400 | Corpo de leitura (notícia, mensagem) |
| `bodyMedium` | 15/22 | 400 | Texto de lista e de formulário |
| `bodySmall` | 13/18 | 400 | Legendas e metadados, **sempre `textoSecundario`** |
| `labelMedium` | 12/16 | 600, +0,4 | Etiquetas de estado, pílulas, **legendas da navegação** (sobe de 11 para 12) e sobretítulos (+1,2, em maiúsculas) |

São oito papéis. A skill mobile recomenda no máximo quatro tamanhos por **ecrã**, e é essa a regra a aplicar ecrã a ecrã: nenhum ecrã precisa de mais do que quatro destes. **Nenhum `fontSize` literal fora de `tema.dart`**, com uma excepção: o cartão, que escala pela largura e deve derivar do `labelMedium` e do `titleMedium` multiplicados por `u`, com um mínimo de 10 px.

### 6.3 Espaçamento (grelha de 4 pt)

| Token | Valor | Uso |
|---|---|---|
| `e1` | 4 | Entre título e subtítulo da mesma linha |
| `e2` | 8 | Entre elementos relacionados; entre cartões numa lista compacta |
| `e3` | 12 | Entre cartões; entre campos do formulário |
| `e4` | 16 | **Margem lateral do ecrã (única: acaba o 20)**; padding interior do `Bloco` (acaba o 14) |
| `e5` | 24 | Antes de um título de secção; padding de folhas e diálogos |
| `e6` | 32 | Entre grupos (formulário → acção); topo dos ecrãs de entrada |
| `e7` | 48 | Estados vazios e respiro de fim de lista |

As regras de relação da skill aplicam-se assim: título de secção → bloco = `e2`; bloco → título de secção seguinte = `e5`, ou seja, o triplo. As listas com botão fixo em baixo reservam `e7 + 56` no fim.

### 6.4 Raios

| Token | Valor | Uso |
|---|---|---|
| `raioXs` | 8 | Miniaturas pequenas, marcas de posição no chat |
| `raioSm` | 12 | Miniaturas (notícia, evento, notificação), anexos, pastilha do resultado (substitui o 10 e o 14) |
| `raioMd` | 16 | Campos, avisos, snackbars, cartão físico, QR (é o `raioPequeno` actual) |
| `raioLg` | 24 | `Bloco`, cartões, capa de destaque (é o `raio` actual; substitui o 18 e o 20 das bolhas) |
| `raioXl` | 32 | Base do cabeçalho do sócio, topo das folhas |
| `pilula` | `StadiumBorder` | Botões, filtros, etiquetas, pílulas (substitui o `circular(100)` ×11) |

Um raio interior é igual ao raio exterior menos o padding (por exemplo, uma imagem dentro de um `Bloco` com 12 de padding leva 12), para os cantos ficarem concêntricos.

### 6.5 Sombras e elevação

A app é **plana** e deve continuar assim: separa por cor (branco sobre cinza), não por sombra. São só dois níveis, e sempre com a sombra tingida de verde e nunca preta pura:

| Nível | Definição | Uso |
|---|---|---|
| `nivel0` | sem sombra | `Bloco`, listas, campos (todo o resto) |
| `nivel1` | `BoxShadow(color: #06341F @ 14 %, blur: 20, offset: (0, 8))` | Objectos "físicos" sobre o fundo: o cartão de sócio e os bilhetes |
| `nivel2` | elevação do tema do `BottomSheet`/`Dialog` (Material) | Folhas e diálogos |

No modo escuro não há sombras. A profundidade vem da superfície mais clara (`#16181B` sobre `#000`).

### 6.6 Toque, movimento e iconografia

- **Toque:** mínimo de **48×48 dp** e 8 dp entre alvos. Os botões circulares visuais podem ter 40 px, desde que fiquem dentro de uma área tocável de 48.
- **Movimento:** 150 ms (micro: estados, cores), 250 ms (entrada e saída de elementos), 400 ms (transições de objecto, como o cartão). Curva `easeOutCubic` a entrar e saída mais rápida do que a entrada. Com `MediaQuery.disableAnimationsOf(context)`, a duração passa a zero.
- **Ícones:** só a família *Rounded* do Material (hoje há mistura de `_outlined`, `_rounded` e simples). O contorno fica para o estado inactivo e o preenchido para o activo. Os ícones acompanham sempre uma legenda ou um `tooltip`.
- **Marca:** o brasão (o mesmo `png`/`svg` do ícone da app) substitui o quadrado "LPS".

### 6.7 Como implementar em Flutter

1. Criar `lib/core/tema/tokens.dart` com `abstract final class Espaco { e1..e7 }`, `abstract final class Raio { xs..xl }` e as durações `Movimento { curto, medio, longo }`.
2. Criar `lib/core/tema/cores_estado.dart` com a `ThemeExtension<CoresEstado>` (as variantes `base` e `container`, com `claro()`, `escuro()` e `lerp`), registada em `Tema._tema(extensions: [...])`. Ler com `Theme.of(context).extension<CoresEstado>()!`.
3. Em `tema.dart`, mudar o `onSurfaceVariant` e o `outline`, dar ao `inputDecorationTheme.enabledBorder` o `BorderSide(color: c.outline)`, subir a legenda da navegação para 12, fixar a escala tipográfica da secção 6.2 e juntar `fontFeatures: [FontFeature.tabularFigures()]` ao `displaySmall` e ao `titleMedium`.
4. Criar em `core/widgets`: `LinhaValor`, `CaixaAviso(tom)`, `Pilula`, `EstadoVazio`, `CabecalhoZona`, `MarcaClube` (com o brasão) e `BotaoIcone` (um `IconButton` com `tooltip` obrigatório no construtor, que resolve o C2 de uma vez).
5. Juntar um teste que falhe se aparecer `Color(0x` ou `fontSize:` fora de `lib/core/tema/` (um `grep` no `test/`, do mesmo género dos testes que já existem).
6. Activar `flutter_test` com `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` e `textContrastGuideline` nos testes de widgets dos ecrãs principais. Detectam automaticamente os C2, C4 e I6 e impedem que voltem.
