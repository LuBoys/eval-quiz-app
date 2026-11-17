#!/usr/bin/env bash
set -euo pipefail

image_tag=${1:?Usage : scripts/deploy.sh TAG_DU_COMMIT}
resource_group=${AZURE_RESOURCE_GROUP:?Renseigne AZURE_RESOURCE_GROUP}
registry=${ACR_NAME:?Renseigne ACR_NAME}
environment=${AZURE_CONTAINERAPPS_ENVIRONMENT:?Renseigne AZURE_CONTAINERAPPS_ENVIRONMENT}
identity=${AZURE_ACR_PULL_IDENTITY:?Renseigne AZURE_ACR_PULL_IDENTITY}
frontend_app=${AZURE_FRONTEND_APP:-quiz-frontend}
backend_app=${AZURE_BACKEND_APP:-quiz-backend}
image_project=${COMPOSE_PROJECT_NAME:-quiz-ci}

backend_secrets=(
  "admin-password=${ADMIN_PASSWORD:?Renseigne le secret ADMIN_PASSWORD}"
  "jwt-secret=${JWT_SECRET:?Renseigne le secret JWT_SECRET}"
)
database_ref=''
resend_ref=''
if [[ -n ${DATABASE_URL:-} ]]; then
  backend_secrets+=("database-url=$DATABASE_URL")
  database_ref='secretref:database-url'
fi
if [[ -n ${RESEND_API_KEY:-} ]]; then
  : "${FROM_EMAIL:?Renseigne FROM_EMAIL pour activer Resend}"
  backend_secrets+=("resend-api-key=$RESEND_API_KEY")
  resend_ref='secretref:resend-api-key'
fi
backend_env=(
  "ADMIN_USERNAME=${ADMIN_USERNAME:-admin}"
  'ADMIN_PASSWORD=secretref:admin-password'
  'JWT_SECRET=secretref:jwt-secret'
  "DATABASE_URL=$database_ref"
  "RESEND_API_KEY=$resend_ref"
  "FROM_EMAIL=${FROM_EMAIL:-}"
)

for service in frontend backend; do
  platform=$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$image_project-$service:latest")
  if [[ "$platform" != 'linux/amd64' ]]; then
    echo "L’image $service doit être construite pour linux/amd64." >&2
    exit 1
  fi
done

registry_server=$(az acr show --resource-group "$resource_group" --name "$registry" \
  --query loginServer --output tsv --only-show-errors)
environment_id=$(az containerapp env show --resource-group "$resource_group" --name "$environment" \
  --query id --output tsv --only-show-errors)
identity_id=$(az identity show --resource-group "$resource_group" --name "$identity" \
  --query id --output tsv --only-show-errors)
apps=$(az containerapp list --resource-group "$resource_group" --query '[].name' --output tsv --only-show-errors)
az acr login --name "$registry" --only-show-errors --output none

publish_image() {
  local service=$1 repository=$2 tagged digest
  tagged="$registry_server/$repository:$image_tag"
  docker image tag "$image_project-$service:latest" "$tagged"
  docker image push "$tagged" >&2
  digest=$(az acr repository show --name "$registry" --image "$repository:$image_tag" \
    --query digest --output tsv --only-show-errors)
  if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "ACR n’a pas renvoyé de digest pour $tagged." >&2
    return 1
  fi
  printf '%s/%s@%s\n' "$registry_server" "$repository" "$digest"
}

backend_image=$(publish_image backend quiz-backend)
frontend_image=$(publish_image frontend quiz-frontend)

app_options=(
  --resource-group "$resource_group"
  --environment "$environment_id"
  --user-assigned "$identity_id"
  --registry-server "$registry_server"
  --registry-identity "$identity_id"
  --min-replicas 0 --max-replicas 2
  --cpu 0.25 --memory 0.5Gi
  --revisions-mode single
  --only-show-errors --output none
)

if grep -Fxq -- "$backend_app" <<< "$apps"; then
  az containerapp secret set --resource-group "$resource_group" --name "$backend_app" \
    --secrets "${backend_secrets[@]}" --only-show-errors --output none
  az containerapp update --resource-group "$resource_group" --name "$backend_app" \
    --image "$backend_image" --set-env-vars "${backend_env[@]}" --only-show-errors --output none
else
  az containerapp create "${app_options[@]}" --name "$backend_app" --image "$backend_image" \
    --ingress internal --target-port 3007 --secrets "${backend_secrets[@]}" --env-vars "${backend_env[@]}"
fi

backend_host=$(az containerapp show --resource-group "$resource_group" --name "$backend_app" \
  --query properties.configuration.ingress.fqdn --output tsv --only-show-errors)
: "${backend_host:?Le backend doit avoir une entrée réseau interne}"

if grep -Fxq -- "$frontend_app" <<< "$apps"; then
  az containerapp update --resource-group "$resource_group" --name "$frontend_app" \
    --image "$frontend_image" --set-env-vars "BACKEND_URL=https://$backend_host" --only-show-errors --output none
else
  az containerapp create "${app_options[@]}" --name "$frontend_app" --image "$frontend_image" \
    --ingress external --target-port 8080 --env-vars "BACKEND_URL=https://$backend_host"
fi

frontend_host=$(az containerapp show --resource-group "$resource_group" --name "$frontend_app" \
  --query properties.configuration.ingress.fqdn --output tsv --only-show-errors)
: "${frontend_host:?Le frontend doit avoir une entrée réseau publique}"

for app in "$backend_app" "$frontend_app"; do
  revision=''
  for attempt in {1..12}; do
    revision=$(az containerapp show --resource-group "$resource_group" --name "$app" \
      --query "properties.latestRevisionName == properties.latestReadyRevisionName && properties.latestReadyRevisionName || ''" \
      --output tsv --only-show-errors)
    if [[ -n "$revision" ]]; then
      break
    fi
    sleep 5
  done
  : "${revision:?La nouvelle révision de $app n’est pas prête}"
  printf '%s · %s\n' "$app" "$revision"
done

health=$(curl --fail --silent --show-error --retry 10 --retry-all-errors --retry-delay 5 \
  --max-time 15 "https://$frontend_host/health")
if [[ "$health" != '{"status":"ok"}' ]]; then
  echo 'La réponse de /health ne correspond pas à celle du backend.' >&2
  exit 1
fi
printf 'Quiz App · https://%s\n' "$frontend_host"
printf 'API · HTTP 200 · %s\n' "$health"
