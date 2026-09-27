# Publicar a LPS Neo na Google Play

Tudo o que a Play Console pede, pronto a copiar. A app substitui a
**"Leões Porto Salvo App Oficial"** (`pt.magicspider.mslps`), por isso é uma
**actualização** da ficha que já existe, não uma app nova.

| Ficheiro | Onde vai |
|---|---|
| `../../build/app/outputs/bundle/release/LPS-Neo-2.0.0+18.aab` | Testar e lançar → versão (gerado localmente, fora do git) |
| `icone-512.png` | Ficha da loja → Ícone da app (512×512) |
| `destaque-1024x500.png` | Ficha da loja → Imagem de destaque |
| `capturas/01…07.png` | Ficha da loja → Capturas de ecrã do telemóvel (1440×2880, 2:1) |

As capturas foram tiradas da app contra a produção, só na zona pública — não
mostram dados pessoais de ninguém.

---

## 1. Ficha principal da loja

*Aumentar número de utilizadores → Presença na loja → Ficha principal da loja.*

**Nome da app** (máx. 30) — manter o que já tem, que é o que as pessoas procuram:

```
Leões Porto Salvo App Oficial
```

**Descrição breve** (máx. 80):

```
Notícias, jogos, bilhetes e a área de sócio dos Leões de Porto Salvo.
```

**Descrição completa** (máx. 4000):

```
A app oficial do Clube Recreativo Leões de Porto Salvo, feita de novo de raiz. Tudo o que se passa no clube, num só sítio — para sócios e para todos os adeptos.

PARA TODOS, SEM CONTA
• Notícias do clube e de todas as modalidades
• Agenda de jogos e eventos, com os próximos e os anteriores
• Resultados, fichas de jogo e as competições em que o clube joga
• As modalidades, a história do clube, contactos e horários

COM UMA CONTA (não é preciso ser sócio)
• Bilhetes: compre por MB WAY ou Multibanco e entre com o código no telemóvel, sem imprimir
• Comunidade Leões: adivinhe o resultado dos jogos, ajude a registar os resultados e participe nos passatempos do clube
• Avisos na app: pagamentos, decisões da secretaria e novidades do clube

ÁREA DE SÓCIO
• Cartão de sócio digital, com o QR para a entrada
• Quotas, faturas e pagamentos, com MB WAY ou referência Multibanco
• Saldo da conta corrente
• Inscrições em modalidades e inscrição de novos sócios
• Encarregados de educação acompanham os educandos na mesma app
• Falar com a secretaria sem sair da app

Entre com o email ou com o seu número de sócio. Se usava a app antiga, entre de novo — a sua ficha de sócio continua a mesma.

Leões de Porto Salvo — desde 1970.
```

**Recursos gráficos:** ícone, imagem de destaque e as 7 capturas desta pasta, por
esta ordem.

**Categoria:** *Configuração da loja* → Tipo **App**, categoria **Desporto**.

**Detalhes de contacto:** email `secretaria@leoesdeportosalvo.pt`, site
`https://www.leoesdeportosalvo.pt/`, telefone `+351 214 214 705`.

---

## 2. Notas da versão

```
<pt-PT>
Nova app dos Leões de Porto Salvo, feita de raiz.

• Notícias, agenda, jogos e resultados, sem precisar de conta
• Bilhetes: compre e leve-os no telemóvel
• Zona de sócio: quotas, pagamentos por MB WAY e Multibanco, cartão e documentos
• Faça-se sócio pela app
• Comunidade: adivinhe os resultados, suba na classificação, escolha o seu leão e participe nos passatempos
• Notificações do clube
</pt-PT>
```

---

## 3. Conteúdo da app (Política → Conteúdo da app)

### Política de privacidade

```
https://mylps.leoesdeportosalvo.pt/lps/privacidade
```

> **Recusa de 26/09/2026:** a ficha ainda tinha a política da app antiga
> (`www.leoesdeportosalvo.pt/politica-privacidade-aplicacao/`, que dá 404 desde que
> o WordPress mudou), e o link de eliminação na *Segurança dos dados* estava
> inválido. Os dois URLs desta página respondem 200. Depois de os mudar, reenviar
> em *Visão geral da publicação*.

### Acesso à app

**Todas ou algumas funcionalidades estão restritas.** Dar ao revisor da Google
uma conta de teste que funcione (a Google recusa a versão se não conseguir entrar):

- Nome: `Conta de teste da Google`
- Email/número e palavra-passe: **criar uma conta própria para isto** — de
  preferência uma ficha de sócio de teste no CISOC, para a área de sócio abrir.
  Não usar a de ninguém.
- Instruções: `Toque em "Sócio" (último separador) e entre com o email e a
  palavra-passe. Sem conta, as notícias, a agenda e o clube estão abertos a todos.`

### Anúncios

**Não, a app não contém anúncios.**

### ID de publicidade

**Não** (já respondido).

### Classificação de conteúdo

Questionário IARC — categoria **"Todas as outras categorias de apps"**. Respostas:
violência, sexo, linguagem, substâncias, jogos de azar — tudo **Não**.

- *Os utilizadores podem interagir ou trocar conteúdo?* **Não** — não há chat
  entre utilizadores nem texto livre; na Comunidade só aparece uma alcunha
  numa classificação. (O suporte é só com a secretaria do clube.)
- *Partilha a localização do utilizador?* **Não**.
- *Compras digitais?* **Não** — vendem-se bilhetes para eventos reais e
  pagam-se quotas, fora da faturação da Google Play.
- *Passatempos com prémios* não são jogos de azar: não se aposta nada.

Resultado esperado: **PEGI 3 / Todos**.

### Público-alvo e conteúdo

- Faixas etárias: **13–15**, **16–17** e **18 ou mais**. **Não** marcar abaixo de
  13 — menores de 13 não têm conta própria; quem usa a app por eles é o
  encarregado de educação.
- *A app pode atrair crianças involuntariamente?* **Não**.

### Apps de notícias

**Não** — é a app de um clube (categoria Desporto), não uma app de notícias.

### Funcionalidades financeiras

**A minha app não oferece nenhuma destas funcionalidades.** Os pagamentos são de
quotas e bilhetes ao próprio clube, por um prestador de pagamentos (IfthenPay).

### Saúde / Governo / COVID-19

**Não** a todas.

### Eliminação de dados (conta)

- *A app permite criar contas?* **Sim**.
- *URL de eliminação da conta:*
  ```
  https://mylps.leoesdeportosalvo.pt/lps/conta/eliminar
  ```
  Vai no formulário da **Segurança dos dados** (secção *Eliminação de dados*), que é
  onde a Google o verifica. Colá-lo sem espaços nem texto à volta, com `https://`.
- Na app: *Conta → Eliminar a conta* (ou *Dados pessoais → Eliminar conta da app*).
- *Também permite pedir a eliminação de alguns dados sem eliminar a conta?*
  **Não** (isso trata-se com a secretaria).

### Segurança dos dados

**Visão geral**

| Pergunta | Resposta |
|---|---|
| A app recolhe ou partilha dados? | **Sim** |
| Os dados são encriptados em trânsito? | **Sim** |
| Os utilizadores podem pedir a eliminação? | **Sim** (URL acima) |
| Partilha com terceiros? | **Não** — a IfthenPay, o Firebase e a Cloudflare são prestadores de serviços, que a Google não conta como partilha |

**Tipos de dados recolhidos** (em todos: *Recolhidos* = Sim, *Partilhados* = Não,
*Tratamento efémero* = Não):

| Categoria → tipo | Obrigatório? | Para quê |
|---|---|---|
| Informações pessoais → **Nome** | Obrigatório | Funcionalidade da app; Gestão da conta |
| Informações pessoais → **Endereço de email** | Obrigatório | Funcionalidade da app; Gestão da conta; Comunicações do programador |
| Informações pessoais → **IDs do utilizador** (conta, n.º de sócio) | Obrigatório | Funcionalidade da app; Gestão da conta |
| Informações pessoais → **Morada** (ficha de sócio) | Opcional | Funcionalidade da app |
| Informações pessoais → **Número de telefone** (MB WAY, ficha) | Opcional | Funcionalidade da app |
| Informações pessoais → **Outras informações** (data de nascimento, NIF) | Obrigatório | Funcionalidade da app; Gestão da conta |
| Informações financeiras → **Histórico de compras** (bilhetes, quotas, pagamentos) | Opcional | Funcionalidade da app |
| Fotos e vídeos → **Fotos** (fotografia de sócio, anexos ao suporte) | Opcional | Funcionalidade da app |
| Mensagens → **Outras mensagens na app** (suporte com a secretaria) | Opcional | Funcionalidade da app |
| Ficheiros e documentos → **Ficheiros e documentos** (anexos ao suporte) | Opcional | Funcionalidade da app |
| Atividade na app → **Outras ações** (palpites, resultados relatados, passatempos) | Opcional | Funcionalidade da app |
| IDs do dispositivo ou outros → **IDs do dispositivo** (token de notificações) | Opcional | Funcionalidade da app |

**Não recolhe:** localização, contactos, calendário, saúde, áudio, histórico de
navegação, registos de falhas/diagnóstico, dados de cartões de pagamento.
A biometria fica no telemóvel e nunca sai dele.

---

## 4. Lançar

1. *Testar e lançar → Testar → Testes internos → Criar nova versão*: carregar o
   `.aab` 18, notas da versão, **Guardar e publicar**; testar com a lista de
   testadores.
2. Quando estiver bem: *Produção → Criar nova versão → Adicionar a partir da
   biblioteca* (o mesmo `.aab`), com **lançamento faseado** (começar em 10–20%).
3. A primeira versão de produção vai a revisão — normalmente de algumas horas a
   poucos dias.

**Antes de produção**, o clube revê os textos da política e dos termos (pedido
`2026-09-25-paginas-web-lojas` no CISOC): responsável pelo tratamento, DPO,
prazos de conservação, alojamento.
