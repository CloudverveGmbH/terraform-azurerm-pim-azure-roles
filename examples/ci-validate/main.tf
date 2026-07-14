# ---------------------------------------------------------------------------
# CI validation wrapper.
# Instantiates the module with minimal inputs so `terraform validate` can run
# in CI without a backend or real Azure credentials.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

provider "azuread" {}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

module "pim_azure_role" {
  source = "../.."

  group_display_name = "AKS Cluster Admin"

  role_assignments = [{
    scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ci-validate"
    role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
    name                 = "aks-cluster-admin"
  }]
}
