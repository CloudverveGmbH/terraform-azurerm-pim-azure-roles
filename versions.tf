# ---------------------------------------------------------------------------
# Provider and Terraform version constraints.
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
    time = {
      source  = "hashicorp/time"
      version = ">= 0.10"
    }
  }
}
