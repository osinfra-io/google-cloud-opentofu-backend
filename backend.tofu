terraform {
  backend "gcs" {
    prefix             = "google-cloud-opentofu-backend"
    kms_encryption_key = local.kms_encryption_key
  }
}
