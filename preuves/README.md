# Preuves de validation de Quiz App

Lucas et Mohamed · 17 novembre 2026

Le déploiement est accessible en [HTTPS sur Azure](https://quizapp-lucas-mohamed.proudplant-fb1d65e2.belgiumcentral.azurecontainerapps.io/). Le groupe travaille dans son [fork GitHub](https://github.com/LuBoys/eval-quiz-app) et fait relire ses changements dans la [PR #1](https://github.com/LuBoys/eval-quiz-app/pull/1).

| Jalon | Compte rendu |
| --- | --- |
| J0 · Accès, régions et quota | [Abonnement Azure](J0/abonnement-azure.md) |
| J1 · Conteneurs et volume local | [Vérification Docker Compose](J1/verification-locale.md) |
| J2 · Sécurité des images | [Rapport Trivy](J2/rapport-trivy.md) |
| J3 · Azure CLI et registre | [Création et nettoyage du groupe de test](J3/creation-cli-acr.md) |
| J4 · Déploiement et logs | [Container Apps en production](J4/deploiement-azure.md) |
| J5 · PostgreSQL externe | [Écriture et relecture du score sur Azure](J5/persistance-neon.md) |
| J6-A · Contrôles GitHub | [Protection de `main` et preuve de CI](J6/livraison-github.md) |
| J6-B · Livraison sur `main` | [Exécutions GitHub Actions sur `main`](https://github.com/LuBoys/eval-quiz-app/actions/workflows/github-actions.yml?query=branch%3Amain) |

Le [schéma cloud](../docs/13-architecture-cloud.md) et le [schéma local](../docs/10-demarrage-local.md#les-trois-services) servent de support à la démonstration.

La [capture des vérifications techniques](verifications-chrome.png) montre les sorties Docker, Azure CLI et GitHub qui accompagnent les comptes rendus. Elle a été prise dans Chrome à partir des résultats expurgés.
