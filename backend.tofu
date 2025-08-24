terraform {
  backend "gcs" {
    prefix             = "google-cloud-opentofu-backend"
    kms_encryption_key = "projects/plt-lz-backend-tf69-sb/locations/global/keyRings/state-encryption/cryptoKeys/default"
  }
}
