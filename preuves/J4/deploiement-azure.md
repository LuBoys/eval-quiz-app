# J4 — Déploiement du quiz sur Azure

Le 17 novembre 2026, Terraform a reconstruit le projet `quizapp-lucas-mohamed` dans le groupe `rg-quizapp-lucas-mohamed`, en Belgique centrale. Le registre s’appelle `quizapplucasmohamed` et les deux applications partagent l’environnement `quiz-env`. L’ancien groupe `rg-quiz-app` a été supprimé. [Guide Terraform](../../docs/12-terraform-azure.md)

Les deux images Linux AMD64 ont passé le scan Trivy avec le seuil `CRITICAL`. Elles ont ensuite été publiées dans ACR avec le tag `364dd23327e335715f740047e9e7d789d0bac468`. Les applications ont été déployées à partir de leurs digests.

| Application | Entrée réseau | Réplicas minimum | Révision vérifiée |
| --- | --- | --- | --- |
| `quizapp-lucas-mohamed` | HTTPS public vers le port 8080 | 1 | `quizapp-lucas-mohamed--mc5wptm` |
| `quiz-backend` | HTTPS interne vers le port 3007 | 1 | `quiz-backend--0000001` |

## Tests depuis l’adresse publique

| Test | Résultat |
| --- | --- |
| Page du quiz et page de gestion | HTTP 200 en HTTPS |
| `GET /health` via Nginx | HTTP 200 et `{"status":"ok"}` |
| Connexion à l’administration | HTTP 200 et création d’un jeton JWT |
| Lecture des résultats avec le JWT | HTTP 200 et réponse PostgreSQL Neon |

[Quiz en ligne](https://quizapp-lucas-mohamed.proudplant-fb1d65e2.belgiumcentral.azurecontainerapps.io) · [Vérifier /health](https://quizapp-lucas-mohamed.proudplant-fb1d65e2.belgiumcentral.azurecontainerapps.io/health)

## Test de la mise à jour

Le script utilisé par GitHub Actions a été exécuté directement sur Azure avec les images vérifiées. `/health` a répondu HTTP 200 après la mise à jour. Les neuf variables du fork correspondent aux sorties Terraform du nouveau projet. Le premier déploiement déclenché par GitHub Actions se vérifiera après la fusion de la PR dans `main`. [Script de déploiement](../../scripts/deploy.sh)

## Vérification des logs depuis Azure CLI

```bash
az containerapp logs show -g rg-quizapp-lucas-mohamed -n quiz-backend --type console --tail 50
```

Le flux console de la révision `quiz-backend--0000001` contenait `Server running on port 3007`. La révision du frontend était prête sur le port 8080 et la route publique `/health` a renvoyé HTTP 200 avec `{"status":"ok"}`. Dans le portail, le flux s’ouvre sous **Monitoring → Log stream → Console**. [Inscription et score vérifiés en production](../J5/persistance-neon.md)
