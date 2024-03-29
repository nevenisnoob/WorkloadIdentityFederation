# local 定義
locals {
  github_repository         = "nevenisnoob/WorkloadIdentityFederation"
  project_id                = "workload-idenity-federation"
  region                    = "asia-northeast1"
  terraform_service_account = "terraform-github@workload-idenity-federation.iam.gserviceaccount.com"

  # api 有効化用
  services = toset([                       # Workload Identity 連携用
    "storage.googleapis.com",              # Terraform state
    "iam.googleapis.com",                  # IAM
    "cloudresourcemanager.googleapis.com", # Resource Manager
    "iamcredentials.googleapis.com",       # Service Account Credentials
    "sts.googleapis.com"                   # Security Token Service API
  ])

  valid_caller_ips = [
    "10.236.41.187/32", # gotdev5002 ip address: 10.236.41.187（動的に変わることがあるので要注意）
  ]
}
