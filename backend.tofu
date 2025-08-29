terraform {
  backend "gcs" {
    prefix             = "google-cloud-opentofu-backend"
    kms_encryption_key = var.kms_encryption_key
  }
}
