# Terraform AWS KMS module 

This module creates **many KMS keys** per region using a single module call (`keys = { ... }`).

## Goals
- **AWS-style default**: by default, the key policy enables IAM policies in the account to grant key usage
- **Easy restriction**: optionally restrict usage to explicit IAM principals and/or AWS services
- **Diff-safe**: uses `aws_kms_key_policy` (separate resource) instead of inline key policy
- **Multi-Region primary keys** supported (`multi_region = true`) — replicas are created outside the module using provider aliases
- **Origin selector** for different key types (AWS-managed, imported key material, Custom Key Store)

---

## Key origins

Per-key, choose the origin mode:

```hcl
origin = "AWS_KMS"      # default (AWS generates key material)
origin = "EXTERNAL"     # imported key material (BYOK) via aws_kms_external_key
origin = "AWS_CLOUDHSM" # Custom Key Store key (requires custom_key_store_id)
```

### EXTERNAL notes

If you set `origin = "EXTERNAL"` you can optionally pass `key_material_base64`.
If you **don't** pass key material, the key is created in **PendingImport** and the module will keep it **disabled**.

### AWS_CLOUDHSM notes

If you set `custom_key_store_id`, the module treats the key as `AWS_CLOUDHSM` automatically.
Custom Key Store keys are limited to symmetric encryption keys and do not support multi-region or automatic rotation.

---

## Policy behavior (important)

### Default (AWS-style, account-wide IAM permissions)
If you do **not** set `kms_key_users` and do **not** set `allowed_via_services`, the module adds
a statement allowing usage by principals in the same account when permitted by IAM policies.

### Restricted to explicit IAM principals
Set:
```hcl
kms_key_administrators = [aws_iam_role.platform_deployer.arn]
kms_key_users          = [aws_iam_role.platform_deployer.arn]
```

### Service-scoped key
Set:
```hcl
allowed_via_services = ["s3"]            # S3-only
allowed_via_services = ["ec2"]           # EBS/EC2-only
allowed_via_services = ["logs"]          # CloudWatch Logs-only
allowed_via_services = ["secretsmanager"]# Secrets Manager-only
allowed_via_services = ["codepipeline","codebuild","s3"] # artifacts/pipeline common set
```

The module enforces service scope using:
- `kms:CallerAccount`
- `kms:ViaService = <service>.<region>.amazonaws.com`

---

## Automatic rotation

You can globally enable/disable KMS automatic rotation:

```hcl
enable_automatic_rotation = true  # default
```

Per-key, you still control rotation with `enable_key_rotation`.

If rotation is enabled, you can set `rotation_period_in_days` (90..2560). Default is 365.


## Usage
### Basic example
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.00"
    }
  }
}
provider "aws" {
  region = "eu-central-1"
}

module "kms" {
  # enable_automatic_rotation = true
  source = "../../"
  keys = {
    general = {
      description   = "General purpose key"
      primary_alias = "general"
    }
    restricted = {
      description            = "Restricted key"
      primary_alias          = "restricted"
      kms_key_administrators = ["arn:aws:iam::123456789012:role/platform-deployer"]
      kms_key_users          = ["arn:aws:iam::123456789012:role/platform-deployer"]
    }
  }
}
output "keys" { value = module.kms.keys }

```
### Multi region primary and replica
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.00"
    }
  }
}
provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

module "kms_primary" {
  source = "../../"
  keys = {
    mr = {
      description          = "Multi-Region PRIMARY key"
      primary_alias        = "mr-key"
      multi_region         = true
      allowed_via_services = ["s3"]
    }
  }
}

resource "aws_kms_replica_key" "eu_west_1" {
  provider        = aws.eu_west_1
  primary_key_arn = module.kms_primary.keys["mr"].arn
  description     = "Replica in eu-west-1"
}

resource "aws_kms_alias" "eu_west_1_alias" {
  provider      = aws.eu_west_1
  name          = "alias/mr-key"
  target_key_id = aws_kms_replica_key.eu_west_1.key_id
}

output "primary" { value = module.kms_primary.keys["mr"] }
output "replica_key_id" { value = aws_kms_replica_key.eu_west_1.key_id }
```

### Service scoped
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.00"
    }
  }
}
provider "aws" {
  region = "eu-central-1"
}

module "kms" {
  source = "../../"
  keys = {
    s3 = {
      description          = "S3-only key"
      primary_alias        = "s3-key"
      allowed_via_services = ["s3"]
    }
    ebs = {
      description          = "EBS/EC2-only key"
      primary_alias        = "ebs-key"
      allowed_via_services = ["ec2"]
    }
    logs = {
      description          = "Logs-only key"
      primary_alias        = "logs-key"
      allowed_via_services = ["logs"]
    }
    secrets = {
      description          = "Secrets-only key"
      primary_alias        = "secrets-key"
      allowed_via_services = ["secretsmanager"]
    }
    artifacts = {
      description          = "Artifacts/pipeline key"
      primary_alias        = "artifacts-key"
      allowed_via_services = ["s3", "codepipeline", "codebuild"]
    }
  }
}
output "keys" { value = module.kms.keys }
```