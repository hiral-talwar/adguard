# providers.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: tells Terraform "you're going to be talking to Azure."
# Terraform itself doesn't know about any specific cloud by default — this
# file is what plugs in the Azure-specific translator (called a "provider").
# You will not need to edit this file for the ADGuard project.
# ----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion = true # when you DO eventually `terraform destroy`, this makes sure the hard disk gets deleted too, not left behind quietly billing you
    }
  }
}
