# J4 — Déploiement du quiz sur Azure

Le 17 novembre 2026, Terraform a créé le registre `quizappluboys`, l’environnement `quiz-env` et les deux Container Apps dans `belgiumcentral`. Le déploiement réutilise le groupe `rg-quiz-app` et l’identité GitHub existante. [Guide Terraform](../../docs/12-terraform-azure.md)

Les deux images Linux AMD64 ont passé le scan Trivy avec le seuil `CRITICAL`. Elles ont ensuite été publiées dans ACR avec le tag `364dd23327e335715f740047e9e7d789d0bac468`. Les applications ont été déployées à partir de leurs digests.

| Application | Entrée réseau | Révision prête au premier déploiement |
| --- | --- | --- |
| `quiz-frontend` | HTTPS public vers le port 8080 | `quiz-frontend--3ggdl6b` |
| `quiz-backend` | HTTPS interne vers le port 3007 | `quiz-backend--k6cixnw` |

## Tests depuis l’adresse publique

| Test | Résultat |
| --- | --- |
| Page du quiz et page de gestion | HTTP 200 en HTTPS |
| `GET /health` via Nginx | HTTP 200 et `{"status":"ok"}` |
| Connexion à l’administration | HTTP 200 et création d’un jeton JWT |
| Lecture des résultats avec le JWT | HTTP 200 et réponse PostgreSQL Neon |

[Quiz en ligne](https://quiz-frontend.thankfulpebble-3772f318.belgiumcentral.azurecontainerapps.io) · [Vérifier /health](https://quiz-frontend.thankfulpebble-3772f318.belgiumcentral.azurecontainerapps.io/health)

## Test de la mise à jour

Le script utilisé par GitHub Actions a été exécuté directement sur Azure avec les images vérifiées. Il a confirmé les révisions `quiz-backend--0000001` et `quiz-frontend--3ggdl6b`, puis obtenu HTTP 200 sur `/health`. Les variables du fork correspondent aux sorties Terraform et Azure autorise la connexion OIDC du workflow sur `main`. Le premier déploiement déclenché par GitHub Actions se vérifiera après la fusion de la PR dans `main`. [Script de déploiement](../../scripts/deploy.sh)
