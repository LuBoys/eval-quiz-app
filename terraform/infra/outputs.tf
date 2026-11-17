output "acr_name" {
  description = "Nom du registre à passer à Azure CLI."
  value       = azurerm_container_registry.quiz.name
}

output "app_inputs" {
  description = "Valeurs à transmettre au dossier terraform/apps."
  value = {
    infrastructure = {
      resource_group_name          = local.resource_group_name
      registry_login_server        = azurerm_container_registry.quiz.login_server
      container_app_environment_id = azurerm_container_app_environment.quiz.id
      pull_identity_id             = azurerm_user_assigned_identity.acr_pull.id
    }
  }
}

output "deployment_variables" {
  description = "Noms à renseigner pour scripts/deploy.sh et GitHub Actions."
  value = {
    AZURE_RESOURCE_GROUP            = local.resource_group_name
    ACR_NAME                        = azurerm_container_registry.quiz.name
    AZURE_CONTAINERAPPS_ENVIRONMENT = azurerm_container_app_environment.quiz.name
    AZURE_ACR_PULL_IDENTITY         = azurerm_user_assigned_identity.acr_pull.name
  }
}

output "github_login_variables" {
  description = "Identifiants GitHub Actions à ajouter quand OIDC est activé."
  value = var.github_oidc_subject == null ? null : {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.github[0].client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
  }
}
