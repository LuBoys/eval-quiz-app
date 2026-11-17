variable "project_name" {
  description = "Nom du projet utilisé pour le site et ses ressources Azure."
  type        = string
  default     = "quizapp-lucas-mohamed"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.project_name)) && !strcontains(var.project_name, "--")
    error_message = "Le nom doit faire 2 à 32 caractères, commencer par une lettre minuscule et finir par une lettre minuscule ou un chiffre. Les tirets simples sont autorisés."
  }
}

variable "location" {
  description = "Région Azure autorisée par l’abonnement étudiant."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.location) != "" && var.location != "REGION_AUTORISEE"
    error_message = "Renseigne un code de région Azure autorisé par ton abonnement."
  }
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources dédié au quiz."
  type        = string
  default     = null
}

variable "use_existing_resource_group" {
  description = "Utiliser un groupe déjà créé avec Azure CLI."
  type        = bool
  default     = false
  nullable    = false
}

variable "acr_name" {
  description = "Nom du registre Azure. Il doit être disponible mondialement."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "Le nom ACR doit contenir 5 à 50 lettres minuscules ou chiffres."
  }
}

variable "github_oidc_subject" {
  description = "Sujet OIDC de main dans le fork GitHub. Renseigne-le pour activer le déploiement GitHub Actions."
  type        = string
  default     = null

  validation {
    condition = (
      var.github_oidc_subject == null ||
      can(regex("^repo:[^/:]+/[^/:]+:ref:refs/heads/main$", var.github_oidc_subject))
    )
    error_message = "Utilise le sujet OIDC du fork GitHub pour refs/heads/main."
  }
}
