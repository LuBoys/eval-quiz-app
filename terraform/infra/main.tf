data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "quiz" {
  count = var.use_existing_resource_group ? 0 : 1

  name     = var.resource_group_name
  location = var.location
}

data "azurerm_resource_group" "existing_quiz" {
  count = var.use_existing_resource_group ? 1 : 0

  name = var.resource_group_name
}

locals {
  resource_group_name = var.use_existing_resource_group ? data.azurerm_resource_group.existing_quiz[0].name : azurerm_resource_group.quiz[0].name
  resource_group_id   = var.use_existing_resource_group ? data.azurerm_resource_group.existing_quiz[0].id : azurerm_resource_group.quiz[0].id
}

resource "azurerm_container_registry" "quiz" {
  name                                         = var.acr_name
  resource_group_name                          = local.resource_group_name
  location                                     = var.location
  sku                                          = "Basic"
  admin_enabled                                = false
  role_assignment_mode                         = "LegacyRegistryPermissions"
  azuread_authentication_as_arm_policy_enabled = true
}

resource "azurerm_container_app_environment" "quiz" {
  name                = "quiz-env"
  resource_group_name = local.resource_group_name
  location            = var.location

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "quiz-acr-pull"
  resource_group_name = local.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                            = azurerm_container_registry.quiz.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.acr_pull.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_user_assigned_identity" "github" {
  count = var.github_oidc_subject == null ? 0 : 1

  name                = "quiz-github-deploy"
  resource_group_name = local.resource_group_name
  location            = var.location
}

resource "azurerm_federated_identity_credential" "github_main" {
  count = var.github_oidc_subject == null ? 0 : 1

  name                      = "github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.github[0].id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = var.github_oidc_subject
}

locals {
  github_roles = {
    acr_push = {
      scope = azurerm_container_registry.quiz.id
      role  = "AcrPush"
    }
    acr_reader = {
      scope = azurerm_container_registry.quiz.id
      role  = "Reader"
    }
    container_apps = {
      scope = local.resource_group_id
      role  = "Container Apps Contributor"
    }
    pull_identity = {
      scope = azurerm_user_assigned_identity.acr_pull.id
      role  = "Managed Identity Operator"
    }
  }
}

resource "azurerm_role_assignment" "github" {
  for_each = var.github_oidc_subject == null ? {} : local.github_roles

  scope                            = each.value.scope
  role_definition_name             = each.value.role
  principal_id                     = azurerm_user_assigned_identity.github[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
