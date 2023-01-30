# local 定義
locals {
    github_repository           = "nevenisnoob/WorkloadIdentityFederation"
    project_id                  = "workload-idenity-federation"
    region                      = "asia-northeast1"
    terraform_service_account   = "terraform-github@workload-idenity-federation.iam.gserviceaccount.com"

    # api 有効化用
    services = toset([                         # Workload Identity 連携用
        "iam.googleapis.com",                  # IAM
        "cloudresourcemanager.googleapis.com", # Resource Manager
        "iamcredentials.googleapis.com",       # Service Account Credentials
        "sts.googleapis.com"                   # Security Token Service API
    ])
}

# provider 設定
terraform {
    required_providers {
        google  = {
            source  = "hashicorp/google"
            version = ">= 4.0.0"
        }
    }
    required_version = ">= 1.3.0"
    backend "gcs" {
        bucket = "wif_terraform_tfstate"
        prefix = "terraform/state"
    }
}

## API の有効化(Workload Identity 用)
resource "google_project_service" "enable_api" {
  for_each                   = local.services
  project                    = local.project_id
  service                    = each.value
  disable_dependent_services = true
}

# wif正しく実行するために、terraform用のsaに以下の権限を付与する必要があります
resource "google_project_iam_member" "terraform_sa_role" {
  for_each = toset([
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageViewer",
    "roles/iam.serviceAccountViewer",
    "roles/iam.workloadIdentityPoolAdmin"
  ])
  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${data.google_service_account.terraform-sa.email}"
}

# Workload Identity Pool 設定
resource "google_iam_workload_identity_pool" "my-wif-pool" {
    provider                  = google-beta
    project                   = local.project_id
    workload_identity_pool_id = "my-wif-pool"
    display_name              = "my-wif-pool"
    description               = "GitHub Actions で使用"
}

# Workload Identity Provider 設定
resource "google_iam_workload_identity_pool_provider" "my-wif-provider" {
    provider                           = google-beta
    project                            = local.project_id
    workload_identity_pool_id          = google_iam_workload_identity_pool.my-wif-pool.workload_identity_pool_id
    workload_identity_pool_provider_id = "my-wif-provider"
    display_name                       = "my-wif-provider"
    description                        = "GitHub Actions で使用"

    attribute_mapping = {
        "google.subject"       = "assertion.sub"
        "attribute.repository" = "assertion.repository"
    }

    oidc {
        issuer_uri = "https://token.actions.githubusercontent.com"
    }
}

# GitHub Actions が借用するサービスアカウント
data "google_service_account" "terraform-sa" {
  account_id = local.terraform_service_account
}


# サービスアカウントの IAM Policy 設定と GitHub リポジトリの指定
resource "google_service_account_iam_member" "terraform_sa" {
    service_account_id = data.google_service_account.terraform-sa.id
    role               = "roles/iam.workloadIdentityUser"
    member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.my-wif-pool.name}/attribute.repository/${local.github_repository}"
}
