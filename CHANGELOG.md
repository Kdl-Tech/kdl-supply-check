# Journal des versions — KDL Supply Check

## 1.1 — 21/09/2026

- Mode `--machine` : sortie stable pour un programme (KDL Toolbox), une information par
  ligne séparée par des tabulations (`KDLSC`, `INDICE`, `RESULTAT`), sans couleur.
  Lecture seule : combiné avec `--nettoyer`, il est refusé (code 64).
- Sortie humaine inchangée (vérifiée contre la 1.0).
- Tests sur machines factices : `bash test/test-machine.sh`.
- Compatibilité annoncée : Linux uniquement.

## 1.0 — 07/08/2026

Première version : détection des traces Shai-Hulud / ChainDrop (veilleur, charge,
paquets piégés, crochets de persistance), neutralisation du veilleur sur demande.
