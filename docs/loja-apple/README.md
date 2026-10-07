# Publicar a LPS Neo na App Store

No iOS a app nunca existiu: é uma **publicação nova**, com o mesmo identificador
do Android (`pt.magicspider.mslps`).

Não é preciso Mac. Quem compila e assina é o GitHub Actions:

| Workflow | Para quê | Arranque |
|---|---|---|
| `.github/workflows/ios.yml` | Confirma que a app compila em iOS; deixa um `.ipa` **sem assinatura** | Sozinho nos pull requests que mexem em `ios/` ou no `pubspec`; à mão em Actions |
| `.github/workflows/ios-testflight.yml` | Compila, **assina** e envia para o TestFlight | Só à mão: Actions → iOS TestFlight → Run workflow |

O segundo precisa de seis segredos no repositório. O resto desta página é como
se obtêm, uma vez, e o que fazer quando caducam.

---

## 1. No Apple Developer

*<https://developer.apple.com/account> → Certificates, Identifiers & Profiles.*

### 1.1 App ID

*Identifiers → + → App IDs → App.*

- **Description:** `LPS Neo`
- **Bundle ID:** *Explicit* → `pt.magicspider.mslps`
- **Capabilities:** marcar **Associated Domains** (a app usa-a para os links
  partilhados, `ios/Runner/Runner.entitlements`; sem ela a assinatura falha).
  Marcar também **Push Notifications**, para não ter de refazer o perfil quando
  o push chegar ao iOS.

### 1.2 Chave e pedido de certificado

No Git Bash, numa pasta **fora do repositório**:

```bash
openssl genrsa -out ios_dist.key 2048
openssl req -new -key ios_dist.key -out ios_dist.csr -subj "/CN=Magic Spider/C=PT"
```

O `ios_dist.key` é a chave privada da assinatura. Guardar uma cópia num sítio
seguro e nunca a pôr no git: com ela e com o certificado, assina-se em nome da
conta.

### 1.3 Certificado

*Certificates → + → **Apple Distribution** → escolher o `ios_dist.csr` →
Download.* Fica um `distribution.cer`.

### 1.4 Perfil

*Profiles → + → Distribution → **App Store Connect** → App ID `LPS Neo` →
o certificado do passo anterior → nome `LPS Neo App Store` → Download.* Fica um
`LPS_Neo_App_Store.mobileprovision`.

## 2. Na App Store Connect

*<https://appstoreconnect.apple.com>.*

### 2.1 A app

*Apps → + → New App.* Plataforma iOS, idioma principal Português (Portugal),
Bundle ID `pt.magicspider.mslps`, SKU `lpsneo`. O nome tem de ser único na loja.

### 2.2 Chave da API (para o envio)

*Users and Access → Integrations → App Store Connect API → Team Keys → +.*
Nome `GitHub Actions`, acesso **App Manager**. Apontar o **Key ID** e o
**Issuer ID** e descarregar o `AuthKey_XXXXXXXXXX.p8` — só se descarrega uma vez.
Na primeira vez a página pede para activar o acesso à API; só o titular da
conta o pode fazer.

## 3. Os segredos no GitHub

*Repositório → Settings → Secrets and variables → Actions → New repository
secret.* No Git Bash, cada comando copia o valor para a área de transferência;
depois é colar no campo *Secret*.

| Segredo | Valor |
|---|---|
| `IOS_DIST_KEY` | `cat ios_dist.key \| clip` |
| `IOS_DIST_CERT_BASE64` | `base64 -w0 distribution.cer \| clip` |
| `IOS_PROFILE_BASE64` | `base64 -w0 LPS_Neo_App_Store.mobileprovision \| clip` |
| `ASC_KEY_ID` | o Key ID |
| `ASC_ISSUER_ID` | o Issuer ID |
| `ASC_KEY_P8` | `cat AuthKey_XXXXXXXXXX.p8 \| clip` |

A equipa (Team ID) e o nome do perfil não se configuram: o workflow lê-os do
próprio perfil.

## 4. Enviar uma versão

*Actions → iOS TestFlight → Run workflow.*

A versão e o número de build são os do `pubspec.yaml` (`2.0.0+18` → versão
`2.0.0`, build `18`). A App Store Connect recusa um número de build repetido
dentro da mesma versão: ou se sobe o `+N` no `pubspec`, ou se escreve outro
número no campo do Run workflow.

Antes de compilar, o workflow confirma em segundos que a chave é a do
certificado, que o perfil é de App Store, desta app, feito com este certificado
e com Associated Domains — e diz qual falhou.

Depois do envio o build demora uns minutos a ser processado e aparece em
*App Store Connect → a app → TestFlight*. Se a Apple encontrar um problema no
processamento, avisa por email a conta.

## 5. Quando caduca

| O quê | Validade | O que fazer |
|---|---|---|
| Certificado Apple Distribution | 1 ano | Repetir 1.3 com o mesmo `ios_dist.csr`, refazer o perfil (1.4) e actualizar `IOS_DIST_CERT_BASE64` e `IOS_PROFILE_BASE64` |
| Perfil | 1 ano, ou quando muda o certificado ou as capacidades do App ID | Repetir 1.4 e actualizar `IOS_PROFILE_BASE64` |
| Chave da API | Não caduca | Revogar e criar outra se sair de mãos |

O workflow escreve no registo as datas de validade do certificado e do perfil.

## 6. O que falta para a loja

- **Push em iOS.** A app corre sem push em iOS (`lib/core/push/firebase.dart`):
  falta registar a app iOS no projecto Firebase `mylps-3fbdb`, a chave APNs e
  o direito `aps-environment`.
- **Universal Links.** O site tem de servir
  `/.well-known/apple-app-site-association` com o Team ID.
- **Ficha da loja.** Capturas de ecrã, descrição, privacidade e classificação
  etária, como em `../loja-play/README.md`.
