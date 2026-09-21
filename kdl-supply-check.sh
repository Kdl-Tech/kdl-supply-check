#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  KDL Supply Check — détecteur de compromission de chaîne d'approvisionnement
#  npm (famille Shai-Hulud / ChainDrop et suivantes).
#
#  KDL TECH — https://kdl-tech.fr
#
#  Ce que fait ce script :
#    • il cherche les traces d'infection sur la machine,
#    • il ne modifie RIEN sans que vous le demandiez explicitement,
#    • il distingue une vraie trouvaille d'un fichier au nom trompeur.
#
#  Le piège que ce script évite : le ver installe un « dead man's switch »,
#  un veilleur qui surveille le jeton volé et déclenche une destruction de
#  données quand vous le révoquez. Il faut donc TOUJOURS neutraliser le
#  veilleur AVANT de toucher au moindre mot de passe. Ce script le cherche
#  en premier et vous le dit avant tout le reste.
#
#  Usage :
#    ./kdl-supply-check.sh              # analyse seule, ne touche à rien
#    ./kdl-supply-check.sh --nettoyer   # propose de neutraliser ce qu'il trouve
#    ./kdl-supply-check.sh --silencieux # sortie courte, pour un script
#    ./kdl-supply-check.sh --machine    # sortie stable pour un programme
#                                       # (KDL Toolbox), lecture seule
# ═══════════════════════════════════════════════════════════════════════════

set -uo pipefail

VERSION="1.1"
NETTOYER=0
SILENCIEUX=0
MACHINE=0
for arg in "$@"; do
  case "$arg" in
    --nettoyer)   NETTOYER=1 ;;
    --silencieux) SILENCIEUX=1 ;;
    --machine)    MACHINE=1; SILENCIEUX=1 ;;
    --version)    echo "kdl-supply-check $VERSION"; exit 0 ;;
    --aide|-h)    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
# Mode machine = analyse seule : il ne neutralise jamais rien.
if [ "$MACHINE" -eq 1 ] && [ "$NETTOYER" -eq 1 ]; then
  echo "ERREUR	--machine et --nettoyer sont incompatibles (le mode machine ne modifie rien)" >&2
  exit 64
fi

# ─── Couleurs, seulement si la sortie est un terminal ───
if [ -t 1 ] && [ "$SILENCIEUX" -eq 0 ]; then
  R=$'\e[31m'; V=$'\e[32m'; J=$'\e[33m'; B=$'\e[34m'; G=$'\e[1m'; Z=$'\e[0m'
else
  R=''; V=''; J=''; B=''; G=''; Z=''
fi

TROUVAILLES=0
ALERTES=0
RAPPORT="${TMPDIR:-/tmp}/kdl-supply-check-$(date +%Y%m%d-%H%M%S).txt"

titre()   { [ "$SILENCIEUX" -eq 1 ] || printf '\n%s%s%s\n' "$G$B" "$1" "$Z"; }
ok()      { [ "$SILENCIEUX" -eq 1 ] || printf '  %s✓%s %s\n' "$V" "$Z" "$1"; }
alerte()  {
  if [ "$MACHINE" -eq 1 ]; then printf 'INDICE\t%s\t%s\n' "$ETAPE" "$(printf '%s' "$1" | tr '\t\r\n' '   ')"
  else printf '  %s⚠ %s%s\n' "$R$G" "$1" "$Z"; fi
  ALERTES=$((ALERTES+1)); echo "ALERTE: $1" >> "$RAPPORT"; }
note()    { [ "$SILENCIEUX" -eq 1 ] || printf '  %s·%s %s\n' "$J" "$Z" "$1"; }

# ═══ Base de signatures ═══════════════════════════════════════════════════
# Empreintes SHA-256 des charges connues. C'est le seul critère fiable : le
# ver emprunte des noms de fichiers qui existent aussi dans des paquets
# parfaitement légitimes.
HASHES_CONNUS="
54dc7ea54a1317cca0e890a2770630cf7fa6c97813e0cb9d2caa93012b350668
fd3ca4007b225fdf8de7af4345a19179d5efa8c4bb9205f88cda806e5684b1eb
9fc2570b7cef51c1b8df116d144d11ff4096357be7d2c4c6367cfc2509cf1bcc
"

# Paquet:version piégée:version saine à reprendre
PAQUETS_PIEGES="
keyv:6.0.0:5.6.0
flat-cache:6.1.24:6.1.23
file-entry-cache:11.1.6:11.1.5
cacheable-request:13.0.20:13.0.19
cacheable:2.5.1:2.5.0
cache-manager:7.2.10:7.2.9
ecto:5.0.1:5.0.0
"

RACINES="${KDL_SCAN_PATHS:-$HOME}"

ETAPE=debut
[ "$MACHINE" -eq 1 ] && printf 'KDLSC\t1\t%s\n' "$VERSION"
[ "$SILENCIEUX" -eq 1 ] || cat <<BANNIERE
${G}${B}KDL Supply Check${Z} ${VERSION} — recherche de compromission npm
machine : $(hostname) · $(date '+%d/%m/%Y %H:%M')
BANNIERE

# ═══ 1. LE VEILLEUR — en premier, toujours ════════════════════════════════
ETAPE=veilleur
titre "1. Veilleur de destruction (à neutraliser avant toute chose)"

VEILLEUR_TROUVE=0
for chemin in \
  "$HOME/.local/bin/gh-token-monitor.sh" \
  "$HOME/.config/gh-token-monitor" \
  "$HOME/.config/systemd/user/gh-token-monitor.service" \
  "$HOME/Library/LaunchAgents/com.github.token-monitor.plist"
do
  if [ -e "$chemin" ]; then
    alerte "veilleur présent : $chemin"
    VEILLEUR_TROUVE=1
  fi
done

if command -v systemctl >/dev/null 2>&1; then
  if systemctl --user list-units --all 2>/dev/null | grep -qi "gh-token-monitor"; then
    alerte "service systemd « gh-token-monitor » actif"
    VEILLEUR_TROUVE=1
  fi
fi

if [ "$VEILLEUR_TROUVE" -eq 1 ] && [ "$MACHINE" -eq 0 ]; then
  printf '\n  %s%sNE RÉVOQUEZ AUCUN MOT DE PASSE NI JETON POUR L'"'"'INSTANT.%s\n' "$R" "$G" "$Z"
  printf '  Ce veilleur déclenche une destruction de données quand il détecte\n'
  printf '  qu'"'"'un jeton volé a été révoqué. Neutralisez-le d'"'"'abord.\n'
  if [ "$NETTOYER" -eq 1 ]; then
    printf '\n  Neutralisation en cours…\n'
    systemctl --user stop gh-token-monitor 2>/dev/null
    systemctl --user disable gh-token-monitor 2>/dev/null
    # On conserve le dossier pour analyse, on ne l'exécute jamais.
    mv "$HOME/.config/gh-token-monitor" "$HOME/.config/gh-token-monitor.preuve-$(date +%s)" 2>/dev/null
    rm -f "$HOME/.config/systemd/user/gh-token-monitor.service" \
          "$HOME/.local/bin/gh-token-monitor.sh" 2>/dev/null
    systemctl --user daemon-reload 2>/dev/null
    ok "veilleur neutralisé — les preuves sont conservées à côté"
  else
    printf '  Relancez avec %s--nettoyer%s pour le neutraliser.\n' "$G" "$Z"
  fi
else
  ok "aucun veilleur de destruction"
fi

# ═══ 2. LA CHARGE MALVEILLANTE ════════════════════════════════════════════
ETAPE=charge
titre "2. Charge malveillante sur le disque"

SUSPECTS=0
FAUX_POSITIFS=0

while IFS= read -r fichier; do
  [ -f "$fichier" ] || continue
  h=$(sha256sum "$fichier" 2>/dev/null | cut -d' ' -f1)
  if echo "$HASHES_CONNUS" | grep -q "$h"; then
    alerte "charge confirmée : $fichier"
    SUSPECTS=$((SUSPECTS+1))
  elif [ "$(basename "$fichier")" = "setup.mjs" ] && grep -q 'oven-sh/bun' "$fichier" 2>/dev/null; then
    alerte "dropper probable (télécharge Bun) : $fichier"
    SUSPECTS=$((SUSPECTS+1))
  else
    FAUX_POSITIFS=$((FAUX_POSITIFS+1))
  fi
done < <(find $RACINES -type f \( -name 'Math_Symbol.js' -o -name 'math_init.js' -o -name 'setup.mjs' \) 2>/dev/null)

if [ "$SUSPECTS" -eq 0 ]; then
  ok "aucune charge malveillante"
  [ "$FAUX_POSITIFS" -gt 0 ] && note "$FAUX_POSITIFS fichier(s) au nom identique mais légitimes (empreinte différente)"
fi

# ═══ 3. LES PAQUETS PIÉGÉS ════════════════════════════════════════════════
ETAPE=paquet
titre "3. Versions de paquets compromises"

PAQUETS_TROUVES=0
for entree in $PAQUETS_PIEGES; do
  [ -z "$entree" ] && continue
  paquet="${entree%%:*}"; reste="${entree#*:}"
  piegee="${reste%%:*}"; saine="${reste##*:}"
  while IFS= read -r dossier; do
    [ -f "$dossier/package.json" ] || continue
    v=$(grep -m1 '"version"' "$dossier/package.json" 2>/dev/null | sed 's/.*"version" *: *"\([^"]*\)".*/\1/')
    if [ "$v" = "$piegee" ]; then
      alerte "$paquet $v est une version piégée — repasser en $saine : $(dirname "$(dirname "$dossier")")"
      PAQUETS_TROUVES=$((PAQUETS_TROUVES+1))
    fi
  done < <(find $RACINES -maxdepth 7 -type d -name "$paquet" -path '*/node_modules/*' 2>/dev/null)
done
[ "$PAQUETS_TROUVES" -eq 0 ] && ok "aucune version piégée installée"

# ═══ 4. PERSISTANCE DANS LES OUTILS ═══════════════════════════════════════
ETAPE=crochet
titre "4. Crochets dans les éditeurs et assistants"

CROCHETS=0
while IFS= read -r f; do
  if grep -qE 'setup\.mjs|math_init|Math_Symbol' "$f" 2>/dev/null; then
    alerte "crochet de persistance : $f"
    CROCHETS=$((CROCHETS+1))
  fi
done < <(find $RACINES \( -path '*/.claude/settings.json' -o -path '*/.vscode/tasks.json' \) -not -path '*/node_modules/*' 2>/dev/null)

for f in "$HOME/.claude/setup.mjs" "$HOME/.vscode/setup.mjs"; do
  [ -e "$f" ] && { alerte "fichier déposé : $f"; CROCHETS=$((CROCHETS+1)); }
done
[ "$CROCHETS" -eq 0 ] && ok "aucun crochet de persistance"

# ═══ 5. INDICES SECONDAIRES ═══════════════════════════════════════════════
ETAPE=indice
titre "5. Indices secondaires"

ls "${TMPDIR:-/tmp}"/bun-dl-* >/dev/null 2>&1 && alerte "restes de téléchargement Bun dans le dossier temporaire" || ok "pas de reste de téléchargement suspect"

if command -v bun >/dev/null 2>&1; then
  note "Bun est installé ($(command -v bun)) — normal si vous l'avez voulu, suspect sinon"
fi

if command -v npm >/dev/null 2>&1; then
  npmv=$(npm -v 2>/dev/null)
  majeure="${npmv%%.*}"
  if [ "${majeure:-0}" -ge 12 ] 2>/dev/null; then
    ok "npm $npmv — les scripts d'installation non approuvés sont bloqués"
  else
    note "npm $npmv — passer en 12 ou plus bloquerait les scripts d'installation automatiques"
  fi
fi

# ═══ VERDICT ══════════════════════════════════════════════════════════════
TOTAL=$((ALERTES))
if [ "$MACHINE" -eq 1 ]; then
  if [ "$TOTAL" -eq 0 ]; then printf 'RESULTAT\tsain\t0\n'; exit 0; fi
  printf 'RESULTAT\tcompromis\t%d\n' "$TOTAL"; exit 2
fi
printf '\n'
if [ "$TOTAL" -eq 0 ]; then
  printf '%s%s  MACHINE SAINE%s — aucun indice de compromission.\n' "$V" "$G" "$Z"
  printf '  Restez à jour et méfiez-vous des paquets publiés depuis moins de 3 jours.\n'
  exit 0
else
  printf '%s%s  %d INDICE(S) TROUVÉ(S) — traitez cette machine comme compromise.%s\n' "$R" "$G" "$TOTAL" "$Z"
  printf '\n  Dans cet ordre, sans en sauter :\n'
  printf '   1. Neutraliser le veilleur   → %s--nettoyer%s (fait en premier)\n' "$G" "$Z"
  printf '   2. Couper le réseau de cette machine\n'
  printf '   3. Supprimer node_modules, vider le cache npm, réinstaller sans scripts\n'
  printf '   4. SEULEMENT ENSUITE, révoquer : jeton npm, puis GitHub, puis SSH,\n'
  printf '      puis les clés d'"'"'API (cloud, IA, paiement)\n'
  printf '   5. Vérifier les publications et dépôts créés en votre nom\n'
  printf '\n  Rapport écrit : %s\n' "$RAPPORT"
  printf '  Besoin d'"'"'aide ? KDL TECH — https://kdl-tech.fr\n'
  exit 2
fi
