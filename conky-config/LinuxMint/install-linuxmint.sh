#!/bin/bash

# Installation rapide pour Linux Mint
# Ce script installe tout automatiquement sans interaction
set -e

echo "🚀 Installation automatique de Conky (Linux Mint)"
echo "=================================================="
echo ""

# Vérifier si on est sur Linux Mint
if [ -f /etc/linuxmint/info ]; then
    echo "✅ Système Linux Mint détecté"
else
    echo "⚠️  Ce script est conçu pour Linux Mint."
    echo "   Il peut fonctionner sur d'autres distributions basées sur Ubuntu."
    echo ""
fi

# Installer Conky si nécessaire
if ! command -v conky &> /dev/null; then
    echo "📦 Installation de Conky et des dépendances..."
    sudo apt update
    sudo apt install -y conky-all fonts-roboto
    echo "✅ Conky installé"
else
    echo "✅ Conky déjà installé"
fi

# Créer les dossiers nécessaires
mkdir -p ~/.config/conky
mkdir -p ~/.config/autostart

# Sauvegarder l'ancienne config
if [ -f ~/.conkyrc ]; then
    backup="$HOME/.conkyrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp ~/.conkyrc "$backup"
    echo "💾 Ancienne config sauvegardée: $backup"
fi

# Copier les fichiers
echo "📁 Copie des fichiers de configuration..."
cp conky-linuxmint.conf ~/.conkyrc
cp conky-linuxmint.lua ~/.config/conky/conky-auto.lua
chmod 644 ~/.conkyrc
chmod 644 ~/.config/conky/conky-auto.lua

echo "   ✅ ~/.conkyrc"
echo "   ✅ ~/.config/conky/conky-auto.lua"

# Autostart
cat > ~/.config/autostart/conky.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Conky
Comment=Moniteur système Linux Mint
Exec=sh -c 'sleep 5 && conky'
Terminal=false
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF

echo "   ✅ ~/.config/autostart/conky.desktop"

echo ""
echo "🔍 DIAGNOSTIC RÉSEAU:"
echo "──────────────────────────────────────────────────"

# Test de détection des interfaces
interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|veth|br-)' | sed 's/@.*//')
if [ -z "$interfaces" ]; then
    echo "⚠️  ATTENTION: Aucune interface réseau détectée!"
    echo "   Vérifiez votre connexion réseau."
else
    echo "✅ Interfaces détectées:"
    for iface in $interfaces; do
        state=$(cat /sys/class/net/$iface/operstate 2>/dev/null || echo "unknown")
        ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ "$state" = "up" ]; then
            echo "   ✅ $iface → $state $([ -n "$ip_addr" ] && echo "($ip_addr)" || echo "(pas d'IP)")"
        else
            echo "   ⚠️  $iface → $state"
        fi
    done
fi

echo ""
echo "✅ Installation terminée !"
echo ""

# Arrêter Conky existant
killall conky 2>/dev/null || true
sleep 1

echo "🚀 Lancement de Conky..."
conky &
sleep 2

# Vérifier que Conky tourne
if pgrep -x conky > /dev/null; then
    echo "✅ Conky est actif et fonctionnel !"
else
    echo "❌ Erreur: Conky ne s'est pas lancé correctement"
    echo "   Lancez manuellement avec: conky -d"
    echo "   pour voir les erreurs"
fi

echo ""
echo "✨ Configuration terminée !"
echo ""
echo "📋 Commandes utiles:"
echo "  - Arrêter:     killall conky"
echo "  - Redémarrer:  killall conky && conky &"
echo "  - Debug:       conky -d"
echo "  - Éditer conf: nano ~/.conkyrc"
echo "  - Éditer Lua:  nano ~/.config/conky/conky-auto.lua"
echo ""
echo "🔄 Conky démarrera automatiquement au prochain redémarrage"
