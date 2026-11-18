# Déployer quizapp-lucas-mohamed avec Terraform

Terraform lit des fichiers `.tf` qui décrivent les ressources dont le quiz a besoin. Il utilise le **provider AzureRM**, son connecteur vers Azure, pour créer et mettre à jour ces ressources. [Architecture du quiz](13-architecture-cloud.md)

## Les deux dossiers Terraform

| Dossier | Ce qu’il crée ou utilise |
| --- | --- |
| [`terraform/infra`](../terraform/infra/) | Crée ou réutilise le groupe de ressources du quiz. Crée le registre d’images ACR en Basic, l’environnement `quiz-env` et l’identité qui permet aux applications de lire les images. Peut aussi créer l’accès à Azure pour GitHub Actions. |
| [`terraform/apps`](../terraform/apps/) | Utilise les adresses fournies par `infra` et deux images déjà publiées dans ACR pour créer le frontend public et le backend interne. Définit leurs ports, le nombre de conteneurs, les vérifications de démarrage et la configuration initiale. |

L’ordre est **installer `infra` → publier les deux images dans ACR → installer `apps`**. Le backend est créé avant le frontend, car Terraform utilise son adresse interne pour renseigner `BACKEND_URL` dans Nginx.

Dans chaque dossier, `main.tf` décrit les ressources, `variables.tf` décrit les valeurs à fournir et `outputs.tf` les valeurs à récupérer. `versions.tf` fixe les versions compatibles. Terraform lit les réglages dans `terraform.tfvars` et dans les fichiers `*.auto.tfvars.json` du dossier choisi. [Chargement des variables Terraform](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-files)

## Comprendre les commandes

| Commande | Effet |
| --- | --- |
| `init` | Prépare le dossier et installe le provider AzureRM. |
| `validate` | Vérifie que la configuration est valide sans contacter Azure. |
| `plan` | Compare les fichiers, l’état Terraform et les ressources Azure. Affiche les créations, modifications et suppressions prévues. |
| `apply` | Présente les changements et les réalise sur Azure après confirmation. |
| `output` | Affiche les sorties déjà enregistrées, par exemple l’adresse du quiz. |

Les deux dossiers ont chacun un fichier d’état local `terraform.tfstate`. Il relie les ressources des fichiers `.tf` aux ressources déjà créées sur Azure. Garde ces états et tes valeurs de configuration en privé, car ils peuvent contenir des secrets en clair. Git ignore les fichiers `*.tfstate`, `*.tfvars`, `*.tfvars.json` et `*.tfplan` des dossiers Terraform. Pour reprendre un déploiement déjà en ligne, utilise ses fichiers d’état et ses réglages existants. [État Terraform](https://developer.hashicorp.com/terraform/language/state) · [Données sensibles](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)

Les étapes suivantes décrivent une première installation sur un groupe dédié au quiz. Pour le jalon J3, le sujet demande de montrer la création de ressources avec les commandes Azure CLI. [Parcours Azure CLI du J3](11-configurer-cicd.md#continuer-la-préparation) · [Jalons du sujet](03-jalons-validation.md#j3--azure-cli-et-acr)

## 1. Préparer ton abonnement Azure

Installe Azure CLI, Docker et Terraform en version `1.7` ou plus récente dans la série `1.x`. Lance les commandes depuis la racine du dépôt. Vérifie l’abonnement sélectionné et ses régions autorisées. Il te faut le droit de créer les ressources et d’attribuer des rôles Azure. [Vérifier les régions autorisées](11-configurer-cicd.md#vérifier-les-régions-autorisées)

```bash
az login
az account show --query '{nom:name,id:id,etat:state}' --output table
az extension add --name containerapp --upgrade
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

La configuration désactive l’enregistrement automatique des services Azure. La commande suivante active les services nécessaires qui manquent dans l’abonnement, si ton compte a les droits.

```bash
for namespace in Microsoft.App Microsoft.ContainerRegistry Microsoft.ManagedIdentity; do
  if [ "$(az provider show --namespace "$namespace" --query registrationState --output tsv)" != "Registered" ]; then
    az provider register --namespace "$namespace" --wait
  fi
done
```

## 2. Créer le registre et l’environnement

Copie l’exemple si `terraform/infra/terraform.tfvars` n’existe pas encore.

```bash
cp terraform/infra/terraform.tfvars.example terraform/infra/terraform.tfvars
```

Dans `terraform/infra/terraform.tfvars`, choisis un `acr_name` disponible mondialement et remplace `REGION_AUTORISEE` par une région permise par ton abonnement. `project_name` donne son nom au frontend et sert à nommer le groupe et les identités Azure. `location` fixe la région du registre, des identités et de `quiz-env`.

Si tu veux utiliser un groupe créé en dehors de Terraform, renseigne `resource_group_name` et `use_existing_resource_group = true` avant le premier `apply`. Pour faire gérer par Terraform une ressource Azure existante, comme un registre ou une identité, il faut l’importer dans l’état du bon dossier. [Importer une ressource](https://developer.hashicorp.com/terraform/cli/commands/import)

Pour activer la livraison GitHub Actions, ajoute le `github_oidc_subject` exact de la branche `main` de ton fork. Terraform crée alors l’identité de déploiement, la règle de confiance GitHub et les droits Azure associés. [Trouver le format de ton sujet OIDC](11-configurer-cicd.md#accès-à-azure-avec-oidc)

```bash
terraform -chdir=terraform/infra init
terraform -chdir=terraform/infra validate
```

Par exemple, si l’identité `quizapp-lucas-mohamed-github-deploy` existe déjà dans `rg-quizapp-lucas-mohamed` et que tu l’ajoutes à l’état Terraform, importe-la après `init` avec le sujet OIDC renseigné.

```bash
terraform -chdir=terraform/infra import \
  'azurerm_user_assigned_identity.github[0]' \
  "/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/rg-quizapp-lucas-mohamed/providers/Microsoft.ManagedIdentity/userAssignedIdentities/quizapp-lucas-mohamed-github-deploy"
```

```bash
terraform -chdir=terraform/infra plan
terraform -chdir=terraform/infra apply
```

Vérifie les changements affichés et confirme seulement si le plan correspond aux ressources que tu veux créer ou modifier.

## 3. Construire, scanner et publier les images

Ouvre Docker Desktop et utilise le fichier `.env` de ton installation locale. Construis les images à partir du commit que tu veux publier. `linux/amd64` indique le système et le type de processeur attendus par le script de déploiement, même si ton ordinateur utilise un processeur différent. [Démarrage local](10-demarrage-local.md) · [Script de déploiement](../scripts/deploy.sh)

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose -p quiz-ci build frontend backend &&
  scripts/scan-images.sh quiz-ci-frontend:latest quiz-ci-backend:latest
```

Quand le scan réussit, publie les deux images. Le **tag** est une étiquette. Ici, il contient le `SHA` du commit, c’est-à-dire son identifiant Git. Le **digest** identifie le contenu exact de l’image. Les commandes enregistrent ces digests dans `terraform/apps/images.auto.tfvars.json` pour que Terraform puisse les utiliser.

```bash
(
  set -e
  registry_name=$(terraform -chdir=terraform/infra output -raw acr_name)
  registry_server=$(az acr show --name "$registry_name" --query loginServer --output tsv)
  az acr login --name "$registry_name"
  image_tag=$(git rev-parse HEAD)

  for service in frontend backend; do
    target="$registry_server/quiz-$service:$image_tag"
    docker image tag "quiz-ci-$service:latest" "$target"
    docker image push "$target"
  done

  frontend_digest=$(az acr repository show --name "$registry_name" \
    --image "quiz-frontend:$image_tag" --query digest --output tsv)
  backend_digest=$(az acr repository show --name "$registry_name" \
    --image "quiz-backend:$image_tag" --query digest --output tsv)

  printf '{"image_digests":{"frontend":"%s","backend":"%s"}}\n' \
    "$frontend_digest" "$backend_digest" > terraform/apps/images.auto.tfvars.json
)
```

## 4. Créer les deux applications

La sortie `app_inputs` de `infra` contient le groupe, l’adresse d’ACR, l’identifiant de `quiz-env`, l’identité de lecture et les noms des deux applications. Écris-la dans un fichier de variables pour `apps`. La commande crée aussi `terraform.tfvars` à partir de l’exemple si le fichier manque.

```bash
terraform -chdir=terraform/infra output -json app_inputs > terraform/apps/infrastructure.auto.tfvars.json
if [ ! -f terraform/apps/terraform.tfvars ]; then
  cp terraform/apps/terraform.tfvars.example terraform/apps/terraform.tfvars
fi
```

Remplis `admin_password` et `jwt_secret` dans `terraform/apps/terraform.tfvars`. Terraform utilise ces valeurs pour créer les secrets du backend. L’exemple indique `min_replicas = 1`, ce qui garde un conteneur prêt par application. Le maximum est fixé à deux. Sur le profil **Consumption**, Azure peut facturer un conteneur qui reste allumé au repos. [Facturation Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/billing)

- Pour enregistrer des scores, utilise une base PostgreSQL externe, par exemple Neon. Initialise le schéma avec `database/init.sql` sur une base vide et renseigne `database_url` avec une connexion TLS vérifiée. [Configurer Neon](10-demarrage-local.md#utiliser-neon-depuis-docker)
- Pour envoyer les résultats aux participants, vérifie le domaine expéditeur dans Resend. Renseigne `resend_api_key` et `from_email` lors de la création des apps. Après la création, ajoute les mêmes réglages dans GitHub sous le secret `RESEND_API_KEY` et la variable `FROM_EMAIL` pour les prochaines livraisons. L’expéditeur de test `onboarding@resend.dev` envoie seulement à l’adresse de ton compte Resend. [Restrictions de l’expéditeur de test](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)

```bash
terraform -chdir=terraform/apps init
terraform -chdir=terraform/apps validate
terraform -chdir=terraform/apps plan
terraform -chdir=terraform/apps apply
```

Ouvre l’adresse publique `frontend_url` fournie par Azure. `/health` doit répondre HTTP 200 avec `{"status":"ok"}` pour confirmer que Nginx peut joindre le backend. Pour vérifier PostgreSQL, enregistre ensuite un résultat et retrouve-le dans la page de gestion.

```bash
terraform -chdir=terraform/apps output -raw frontend_url
curl --fail --silent --show-error --retry 6 --retry-all-errors --retry-delay 5 \
  --write-out '\nHTTP %{http_code}\n' "$(terraform -chdir=terraform/apps output -raw health_url)"
```

## 5. Relier GitHub Actions

Si tu as renseigné le sujet OIDC, récupère les valeurs avec ces deux commandes. Ajoute-les dans **Settings → Secrets and variables → Actions** du fork, puis configure les secrets avec les mêmes valeurs que lors de la création du backend. [Variables et secrets du workflow](11-configurer-cicd.md#renseigner-github-avant-la-fusion)

```bash
terraform -chdir=terraform/infra output -json deployment_variables
terraform -chdir=terraform/infra output -json github_login_variables
```

Après la création, GitHub Actions utilise `scripts/deploy.sh` à chaque livraison sur `main`. Il publie les images, met à jour les deux digests déployés et règle les variables et les secrets du backend. Pour mettre à jour ces réglages, change les variables ou secrets du fork avant la livraison.

Dans `terraform/apps/main.tf`, `ignore_changes` laisse la pipeline gérer l’image des deux applications et les secrets et variables du backend après leur création. Pour changer les ressources Azure, les ports ou le nombre de réplicas, révise le plan Terraform du dossier concerné. Une nouvelle question du quiz suit le [parcours de livraison GitHub Actions](11-configurer-cicd.md#ce-que-fait-le-workflow). [Fonctionnement d’`ignore_changes`](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle#ignore_changes)

## Voir les logs du backend

Dans le portail Azure, ouvre **Container Apps → quiz-backend → Monitoring → Log stream**, puis sélectionne **Console**. Depuis le terminal connecté à Azure, utilise cette commande et arrête le flux avec **Ctrl+C**. [Flux de logs Azure](https://learn.microsoft.com/en-us/azure/container-apps/log-streaming)

```bash
az containerapp logs show -g rg-quizapp-lucas-mohamed \
  -n quiz-backend --type console --follow
```

## Utiliser le sous-domaine attribué

Attends que le formateur communique le nom réservé à ton groupe. Cette commande affiche les deux valeurs DNS à lui transmettre. [Sous-domaine et HTTPS dans le sujet](05-bonus-azure.md#sous-domaine-personnalisé-et-https)

```bash
terraform -chdir=terraform/apps output -json frontend_dns
```

1. Demande au formateur de créer un `CNAME` pour le sous-domaine attribué avec `cname_target` comme cible.
2. Donne-lui aussi l’enregistrement `TXT` pour `asuid.<sous-domaine attribué>` avec `verification_txt_value` comme valeur.
3. Dans le portail Azure, ouvre **Container Apps → quizapp-lucas-mohamed → Domaines personnalisés → Ajouter**. Saisis le nom attribué et sélectionne un **certificat géré** avec validation **CNAME**. Une fois les DNS validés, Azure associe le certificat HTTPS au site. [Certificats gérés Azure](https://learn.microsoft.com/en-us/azure/container-apps/custom-domains-managed-certificates)

## Supprimer les ressources du quiz

Après avoir gardé tes preuves et obtenu l’accord du formateur, supprime d’abord les applications, puis le registre et l’environnement. Révise le plan affiché avant de confirmer chaque suppression.

Si Terraform a créé le groupe, le plan de suppression inclut aussi ce groupe. Avec `use_existing_resource_group = true`, Terraform supprime les ressources qu’il suit dans le groupe réutilisé.

```bash
terraform -chdir=terraform/apps destroy &&
  terraform -chdir=terraform/infra destroy
```
