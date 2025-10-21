#!/usr/bin/env bash
# Script portátil para OpenRocket 24.12 + JRE Temurin 17
set -Eeuo pipefail
trap 'echo "❌ Erro na linha $LINENO"; exit 1' ERR

JRE_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.9%2B9/OpenJDK17U-jre_x64_linux_hotspot_17.0.9_9.tar.gz"
JRE_SHA_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.9%2B9/OpenJDK17U-jre_x64_linux_hotspot_17.0.9_9.tar.gz.sha256.txt"
OR_URL="https://github.com/openrocket/openrocket/releases/download/release-24.12/OpenRocket-24.12.jar"

DEST="$HOME/openrocket-portable"
LAUNCHER="$HOME/rodar.sh"

echo "📁 Criando pasta de destino em: $DEST"
mkdir -p "$DEST"
cd "$DEST"

echo "🧩 [1/6] Baixando JRE portátil..."
wget -q --show-progress "$JRE_URL" -O jre.tar.gz
wget -q "$JRE_SHA_URL" -O jre.tar.gz.sha256.txt || true

echo "🔍 [2/6] Verificando integridade (SHA256)..."
if [ -f jre.tar.gz.sha256.txt ]; then
  sha256sum -c jre.tar.gz.sha256.txt
else
  echo "⚠️  SHA256 não disponível — seguindo mesmo assim."
fi

echo "📦 [3/6] Extraindo JRE para ./jre17 ..."
rm -rf jre17
mkdir -p jre17
# Extrai removendo o primeiro nível de diretório do tar
tar -xzf jre.tar.gz -C jre17 --strip-components=1
rm -f jre.tar.gz jre.tar.gz.sha256.txt

echo "🚀 [4/6] Baixando OpenRocket 24.12..."
wget -q --show-progress "$OR_URL" -O OpenRocket-24.12.jar

echo "⚙️ [5/6] Criando lançador em $LAUNCHER ..."
cat > "$LAUNCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$HOME/openrocket-portable/jre17/bin/java" -jar "$HOME/openrocket-portable/OpenRocket-24.12.jar"
EOF
chmod +x "$LAUNCHER"

echo "✅ [6/6] Tudo pronto. Abrindo o OpenRocket..."
sleep 1
"$LAUNCHER"
