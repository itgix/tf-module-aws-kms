# AWS-managed key material (AWS_KMS / CloudHSM via custom key store)
resource "aws_kms_key" "this" {
  for_each = local.keys_kms

  description              = each.value.description
  key_usage                = each.value.key_usage
  customer_master_key_spec = each.value.key_spec

  # For custom key stores (AWS_CLOUDHSM): pass the custom key store id
  custom_key_store_id = each.value.custom_key_store_id

  multi_region            = each.value.multi_region
  deletion_window_in_days = each.value.deletion_window_in_days
  is_enabled              = each.value.is_enabled

  enable_key_rotation = (
    var.enable_automatic_rotation == true &&
    each.value.origin == "AWS_KMS" &&
    each.value.enable_key_rotation == true &&
    each.value.key_usage == "ENCRYPT_DECRYPT" &&
    each.value.key_spec == "SYMMETRIC_DEFAULT"
  )

  rotation_period_in_days = (
    var.enable_automatic_rotation == true &&
    each.value.origin == "AWS_KMS" &&
    each.value.enable_key_rotation == true &&
    each.value.key_usage == "ENCRYPT_DECRYPT" &&
    each.value.key_spec == "SYMMETRIC_DEFAULT"
  ) ? each.value.rotation_period_in_days : null

  tags = each.value.tags

  lifecycle {
    # Guardrail: rotation only supported for symmetric ENCRYPT_DECRYPT keys with AWS-managed key material.
    precondition {
      condition = (
        each.value.enable_key_rotation == false ||
        var.enable_automatic_rotation == false ||
        (
          each.value.origin == "AWS_KMS" &&
          each.value.key_usage == "ENCRYPT_DECRYPT" &&
          each.value.key_spec == "SYMMETRIC_DEFAULT"
        )
      )
      error_message = "Key rotation is only supported for symmetric ENCRYPT_DECRYPT keys with AWS-managed key material. Set enable_key_rotation=false for other key types or origins."
    }
  }
}

# Imported key material (EXTERNAL / BYOK)
resource "aws_kms_external_key" "this" {
  for_each = local.keys_external

  description = each.value.description
  key_usage   = each.value.key_usage
  key_spec    = each.value.key_spec

  # NOTE: If key material is not provided, key is created in PendingImport and should remain disabled.
  enabled = each.value.key_material_base64 != null ? each.value.is_enabled : false

  deletion_window_in_days = each.value.deletion_window_in_days

  # Optional: if null, Terraform won't import and the key stays PendingImport.
  key_material_base64 = each.value.key_material_base64

  multi_region = each.value.multi_region

  tags = each.value.tags
}

# Unified lookup maps (so downstream resources don't care which type was used)
locals {
  key_id_by_key = merge(
    { for k, v in aws_kms_key.this : k => v.key_id },
    { for k, v in aws_kms_external_key.this : k => v.key_id }
  )

  key_arn_by_key = merge(
    { for k, v in aws_kms_key.this : k => v.arn },
    { for k, v in aws_kms_external_key.this : k => v.arn }
  )

  key_multi_region_by_key = merge(
    { for k, v in aws_kms_key.this : k => v.multi_region },
    { for k, v in aws_kms_external_key.this : k => v.multi_region }
  )

  key_enabled_by_key = merge(
    { for k, v in aws_kms_key.this : k => v.is_enabled },
    { for k, v in aws_kms_external_key.this : k => v.enabled }
  )
}

# Apply policy separately (enterprise pattern)
resource "aws_kms_key_policy" "this" {
  for_each = local.resolved

  key_id = local.key_id_by_key[each.key]
  policy = (
    each.value.policy_json != null
    ? each.value.policy_json
    : data.aws_iam_policy_document.this[each.key].json
  )
}

# Aliases
# Primary alias
resource "aws_kms_alias" "primary" {
  for_each      = local.resolved
  name          = "alias/${each.value.primary_alias}"
  target_key_id = local.key_id_by_key[each.key]
}

# Extra aliases
resource "aws_kms_alias" "extra" {
  for_each = {
    for item in flatten([
      for k, cfg in local.resolved : [
        for a in cfg.extra_aliases : {
          key   = k
          alias = a
        }
      ]
    ]) : "${item.key}:${item.alias}" => item
  }

  name          = "alias/${each.value.alias}"
  target_key_id = local.key_id_by_key[each.value.key]
}
