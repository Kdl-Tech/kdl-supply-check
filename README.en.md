[Français](README.md) · **English**

# KDL Supply Check

Detects npm supply chain compromise — the **Shai-Hulud / ChainDrop** family.

One file, no dependencies, no network calls. It looks at your machine and tells you
whether the worm has been through it.

```bash
curl -fsSL https://raw.githubusercontent.com/Kdl-Tech/kdl-supply-check/main/kdl-supply-check.sh -o kdl-supply-check.sh
less kdl-supply-check.sh      # read it before you run it. Always.
bash kdl-supply-check.sh
```

![Script output on a compromised machine: the dead man's switch is caught first, then the dropper, the booby-trapped keyv package and the persistence hook, followed by the remediation steps in order](docs/machine-infectee.svg)

<sub>Real output, captured on a deliberately infected test machine. The script speaks French.</sub>

---

## The mistake that costs you everything

These worms plant a **dead man's switch**. It watches the stolen GitHub token, and **the
moment you revoke it, it wipes your data**.

The natural reflex — "I'm infected, let me change all my passwords" — is precisely what
pulls the trigger.

**KDL Supply Check looks for that switch first and stops you before you touch anything.**
That is the whole point of this tool: in this attack, the order of operations matters more
than the detection itself.

The safe order, which the script reminds you of whenever it finds something:

1. neutralise the dead man's switch,
2. take the machine off the network,
3. wipe `node_modules` and the npm cache,
4. **only then** revoke tokens — npm, GitHub, SSH, API keys,
5. check for repositories and packages published in your name.

## What it looks for

| | |
|---|---|
| **The dead man's switch** | `gh-token-monitor` — systemd service, launchd agent, dropped scripts |
| **The payload** | by SHA-256 hash, never by filename |
| **Booby-trapped packages** | `keyv` 6.0.0, `flat-cache` 6.1.24, `file-entry-cache` 11.1.6, `cacheable-request` 13.0.20, `cacheable` 2.5.1, `cache-manager` 7.2.10, `ecto` 5.0.1 |
| **Persistence** | hooks in `.claude/settings.json`, `.vscode/tasks.json`, dropped files |
| **Leftovers** | Bun download remnants, npm version |

## Why hashes and not filenames

The worm's payload is called `Math_Symbol.js`. A perfectly legitimate package —
`regenerate-unicode-properties` — ships a file with the **exact same name**.

A name-based detector triggers a false alarm on a clean machine. This one compares SHA-256
hashes: the legitimate file is around 1 KB, the payload is over 700. Files that merely
share the name are counted separately and reported as such.

On a clean machine, the script says so plainly:

![Script output on a clean machine: all five checks pass and the verdict reads "machine saine" — machine clean](docs/machine-saine.svg)

## Usage

```bash
./kdl-supply-check.sh              # scan only — changes nothing
./kdl-supply-check.sh --nettoyer   # neutralise the switch, keep the evidence
./kdl-supply-check.sh --silencieux # short output, for monitoring
```

Exit codes: `0` clean, `2` indicators found. Suitable for cron and monitoring.

It scans your home directory by default. To point it elsewhere:

```bash
KDL_SCAN_PATHS="/srv /opt/apps" ./kdl-supply-check.sh
```

Across a fleet, over SSH:

```bash
for m in host1 host2 server; do
  echo "── $m"; ssh "$m" 'bash -s' < kdl-supply-check.sh
done
```

`--nettoyer` does not delete the switch: it stops it, disables it, then **renames its
directory to `.preuve-<timestamp>`**. You keep everything you need to investigate.

## What it does not do

It is not an antivirus and not a full audit. It looks for **the known traces of one
specific family of npm worms**, nothing more. A machine this script calls clean may still
be compromised in some other way.

It never revokes a token and never touches your passwords — that is yours to do, in order,
and only once the switch is neutralised.

## Requirements

Bash 4+ — Linux, macOS, WSL. Nothing to install.

## Contributing

New wave, new hashes? Open an issue with a public source for the indicator. The signatures
live at the top of the script, in `HASHES_CONNUS` and `PAQUETS_PIEGES` — two readable
lists, easy to extend.

## Licence

MIT. Take it, change it, fold it into your own tooling. A security detector is only worth
anything if it travels.

---

Written by [**KDL TECH**](https://kdl-tech.fr) after auditing an entire fleet the night of
the 4 August 2026 attack. All six machines were clean — but checking took hours, and
nobody should have to do that work by hand.

IT support, software development, security — Guadeloupe and remote.

---

**Publisher** — KDL TECH, trading name of Karim Laurent De Lucia, sole trader (*entrepreneur individuel*, France) · SIRET 423 471 481 00022 · NAF/APE 95.11Z · LD Caraque, Rue Narcisse Louis, 97139 Les Abymes, Guadeloupe, France · [contact@kdl-tech.fr](mailto:contact@kdl-tech.fr) · [kdl-tech.fr](https://kdl-tech.fr)
