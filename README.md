The Terraform module is used by the ITGix AWS Landing Zone - https://itgix.com/itgix-landing-zone/

# AWS KMS Terraform Module

This module creates and manages AWS KMS keys with support for symmetric, asymmetric, HMAC, and external key material. Includes configurable key policies, aliases, rotation, and access controls.

Part of the [ITGix AWS Landing Zone](https://itgix.com/itgix-landing-zone/).

## Resources Created

- KMS keys (symmetric, asymmetric, HMAC, or external)
- KMS aliases (primary and extra)
- Key policies with administrator and user access
- Service-scoped grants

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS provider | >= 5.50 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `tags` | Tags applied to all resources (merged with per-key tags) | `map(string)` | `{}` | no |
| `enable_automatic_rotation` | Global toggle for KMS automatic rotation | `bool` | `true` | no |
| `enable_same_account_read_only` | Allow same-account read-only access to keys | `bool` | `false` | no |
| `keys` | Map of KMS keys to create (see below for object schema) | `map(object({...}))` | `{}` | no |

The `keys` object supports:

| Attribute | Description | Type | Default |
|-----------|-------------|------|---------|
| `description` | Key description | `string` | — (required) |
| `preset` | Key preset: `symmetric`, `asymmetric_sign`, `hmac`, `custom` | `string` | `"symmetric"` |
| `key_usage` | Key usage (required when preset = custom) | `string` | `null` |
| `key_spec` | Key spec (required when preset = custom) | `string` | `null` |
| `origin` | Key origin: `AWS_KMS`, `EXTERNAL`, `AWS_CLOUDHSM` | `string` | `"AWS_KMS"` |
| `custom_key_store_id` | Custom key store ID (for AWS_CLOUDHSM) | `string` | `null` |
| `key_material_base64` | Base64-encoded key material (EXTERNAL only) | `string` | `null` |
| `multi_region` | Enable multi-region key | `bool` | `false` |
| `enable_key_rotation` | Enable key rotation | `bool` | `true` |
| `rotation_period_in_days` | Rotation period in days | `number` | `365` |
| `deletion_window_in_days` | Deletion window in days | `number` | `30` |
| `is_enabled` | Whether the key is enabled | `bool` | `true` |
| `primary_alias` | Primary alias (without `alias/` prefix) | `string` | — (required) |
| `extra_aliases` | Additional aliases | `list(string)` | `[]` |
| `kms_key_administrators` | IAM ARNs for key administrators | `list(string)` | `[]` |
| `kms_key_users` | IAM ARNs for key users | `list(string)` | `[]` |
| `allowed_via_services` | AWS service names allowed to use the key | `list(string)` | `[]` |
| `policy_json` | Custom key policy JSON (escape hatch) | `string` | `null` |
| `tags` | Per-key tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `keys` | Map of created keys with key_id, arn, multi_region, enabled, primary_alias, and extra_aliases |

## Usage Example

```hcl
module "kms" {
  source = "path/to/tf-module-aws-kms"

  keys = {
    s3 = {
      description   = "KMS key for S3 encryption"
      primary_alias = "my-s3-key"
      allowed_via_services = ["s3"]
      kms_key_administrators = ["arn:aws:iam::123456789012:role/admin"]
    }
    ebs = {
      description   = "KMS key for EBS volumes"
      primary_alias = "my-ebs-key"
      allowed_via_services = ["ec2"]
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```
