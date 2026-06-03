#!/bin/bash
# ============================================
# Script d'installation GNS3 sur Kali Linux
# Auteur : ab060 - Abdallahi
# ============================================

set -e
USER_HOME="/home/ab060"
VENV="$USER_HOME/gns3-env"
GNS3_DIR="$USER_HOME/GNS3"
ICONS_DIR="$USER_HOME/.local/share/icons"
APPS_DIR="$USER_HOME/.local/share/applications"

echo "============================================"
echo "   Installation GNS3 sur Kali Linux"
echo "============================================"

# ── Étape 1 : Dépendances système ──────────────
echo ""
echo "[1/9] Installation des dépendances système..."
sudo apt update -y
sudo apt install -y \
    python3-pip python3-pyqt5 python3-pyqt5.qtsvg \
    python3-pyqt5.qtwebsockets vpcs \
    openvswitch-switch docker.io \
    git libpcap-dev cmake \
    qemu-system-x86 wireshark \
    software-properties-common

# ── Étape 2 : Compiler ubridge ─────────────────
echo ""
echo "[2/9] Compilation de ubridge..."
if [ ! -f "/usr/local/bin/ubridge" ]; then
    cd "$USER_HOME"
    if [ ! -d "$USER_HOME/ubridge" ]; then
        git clone https://github.com/GNS3/ubridge.git "$USER_HOME/ubridge"
    fi
    cd "$USER_HOME/ubridge"
    make
    sudo make install
    echo "ubridge installé avec succès."
else
    echo "ubridge déjà installé, on passe."
fi

# ── Étape 3 : Environnement virtuel Python ─────
echo ""
echo "[3/9] Création de l'environnement virtuel Python..."
if [ ! -d "$VENV" ]; then
    python3 -m venv "$VENV" --system-site-packages
fi
source "$VENV/bin/activate"

# ── Étape 4 : Installation GNS3 ───────────────
echo ""
echo "[4/9] Installation de GNS3 (server + GUI)..."
pip install --upgrade pip
pip install PyQt5 PyQt5-sip
pip install gns3-server gns3-gui

deactivate

# ── Étape 5 : Script de lancement ─────────────
echo ""
echo "[5/9] Création du script de lancement..."
cat > "$USER_HOME/launch-gns3.sh" << 'EOF'
#!/bin/bash
source /home/ab060/gns3-env/bin/activate
exec gns3
EOF
chmod +x "$USER_HOME/launch-gns3.sh"

# ── Étape 6 : Icône et lanceur desktop ────────
echo ""
echo "[6/9] Configuration de l'icône et du lanceur..."
mkdir -p "$ICONS_DIR"
ICON_SRC="$VENV/lib/python3.13/site-packages/gns3/linux/icons/hicolor/48x48/apps/gns3.png"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$ICONS_DIR/gns3.png"
else
    echo "Icône non trouvée, utilisation d'une icône générique."
fi

mkdir -p "$APPS_DIR"
cat > "$APPS_DIR/gns3.desktop" << EOF
[Desktop Entry]
Version=1.0
Name=GNS3
Comment=Network Simulator
Exec=$USER_HOME/launch-gns3.sh
Icon=$ICONS_DIR/gns3.png
Terminal=false
Type=Application
Categories=Network;Education;
StartupNotify=true
EOF
chmod +x "$APPS_DIR/gns3.desktop"
update-desktop-database "$APPS_DIR" 2>/dev/null || true

# ── Étape 7 : Services système ────────────────
echo ""
echo "[7/9] Activation des services..."
sudo systemctl enable docker 2>/dev/null || true
sudo systemctl start docker 2>/dev/null || true
sudo systemctl enable openvswitch-switch 2>/dev/null || true
sudo systemctl start openvswitch-switch 2>/dev/null || true

# ── Étape 8 : Groupes utilisateur ────────────
echo ""
echo "[8/9] Ajout de l'utilisateur aux groupes..."
sudo usermod -aG docker,wireshark,kvm ab060 2>/dev/null || true

# ── Étape 9 : Appliances et images GNS3 ───────
echo ""
echo "[9/9] Configuration des appliances GNS3..."
mkdir -p "$GNS3_DIR/appliances"
mkdir -p "$GNS3_DIR/images/QEMU"

# Cloner le registre GNS3
if [ ! -d "$USER_HOME/gns3-registry" ]; then
    git clone https://github.com/GNS3/gns3-registry.git "$USER_HOME/gns3-registry"
fi
cp "$USER_HOME/gns3-registry/appliances/"*.gns3a "$GNS3_DIR/appliances/" 2>/dev/null || true

# Créer le disque vide nécessaire pour FortiGate
if [ ! -f "$GNS3_DIR/images/QEMU/empty30G.qcow2" ]; then
    qemu-img create -f qcow2 "$GNS3_DIR/images/QEMU/empty30G.qcow2" 30G
    echo "Disque empty30G.qcow2 créé."
fi

# Copier l'image FortiGate si elle existe dans Downloads
FORTIGATE_SRC=$(find "$USER_HOME/Downloads" -name "fortios.qcow2" 2>/dev/null | head -1)
if [ -n "$FORTIGATE_SRC" ]; then
    cp "$FORTIGATE_SRC" "$GNS3_DIR/images/QEMU/FGT_VM64_KVM-v7.4.12.M-build2902-FORTINET.out.kvm.qcow2"
    echo "Image FortiGate copiée."
fi

# Copier l'image OpenWrt si elle existe dans Downloads
OPENWRT_SRC=$(find "$USER_HOME/Downloads" -name "openwrt*.img" 2>/dev/null | head -1)
if [ -n "$OPENWRT_SRC" ]; then
    cp "$OPENWRT_SRC" "$GNS3_DIR/images/QEMU/"
    echo "Image OpenWrt copiée."
fi

# ── Résumé ────────────────────────────────────
echo ""
echo "============================================"
echo "   Installation terminée avec succès !"
echo "============================================"
echo ""
echo "  ✅ GNS3 installé dans : $VENV"
echo "  ✅ Lanceur créé      : $USER_HOME/launch-gns3.sh"
echo "  ✅ Icône desktop     : $APPS_DIR/gns3.desktop"
echo "  ✅ Appliances        : $GNS3_DIR/appliances/"
echo "  ✅ Images QEMU       : $GNS3_DIR/images/QEMU/"
echo ""
echo "  ⚠️  Redémarre ta session pour appliquer les groupes !"
echo ""
echo "  Pour lancer GNS3 : ./launch-gns3.sh"
echo "============================================"
