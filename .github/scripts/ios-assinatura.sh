#!/usr/bin/env bash
# Prepara a assinatura de distribuição num Mac do GitHub Actions.
#
# Lê, do ambiente:
#   IOS_DIST_KEY          chave privada do certificado (PEM, sem palavra-passe)
#   IOS_DIST_CERT_BASE64  certificado "Apple Distribution" (.cer) em base64
#   IOS_PROFILE_BASE64    perfil "App Store Connect" (.mobileprovision) em base64
#   BUNDLE_ID             identificador da app
#
# Deixa:
#   $RUNNER_TEMP/assinatura.keychain-db          o certificado, pronto a assinar
#   ios/Flutter/Signing.xcconfig                 equipa, perfil e certificado do Runner
#   $RUNNER_TEMP/assinatura/ExportOptions.plist  para o `flutter build ipa`
#
# A equipa e o nome do perfil lêem-se do próprio perfil: não há mais nada a
# configurar. Antes de gastar um build, confirma que as três peças batem certo.
set -euo pipefail

falha() {
  echo "::error::$*"
  exit 1
}

for v in IOS_DIST_KEY IOS_DIST_CERT_BASE64 IOS_PROFILE_BASE64 BUNDLE_ID RUNNER_TEMP; do
  [ -n "${!v:-}" ] || falha "Falta $v."
done

raiz="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$RUNNER_TEMP/assinatura"
porta_chaves="$RUNNER_TEMP/assinatura.keychain-db"
# O LibreSSL do macOS, e não o OpenSSL 3 do Homebrew: o .p12 que este faz por
# omissão não é lido pelo `security import`.
ssl=/usr/bin/openssl

umask 077
mkdir -p "$dir"

# --- Os três ficheiros -------------------------------------------------------

printf '%s\n' "$IOS_DIST_KEY" | tr -d '\r' > "$dir/dist.key"
printf '%s' "$IOS_DIST_CERT_BASE64" | tr -d '[:space:]' | base64 --decode > "$dir/dist.cer" \
  || falha "IOS_DIST_CERT_BASE64 não é base64 válido."
printf '%s' "$IOS_PROFILE_BASE64" | tr -d '[:space:]' | base64 --decode > "$dir/perfil.mobileprovision" \
  || falha "IOS_PROFILE_BASE64 não é base64 válido."

# A Apple entrega o certificado em DER; aceita-se também em PEM.
"$ssl" x509 -inform DER -in "$dir/dist.cer" -out "$dir/dist.pem" 2>/dev/null \
  || "$ssl" x509 -inform PEM -in "$dir/dist.cer" -out "$dir/dist.pem" 2>/dev/null \
  || falha "IOS_DIST_CERT_BASE64 não é um certificado (.cer)."
"$ssl" x509 -in "$dir/dist.pem" -outform DER -out "$dir/dist.der"

publica_cert=$("$ssl" x509 -in "$dir/dist.pem" -noout -pubkey | "$ssl" sha256)
publica_chave=$("$ssl" pkey -in "$dir/dist.key" -passin pass: -pubout 2>/dev/null | "$ssl" sha256) \
  || falha "IOS_DIST_KEY não é uma chave privada PEM sem palavra-passe."
[ "$publica_cert" = "$publica_chave" ] \
  || falha "A chave (IOS_DIST_KEY) não é a do certificado (IOS_DIST_CERT_BASE64): o certificado tem de ter sido pedido com o .csr feito a partir desta chave."

nome_cert=$("$ssl" x509 -in "$dir/dist.pem" -noout -subject -nameopt multiline,utf8,-esc_msb \
  | sed -n 's/^ *commonName *= *//p' | head -1)
[ -n "$nome_cert" ] || falha "Não foi possível ler o nome do certificado."

# --- Porta-chaves temporário -------------------------------------------------

senha_p12=$("$ssl" rand -hex 16)
senha_porta_chaves=$("$ssl" rand -hex 16)
"$ssl" pkcs12 -export -inkey "$dir/dist.key" -in "$dir/dist.pem" \
  -name "$nome_cert" -out "$dir/dist.p12" -passout "pass:$senha_p12"

security delete-keychain "$porta_chaves" 2>/dev/null || true
security create-keychain -p "$senha_porta_chaves" "$porta_chaves"
security set-keychain-settings -lut 21600 "$porta_chaves"
security unlock-keychain -p "$senha_porta_chaves" "$porta_chaves"
security import "$dir/dist.p12" -P "$senha_p12" -A -t cert -f pkcs12 -k "$porta_chaves" > /dev/null
security set-key-partition-list -S apple-tool:,apple: -k "$senha_porta_chaves" "$porta_chaves" > /dev/null
security list-keychains -d user -s "$porta_chaves"

# --- Perfil, Signing.xcconfig e ExportOptions.plist --------------------------

security cms -D -i "$dir/perfil.mobileprovision" > "$dir/perfil.plist" 2>/dev/null \
  || falha "IOS_PROFILE_BASE64 não é um perfil (.mobileprovision)."

DIR="$dir" RAIZ="$raiz" NOME_CERT="$nome_cert" python3 - <<'PY'
import datetime
import os
import plistlib
import shutil
import sys

pasta = os.environ["DIR"]
raiz = os.environ["RAIZ"]
app = os.environ["BUNDLE_ID"]
nome_cert = os.environ["NOME_CERT"]

with open(f"{pasta}/perfil.plist", "rb") as f:
    perfil = plistlib.load(f)
with open(f"{pasta}/dist.der", "rb") as f:
    certificado = f.read()

direitos = perfil.get("Entitlements", {})
equipa = (perfil.get("TeamIdentifier") or [""])[0]
nome = perfil.get("Name", "")
uuid = perfil.get("UUID", "")
validade = perfil.get("ExpirationDate")
agora = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

erros = []
if not (equipa and nome and uuid):
    erros.append("O perfil não traz equipa, nome ou UUID.")
if direitos.get("application-identifier") != f"{equipa}.{app}":
    erros.append(
        f'O perfil é de "{direitos.get("application-identifier")}" e a app é '
        f'"{equipa}.{app}". Criar o perfil para o App ID {app}.'
    )
if perfil.get("ProvisionedDevices") or perfil.get("ProvisionsAllDevices") or direitos.get("get-task-allow"):
    erros.append(
        "O perfil não é de distribuição na App Store. Criá-lo em "
        "Profiles > Distribution > App Store Connect."
    )
if "com.apple.developer.associated-domains" not in direitos:
    erros.append(
        "O perfil não traz Associated Domains, que a app usa (Runner.entitlements). "
        "Activar a capacidade no App ID e gerar o perfil de novo."
    )
if certificado not in [bytes(c) for c in perfil.get("DeveloperCertificates", [])]:
    erros.append(
        "O perfil não foi criado com este certificado. Editar o perfil, escolher o "
        "certificado de IOS_DIST_CERT_BASE64 e descarregá-lo de novo."
    )
if validade and validade < agora:
    erros.append(f"O perfil expirou em {validade:%Y-%m-%d}. Gerar um novo.")

if erros:
    for erro in erros:
        print(f"::error::{erro}")
    sys.exit(1)

# O Xcode 16 mudou a pasta dos perfis; os anteriores lêem a antiga.
casa = os.path.expanduser("~")
for destino in (
    f"{casa}/Library/MobileDevice/Provisioning Profiles",
    f"{casa}/Library/Developer/Xcode/UserData/Provisioning Profiles",
):
    os.makedirs(destino, exist_ok=True)
    shutil.copyfile(f"{pasta}/perfil.mobileprovision", f"{destino}/{uuid}.mobileprovision")

# Lido pelo Release.xcconfig, que é a base só do alvo Runner: os pods não
# recebem perfil nenhum (e recusavam-no).
with open(f"{raiz}/ios/Flutter/Signing.xcconfig", "w", encoding="utf-8") as f:
    f.write(
        "CODE_SIGN_STYLE = Manual\n"
        f"DEVELOPMENT_TEAM = {equipa}\n"
        f"PROVISIONING_PROFILE_SPECIFIER = {nome}\n"
        f"CODE_SIGN_IDENTITY = {nome_cert}\n"
        f"CODE_SIGN_IDENTITY[sdk=iphoneos*] = {nome_cert}\n"
    )

with open(f"{pasta}/ExportOptions.plist", "wb") as f:
    plistlib.dump(
        {
            "method": "app-store-connect",
            "teamID": equipa,
            "signingStyle": "manual",
            "provisioningProfiles": {app: nome},
            "uploadSymbols": True,
            "manageAppVersionAndBuildNumber": False,
        },
        f,
    )

print(f"Equipa:      {equipa}")
print(f"Certificado: {nome_cert}")
print(f"Perfil:      {nome} (válido até {validade:%Y-%m-%d})" if validade else f"Perfil:      {nome}")
PY

echo "Certificado válido até: $("$ssl" x509 -in "$dir/dist.pem" -noout -enddate | cut -d= -f2)"
