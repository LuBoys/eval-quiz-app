#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage : %s GROUPE [--apply]\n' "$0"
  printf 'Affiche les ressources du groupe Azure dédié au quiz. --apply supprime le groupe.\n'
}

if [[ ${1:-} == --help ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 || -z ${1:-} || ${1:-} == -* || ( $# == 2 && ${2:-} != --apply ) ]]; then
  usage >&2
  exit 2
fi

group=$1
exists=$(az group exists --name "$group" --output tsv --only-show-errors)
if [[ "$exists" == false ]]; then
  printf 'Le groupe Azure %s est déjà absent.\n' "$group"
  exit 0
fi

subscription=$(az account show --query name --output tsv --only-show-errors)
printf 'Abonnement %s · groupe %s\n' "$subscription" "$group"
az resource list --resource-group "$group" --only-show-errors --output table \
  --query '[].{Ressource:name,Type:type,Region:location}'

if [[ ${2:-} == --apply ]]; then
  az group delete --name "$group" --yes --only-show-errors
  printf 'Groupe Azure %s supprimé.\n' "$group"
else
  printf 'Pour lancer la suppression, relance la commande avec --apply.\n'
fi
