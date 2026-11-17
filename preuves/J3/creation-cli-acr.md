# J3 · Création du registre et de l’environnement avec Azure CLI

Le 17 novembre 2026, le test a utilisé `rg-quiz-lm-j3-1117151823` en **Suisse Nord**. Le quiz en ligne utilise son propre groupe en Belgique Centre.

1. `az group create` a créé le groupe temporaire en `switzerlandnorth`. Azure a répondu `Succeeded`.
2. `az acr create --sku Basic --role-assignment-mode rbac` a créé le registre `quizlmj3261117151823`.
3. `az containerapp env create --logs-destination none --enable-workload-profiles true` a créé l’environnement `quiz-j3-env`. Son état était `Succeeded`.
4. `az acr import` a copié `quiz-frontend` et `quiz-backend` depuis le registre du projet. Les deux images venaient d’un build Linux AMD64 validé par Trivy. Le tag Git complet des deux images était `400c0ffef11bf37670b18b6e63100a22da15e82d`.
5. `az acr repository show` a confirmé les digests ci-dessous.
6. `scripts/destroy.sh rg-quiz-lm-j3-1117151823` a affiché le registre et l’environnement. La même commande avec `--apply` a supprimé le groupe de test. `az group exists` a confirmé que le groupe de test était absent et que le groupe du quiz en ligne existait toujours.

| Image | Digest ACR |
| --- | --- |
| `quiz-frontend` | `sha256:987d448d0c6ccf3e1207eb30289e3fbfd3f2f4649a29bfe9c36f857842eadbe0` |
| `quiz-backend` | `sha256:519b53cd73139c98d0421c99c7be15bdc3f827f9b2794fc76f73e0e81ce1fdf5` |

Les [commandes reproductibles](../../docs/11-configurer-cicd.md#continuer-la-préparation) incluent l’identité `AcrPull` et l’identité OIDC utilisées pour les deux apps du quiz.
