# J2 · Scan des images Docker du 17 novembre 2026

Trivy 0.76.2 a analysé les images Linux ARM64 avant et après les corrections, avec la même base de vulnérabilités mise à jour le 17 novembre à 07 h 59, heure de Paris. Les nombres indiquent les alertes relevées dans chaque image.

| Service | Étape | Début de l’identifiant de l’image | CRITICAL | HIGH | MEDIUM | LOW | UNKNOWN |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Frontend | Avant | `6ef324921314` | 0 | 0 | 1 | 0 | 0 |
| Frontend | Après | `4ed996536171` | 0 | 0 | 0 | 0 | 0 |
| Backend | Avant | `234c948f5e1e` | 0 | 6 | 15 | 1 | 0 |
| Backend | Après | `3645c7af851b` | 0 | 0 | 2 | 0 | 0 |
| PostgreSQL | Avant | `2e7ed4ea03de` | 2 | 148 | 194 | 156 | 11 |
| PostgreSQL | Après | `d4d9637f9bc0` | 0 | 0 | 0 | 0 | 0 |

## Corrections vérifiées

- Le frontend installe la mise à jour Alpine de `zlib`, de `1.3.2-r1` à `1.4-r0`. Trivy ne relève plus `CVE-2026-4738` dans cette image. Nginx tourne avec l’utilisateur 101 au démarrage.
- Le backend utilise `npm ci` pendant la construction. L’image finale contient Node.js, les dépendances de production et les bibliothèques nécessaires. L’absence du gestionnaire npm à l’exécution retire les six alertes HIGH repérées dans ses dépendances `brace-expansion` et `undici`. La mise à jour Alpine corrige aussi `zlib`. [Guide des images Node.js](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)
- PostgreSQL passe de `postgres:16.16` sur Debian à `postgres:16.16-alpine`. Le scan Alpine ne relève plus l’alerte critique `CVE-2026-6653` dans `libxml2`. Le Dockerfile retire le binaire `gosu` concerné par `CVE-2025-68121` et utilise `su-exec` pour démarrer PostgreSQL sous le compte `postgres`. Les données de la première vérification ont été transférées par export et import PostgreSQL vers le nouveau volume. [Documentation de su-exec](https://github.com/ncopa/su-exec)

## Alertes restantes

Le backend conserve deux alertes MEDIUM dans des dépendances indirectes. Les versions corrigées indiquées par Trivy sont des versions majeures différentes. Leur mise à jour demande de valider la compatibilité des modules qui les utilisent.

| Paquet | Alerte | Version installée | Version corrigée indiquée |
| --- | --- | --- | --- |
| `glob` | `CVE-2026-118773` | `10.5.0` | `14.0.2` |
| `minimatch` | `CVE-2026-118764` | `9.0.9` | `11.0.1` |

## Contrôle des images pour GitHub Actions et Azure

Le 17 novembre 2026, les trois images ont aussi été construites en `linux/amd64`, l’architecture utilisée dans le workflow. Le frontend et PostgreSQL ont obtenu zéro alerte. Le backend a obtenu les deux alertes MEDIUM ci-dessus. Le script de la CI a renvoyé `0` pour les trois images corrigées et `1` lorsqu’il a testé l’ancienne image PostgreSQL contenant les deux alertes CRITICAL.

## Rejouer le contrôle CRITICAL

Le workflow appelle `scripts/scan-images.sh` avec les options Trivy `--severity CRITICAL --exit-code 1`. Lance ces commandes pour rejouer le contrôle sur les images locales.

```bash
docker compose build
docker compose config --images | xargs scripts/scan-images.sh
```

Ce bloc affiche toutes les alertes pour refaire le rapport complet.

```bash
(
  set -e
  docker compose build
  scan_dir=$(mktemp -d)
  trap 'rm -rf "$scan_dir"' EXIT
  docker compose config --images | while read -r image; do
    docker image save --output "$scan_dir/image.tar" "$image"
    docker run --rm --user "$(id -u):$(id -g)" --env HOME=/scan \
      --mount "type=bind,source=$scan_dir,target=/scan" \
      aquasec/trivy:0.76.2 image --cache-dir /scan/cache --scanners vuln \
      --input /scan/image.tar
  done
)
```
