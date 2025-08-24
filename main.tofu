# Datadog Google Cloud Platform Integration Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-datadog-google-integration

module "datadog" {
  source = "github.com/osinfra-io/opentofu-datadog-google-integration?ref=v0.3.6"
  count  = var.datadog_enable ? 1 : 0

  api_key                            = var.datadog_api_key
  is_cspm_enabled                    = true
  is_security_command_center_enabled = true
  labels                             = module.helpers.labels
  project                            = module.project.id
}

# Google Project Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-project

module "project" {
  source = "github.com/osinfra-io/opentofu-google-project?ref=v0.4.5"

  billing_account                 = var.project_billing_account
  cis_2_2_logging_sink_project_id = var.project_cis_2_2_logging_sink_project_id
  description                     = "backend"
  folder_id                       = var.project_folder_id
  labels                          = module.helpers.labels
  monthly_budget_amount           = var.project_monthly_budget_amount
  prefix                          = "plt-lz"

  services = [
    "billingbudgets.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudidentity.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com"
  ]
}

# Google Storage Bucket Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-storage-bucket

module "opentofu_state_storage_bucket" {
  source   = "github.com/osinfra-io/opentofu-google-storage-bucket?ref=v0.2.1"
  for_each = local.service_accounts

  labels   = module.helpers.labels
  location = "us"
  name     = "${each.key}-${random_id.bucket.hex}-${module.helpers.env}"
  project  = module.project.id
}

# Google Identity Group Membership
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/cloud_identity_group_membership

resource "google_cloud_identity_group_membership" "github_actions" {
  for_each = local.service_accounts

  # Use the following gcloud command to figure out the group_id
  # gcloud identity groups search --organization=osinfra.io --labels="cloudidentity.googleapis.com/groups.discussion_forum"

  # This should be the group_id for the gcp-billing-users group created in the google-cloud-hierarchy repository.

  group = "groups/${var.billing_users_group_id}"

  preferred_member_key {
    id = google_service_account.github_actions[each.key].email
  }

  roles { name = "MEMBER" }

  dynamic "roles" {
    for_each = each.key == "plt-lz-backend" ? [1] : []

    content {
      name = "MANAGER"
    }
  }

  depends_on = [
    module.project
  ]
}

# Google KMS Crypto Key Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_crypto_key

resource "google_kms_crypto_key" "state_encryption" {
  name            = "default"
  key_ring        = google_kms_key_ring.state_encryption.id
  labels          = module.helpers.labels
  rotation_period = "7776000s"

  # We can't use the lifecycle block to prevent destroy on this resource for testing purposes.

  # CryptoKeys cannot be deleted from Google Cloud Platform. Destroying a OpenTofu-managed CryptoKey will
  # remove it from state and delete all CryptoKeyVersions, rendering the key unusable, but will not delete
  # the resource from the project. When OpenTofu destroys these keys, any data previously encrypted with
  # these keys will be irrecoverable. For this reason, it is strongly recommended that you add lifecycle
  # hooks to the resource to prevent accidental destruction.

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Google KMS Crypto Key IAM Member
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member

resource "google_kms_crypto_key_iam_member" "github_actions" {
  for_each = local.service_accounts

  crypto_key_id = google_kms_crypto_key.state_encryption.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.github_actions[each.key].email}"
}

# Google KMS Key Ring Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_key_ring

resource "google_kms_key_ring" "state_encryption" {
  name     = "state-encryption"
  location = "global"
  project  = module.project.id

  # We can't use the lifecycle block to prevent destroy on this resource for testing purposes.

  # KeyRings cannot be deleted from Google Cloud Platform. Destroying a OpenTofu-managed KeyRing will remove it from
  # state but will not delete the resource from the project.

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Google Service Account Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/google_service_account

resource "google_service_account" "github_actions" {
  for_each = local.service_accounts

  account_id   = "${each.key}-github"
  display_name = "Service account for GitHub Actions"
  project      = module.project.id
}

# Google Service Account IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/google_service_account_iam#google_service_account_iam_member

resource "google_service_account_iam_member" "github_actions" {
  for_each = local.github_repositories

  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/osinfra-io/${each.value.repository}"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.github_actions[each.value.name].id
}

# Google Storage Bucket IAM Member
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/storage_bucket_iam#google_storage_bucket_iam_member

resource "google_storage_bucket_iam_member" "github_actions" {
  for_each = local.service_accounts

  bucket = module.opentofu_state_storage_bucket[each.key].name
  member = "serviceAccount:${google_service_account.github_actions[each.key].email}"
  role   = "roles/storage.objectAdmin"
}

# Random Random ID Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/id

resource "random_id" "bucket" {
  byte_length = 2
}
