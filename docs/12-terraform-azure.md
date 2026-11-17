# Déployer quizapp-lucas-mohamed avec Terraform

Pour le jalon J3, le sujet demande de montrer des ressources créées avec Azure CLI. La variante Terraform ci-dessous crée la même architecture. Utilise un groupe de ressources dédié au quiz. [Commandes Azure CLI](11-configurer-cicd.md#préparer-azure-une-fois) · [Jalons du sujet](03-jalons-validation.md#j3--azure-cli-et-acr)

Terraform crée d’abord ACR et l’environnement Container Apps. Après publication des images dans ACR, il crée le frontend Nginx public sur le port 8080 et le backend Node.js interne sur le port 3007. Nginx atteint le backend en HTTPS via `BACKEND_URL`. Les deux applications utilisent une identité Azure qui a le rôle `AcrPull` sur le registre. ACR est en Basic et chaque application utilise le profil Consumption. En production, `min_replicas = 1` garde un conteneur lancé par application pour réduire l’attente au premier accès. Deux réplicas maximum sont autorisés par application. Azure peut facturer les réplicas gardés au repos. [Facturation Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/billing)

## 1. Préparer ton abonnement Azure

Installe Azure CLI, Terraform et Docker. Lance les commandes depuis la racine du dépôt. Vérifie dans quel abonnement tu es connecté et quelles régions il autorise. Il te faut le droit de créer les ressources et d’attribuer des rôles Azure.

```bash
az login
az account show --query '{nom:name,id:id,etat:state}' --output table
az extension add --name containerapp --upgrade
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

Si l’un de ces services Azure est encore à enregistrer sur ton abonnement, cette commande l’enregistre.

```bash
for namespace in Microsoft.App Microsoft.ContainerRegistry Microsoft.ManagedIdentity; do
  if [ "$(az provider show --namespace "$namespace" --query registrationState --output tsv)" != "Registered" ]; then
    az provider register --namespace "$namespace" --wait
  fi
done
```

## 2. Créer le registre et l’environnement

```bash
cp terraform/infra/terraform.tfvars.example terraform/infra/terraform.tfvars
```

Dans `terraform/infra/terraform.tfvars`, `project_name` donne son nom au site et aux identités. Choisis un `acr_name` disponible mondialement et remplace `REGION_AUTORISEE` par une région permise par ton abonnement. Si ton groupe existe déjà, renseigne son nom dans `resource_group_name` et mets `use_existing_resource_group = true` avant la première application. `location` fixe la région du registre, des identités et de `quiz-env`. Pour reprendre des ressources que tu as déjà créées dans Azure, importe-les dans Terraform avant de les gérer avec lui. [Vérifier les régions autorisées](11-configurer-cicd.md#préparer-azure-une-fois) · [Importer une ressource](https://developer.hashicorp.com/terraform/cli/commands/import)

Pour activer le déploiement GitHub Actions, ajoute le `github_oidc_subject` exact de la branche `main` de ton fork. Le format dépend des paramètres OIDC du fork. [Préparer OIDC](11-configurer-cicd.md#préparer-azure-une-fois)

```bash
terraform -chdir=terraform/infra init
```

`init` prépare Terraform et installe le provider Azure. Si l’identité `quizapp-lucas-mohamed-github-deploy` existe déjà dans le groupe `rg-quizapp-lucas-mohamed`, importe-la une fois entre `init` et `plan`. Terraform pourra ainsi gérer cette identité existante.

```bash
terraform -chdir=terraform/infra import \
  'azurerm_user_assigned_identity.github[0]' \
  "/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/rg-quizapp-lucas-mohamed/providers/Microsoft.ManagedIdentity/userAssignedIdentities/quizapp-lucas-mohamed-github-deploy"
```

```bash
terraform -chdir=terraform/infra plan
terraform -chdir=terraform/infra apply
```

`plan` affiche les ressources que Terraform prévoit de créer. `apply` les crée dans l’abonnement sélectionné une fois le plan confirmé.

## 3. Construire, scanner et publier les images

Ouvre Docker Desktop et utilise le fichier `.env` de ton installation locale. Le même build et le même scan Trivy servent à préparer les images à publier. [Démarrage local](10-demarrage-local.md)

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose -p quiz-ci build frontend backend &&
  scripts/scan-images.sh quiz-ci-frontend:latest quiz-ci-backend:latest
```

Quand le scan réussit, publie les deux images. Ces commandes enregistrent dans `terraform/apps/images.auto.tfvars.json` leur **digest**, l’identifiant exact de chaque image dans ACR.

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

```bash
terraform -chdir=terraform/infra output -json app_inputs > terraform/apps/infrastructure.auto.tfvars.json
cp terraform/apps/terraform.tfvars.example terraform/apps/terraform.tfvars
```

Remplis `admin_password` et `jwt_secret` dans `terraform/apps/terraform.tfvars`. Terraform place ces valeurs dans les secrets du backend et les conserve dans son état `.tfstate`. Garde ces fichiers sur ta machine. Git et le contexte de build Docker les ignorent.

- Pour enregistrer des scores, utilise une base PostgreSQL externe, par exemple Neon. Initialise le schéma avec `database/init.sql` sur une base vide et renseigne `database_url` avec une connexion TLS vérifiée. [Configurer Neon](10-demarrage-local.md#utiliser-neon-depuis-docker)
- Pour envoyer les résultats aux participants, vérifie le domaine expéditeur dans Resend. Renseigne `resend_api_key` et `from_email` lors de la création des apps. Après la création, ajoute les mêmes réglages dans GitHub sous le secret `RESEND_API_KEY` et la variable `FROM_EMAIL` pour les prochaines livraisons. L’expéditeur de test `onboarding@resend.dev` envoie seulement à l’adresse de ton compte Resend. [Restrictions de l’expéditeur de test](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain)

```bash
terraform -chdir=terraform/apps init
terraform -chdir=terraform/apps plan
terraform -chdir=terraform/apps apply
```

Azure fournit l’adresse HTTPS automatiquement. Ouvre celle renvoyée par `frontend_url`, puis vérifie que `/health` répond avec `{"status":"ok"}` et HTTP 200. Pour le jalon PostgreSQL, enregistre ensuite un résultat et retrouve-le dans la page de gestion. Le nom personnalisé est un bonus attribué par le formateur. [Sous-domaine et HTTPS](05-bonus-azure.md#sous-domaine-personnalisé-et-https)

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

Après la création, le workflow existant utilise `scripts/deploy.sh` pour publier les nouvelles images et mettre à jour leurs digests, les variables et les secrets du backend. Pour changer ces valeurs après le premier déploiement, mets à jour les paramètres du workflow ou utilise le script Azure CLI. Terraform continue de gérer le réseau, les identités et la capacité des applications.

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

```bash
terraform -chdir=terraform/apps destroy &&
  terraform -chdir=terraform/infra destroy
```
