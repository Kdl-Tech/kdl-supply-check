#!/usr/bin/env python3
"""Transforme une sortie réelle du script en SVG de terminal.

Le SVG est préféré à une capture PNG : net à toutes les tailles, léger, et le
texte reste sélectionnable. Rien n'est reconstitué à la main — l'entrée est la
sortie authentique de kdl-supply-check.sh.
"""
import html
import sys

# Palette : sombre en permanence, un terminal ne change pas de thème.
FOND, CADRE, BARRE = "#0f1419", "#243140", "#161c24"
BLANC, GRIS, VERT, ROUGE, ORANGE, BLEU = "#dbe6f0", "#7d94a8", "#4ade80", "#f87171", "#fbbf24", "#8fc3e8"

LH, PAD_X, PAD_Y, BARRE_H = 20, 22, 16, 34
CAR = 7.62  # largeur d'un caractère en 13px monospace


def couleur(ligne):
    l = ligne.strip()
    if l.startswith("⚠"):
        return ROUGE
    if l.startswith("✓"):
        return VERT
    if l.startswith("·"):
        return ORANGE
    # Titre de section : numéro en début de ligne, sans indentation.
    if not ligne.startswith(" ") and l[:1].isdigit() and l[1:2] == ".":
        return BLEU
    if "MACHINE SAINE" in l:
        return VERT
    if "INDICE(S) TROUVÉ(S)" in l or "NE RÉVOQUEZ" in l:
        return ROUGE
    if l.startswith("KDL Supply Check"):
        return BLANC
    return GRIS


def gras(ligne):
    l = ligne.strip()
    return (
        l.startswith("KDL Supply Check")
        or "MACHINE SAINE" in l
        or "INDICE(S) TROUVÉ(S)" in l
        or "NE RÉVOQUEZ" in l
        or (not ligne.startswith(" ") and l[:1].isdigit() and l[1:2] == ".")
    )


def construire(lignes, titre):
    largeur_max = max((len(x) for x in lignes), default=60)
    W = int(largeur_max * CAR) + PAD_X * 2
    H = BARRE_H + PAD_Y * 2 + len(lignes) * LH
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}" font-family="ui-monospace,SFMono-Regular,Menlo,Consolas,monospace" font-size="13">',
        f'<rect width="{W}" height="{H}" rx="10" fill="{FOND}" stroke="{CADRE}"/>',
        f'<path d="M0 10a10 10 0 0 1 10-10h{W-20}a10 10 0 0 1 10 10v{BARRE_H-10}H0z" fill="{BARRE}"/>',
    ]
    for i, cx in enumerate((20, 38, 56)):
        out.append(f'<circle cx="{cx}" cy="17" r="5" fill="#2b3947"/>')
    out.append(
        f'<text x="78" y="21" fill="#5c7086" font-size="11" font-weight="600">{html.escape(titre)}</text>'
    )
    y = BARRE_H + PAD_Y + 14
    for ligne in lignes:
        if ligne.strip():
            fw = ' font-weight="700"' if gras(ligne) else ""
            out.append(
                f'<text x="{PAD_X}" y="{y}" fill="{couleur(ligne)}"{fw} '
                f'xml:space="preserve">{html.escape(ligne)}</text>'
            )
        y += LH
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    source, cible, titre = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(source, encoding="utf-8") as f:
        lignes = [l.rstrip("\n") for l in f]
    while lignes and not lignes[-1].strip():
        lignes.pop()
    with open(cible, "w", encoding="utf-8") as f:
        f.write(construire(lignes, titre))
    print(f"{cible} — {len(lignes)} lignes")
