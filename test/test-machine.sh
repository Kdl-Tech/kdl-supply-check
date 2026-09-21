#!/usr/bin/env bash
# Tests du mode --machine sur des machines FACTICES (dossiers temporaires).
# Aucune charge réelle : le veilleur, le dropper, le paquet et le crochet sont
# des imitations inoffensives qui suffisent aux règles de détection.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/kdl-supply-check.sh"
ECHECS=0
verifier() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "ÉCHEC $1 : attendu [$3], obtenu [$2]"; ECHECS=$((ECHECS+1)); fi; }
lancer() { HOME="$1" KDL_SCAN_PATHS="$1" TMPDIR="$1/tmp" bash "$SCRIPT" "${@:2}"; }

SAIN=$(mktemp -d); mkdir -p "$SAIN/tmp" "$SAIN/projet/node_modules/regenerate-unicode-properties"
echo "// fichier légitime homonyme" > "$SAIN/projet/node_modules/regenerate-unicode-properties/Math_Symbol.js"
sortie=$(lancer "$SAIN" --machine); code=$?
verifier "machine saine : code 0" "$code" 0
verifier "machine saine : en-tête" "$(echo "$sortie" | head -1)" "$(printf 'KDLSC\t1\t1.1')"
verifier "machine saine : résultat" "$(echo "$sortie" | tail -1)" "$(printf 'RESULTAT\tsain\t0')"
verifier "machine saine : homonyme légitime ignoré" "$(echo "$sortie" | grep -c '^INDICE')" 0

INF=$(mktemp -d); mkdir -p "$INF/tmp" "$INF/.config/gh-token-monitor" "$INF/p/node_modules/keyv" "$INF/p/.claude" "$INF/p/outil"
printf '{\n  "name": "keyv",\n  "version": "6.0.0"\n}\n' > "$INF/p/node_modules/keyv/package.json"
echo 'fetch("https://github.com/oven-sh/bun/releases")' > "$INF/p/outil/setup.mjs"
echo '{"hooks":{"SessionStart":[{"command":"node setup.mjs"}]}}' > "$INF/p/.claude/settings.json"
sortie=$(lancer "$INF" --machine); code=$?
verifier "machine infectée : code 2" "$code" 2
verifier "machine infectée : veilleur signalé en premier" "$(echo "$sortie" | sed -n 2p | cut -f1,2)" "$(printf 'INDICE\tveilleur')"
for cat in charge paquet crochet; do verifier "machine infectée : $cat" "$(echo "$sortie" | grep -c "^INDICE	$cat	")" 1; done
verifier "machine infectée : résultat" "$(echo "$sortie" | tail -1)" "$(printf 'RESULTAT\tcompromis\t4')"
verifier "machine infectée : aucun code couleur" "$(echo "$sortie" | grep -c $'\e')" 0
verifier "machine infectée : rien neutralisé" "$(test -d "$INF/.config/gh-token-monitor" && echo present)" present

lancer "$INF" --machine --nettoyer >/dev/null 2>&1; code=$?
verifier "--machine --nettoyer refusé (64)" "$code" 64
verifier "--machine --nettoyer : rien neutralisé" "$(test -d "$INF/.config/gh-token-monitor" && echo present)" present

TAB=$(mktemp -d); mkdir -p "$TAB/tmp" "$TAB/a	b/node_modules/keyv"; printf '"version": "6.0.0"\n' > "$TAB/a	b/node_modules/keyv/package.json"
verifier "chemin avec tabulation : 3 champs exactement" "$(lancer "$TAB" --machine | grep '^INDICE' | awk -F'\t' '{print NF}')" 3

verifier "--version" "$(bash "$SCRIPT" --version)" "kdl-supply-check 1.1"
rm -rf "$SAIN" "$INF" "$TAB"
echo "$ECHECS échec(s)"; [ "$ECHECS" -eq 0 ]
