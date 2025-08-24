terraform {

  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  encryption {
    key_provider "gcp_kms" "default" {
      kms_encryption_key = "projects/plt-lz-backend-tf69-sb/locations/us/keyRings/state-encryption/cryptoKeys/default"
      key_length         = 32
    }

    method "aes_gcm" "default" {
      keys = key_provider.gcp_kms.default
    }

    plan {
      method   = method.aes_gcm.default
      enforced = true
    }

    state {
      method   = method.aes_gcm.default
      enforced = true
    }
  }


  # Requiring Providers
  # https://opentofu.org/docs/language/providers/requirements#requiring-providers

  required_providers {

    # Datadog Provider
    # https://search.opentofu.org/provider/DataDog/datadog/latest/docs

    datadog = {
      source = "datadog/datadog"
    }

    # Google Cloud Platform Provider
    # https://search.opentofu.org/provider/hashicorp/google/latest/docs

    google = {
      source = "hashicorp/google"
    }

    # Random Provider
    # https://opentofu.org/docs/providers/random/index.html

    random = {
      source = "hashicorp/random"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}


# Google Cloud Provider
# https://search.opentofu.org/provider/hashicorp/google/latest/docs

# This is only needed during bootstrapping.

# provider "google" {
#   billing_project       = var.billing_project
#   user_project_override = true
# }
