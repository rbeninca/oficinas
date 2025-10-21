#!/usr/bin/env bash
set -euo pipefail

# Fedora Dev Workstation Setup (somente clientes/ ferramentas)
# Corrigido: Insync repo + fallback; JDK 21; Notepad Next (Flatpak)

if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Execute como root: sudo $0"
  exit 1
fi

command -v dnf >/dev/null || { echo "❌ dnf não encontrado — este script é para Fedora."; exit 1; }

echo "==> Atualizando sistema e base..."
dnf -y update
dnf -y install dnf-plugins-core curl gnupg2 ca-certificates flatpak

# ---------- Repositórios ----------
echo "==> Adicionando repositórios de terceiros..."

# Google Chrome
cat > /etc/yum.repos.d/google-chrome.repo <<'EOF'
[google-chrome]
name=google-chrome - x86_64
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Visual Studio Code
cat > /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Docker CE
curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo || true

# Insync (com $releasever correto)
cat > /etc/yum.repos.d/insync.repo <<'EOF'
[insync]
name=insync repo
baseurl=http://yum.insync.io/fedora/$releasever/
gpgcheck=1
gpgkey=https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key
enabled=1
metadata_expire=120m
EOF

echo "==> Instalando pacotes principais..."
# OBS: JDK troca para 21 (LTS disponível no Fedora 42)
dnf -y install \
  google-chrome-stable \
  code \
  nmap \
  openssh-clients \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  git \
  java-21-openjdk java-21-openjdk-devel \
  android-tools \
  cmake make gcc-c++ gdb strace ltrace \
  python3 python3-pip nodejs npm \
  vim-enhanced

# Grupos de desenvolvimento
#echo "==> Instalando toolchains de desenvolvimento..."
#dnf -y groupinstall "Development Tools" "C Development Tools and Libraries"
echo "==> Instalando toolchains de desenvolvimento (compatível com dnf5)..."
dnf -y group install "Development Tools" "C Development Tools and Libraries" --with-optional || \
dnf -y group upgrade "Development Tools" "C Development Tools and Libraries" --with-optional || \
dnf -y install @development-tools @c-development


# ---------- Flatpak ----------
echo "==> Configurando Flathub..."
if ! flatpak remotes | grep -q flathub; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "==> Instalando Android Studio (Flatpak) e Notepad Next..."
flatpak -y install flathub com.google.AndroidStudio
flatpak -y install flathub com.github.dail8859.NotepadNext

# ---------- Insync com fallback automático ----------
echo "==> Instalando Insync (tentando versão do seu Fedora; aplica fallback se necessário)..."
if ! dnf -y install insync; then
  # fallback progressivo: 41 -> 40
  for VER in 41 40; do
    echo "   - Repositório do Insync para Fedora $VER (fallback)..."
    sed -i "s|^baseurl=.*|baseurl=http://yum.insync.io/fedora/${VER}/|" /etc/yum.repos.d/insync.repo
    if dnf -y makecache --disablerepo='*' --enablerepo='insync' && dnf -y install insync; then
      echo "   ✔️  Insync instalado a partir do repo Fedora $VER."
      break
    fi
  done
fi

# ---------- Docker ----------
systemctl enable --now docker.service
if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  groupadd -f docker
  usermod -aG docker "${SUDO_USER}" || true
  echo "Usuário ${SUDO_USER} adicionado ao grupo docker (logout/login necessário)."
fi

# ---------- Extensões do VS Code ----------
echo "==> Instalando extensões do VS Code (GitLens, Five Server, Remote SSH)..."
sudo -u "${SUDO_USER:-root}" code --install-extension eamodio.gitlens --force || true
sudo -u "${SUDO_USER:-root}" code --install-extension yandeu.five-server --force || true
sudo -u "${SUDO_USER:-root}" code --install-extension ms-vscode-remote.remote-ssh --force || true

dnf -y makecache || true

cat <<'EOT'

✅ Instalação concluída!

Incluído:
• Chrome, VS Code (+ GitLens, Five Server, Remote SSH), Git, Vim
• Docker CE (+ Compose v2 e Buildx) — serviço habilitado
• OpenJDK 21 (runtime + devel)
• android-tools (adb, fastboot) + Android Studio (Flatpak)
• Notepad Next (Flatpak) — alternativa moderna ao Notepad++
• Toolchains: gcc/g++, make, cmake, gdb, python3/pip, nodejs/npm
• Insync (com fallback automático de repo, se necessário)

Se quiser Java 17 especificamente (quando não disponível no Fedora 42),
pode usar o repositório Adoptium (Temurin). Ex.: 
  sudo dnf install adoptium-temurin-java-repository
  sudo dnf install temurin-17-jdk

Testes:
  docker run --rm hello-world
  code --list-extensions
  adb version
  flatpak run com.github.dail8859.NotepadNext
  flatpak run com.google.AndroidStudio
  insync start --no-daemon &

EOT

