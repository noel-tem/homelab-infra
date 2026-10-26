# State lives in a Cloudflare R2 bucket; it's encrypted before upload (encryption.tf)
# Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (an R2 API token)
variable "r2_account_id" {
  type = string
}

variable "r2_bucket" {
  type = string
}

terraform {
  backend "s3" {
    bucket       = var.r2_bucket
    key          = "homelab/terraform.tfstate"
    region       = "auto"
    use_lockfile = true
    endpoints = {
      s3 = "https://${var.r2_account_id}.r2.cloudflarestorage.com"
    }

    # R2 isn't AWS, so skip the AWS-only checks
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
