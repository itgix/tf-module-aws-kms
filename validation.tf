check "keys_custom_requires_usage_and_spec" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      (cfg.preset != "custom") || (cfg.key_usage != null && cfg.key_spec != null)
    ])
    error_message = "For any key with preset=custom you must set both key_usage and key_spec."
  }
}

check "keys_primary_alias_format" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      !startswith(cfg.primary_alias, "alias/") && !startswith(cfg.primary_alias, "aws/")
    ])
    error_message = "primary_alias must be provided WITHOUT 'alias/' and cannot start with reserved 'aws/'."
  }
}

check "keys_extra_aliases_format" {
  assert {
    condition = alltrue(flatten([
      for _, cfg in var.keys : [
        for a in coalesce(cfg.extra_aliases, []) :
        !startswith(a, "alias/") && !startswith(a, "aws/")
      ]
    ]))
    error_message = "extra_aliases must be provided WITHOUT 'alias/' and cannot start with reserved 'aws/'."
  }
}

check "keys_deletion_window_range" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      cfg.deletion_window_in_days >= 7 && cfg.deletion_window_in_days <= 30
    ])
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

check "keys_origin_allowed" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      contains(["AWS_KMS", "EXTERNAL", "AWS_CLOUDHSM"], cfg.origin)
    ])
    error_message = "origin must be one of: AWS_KMS, EXTERNAL, AWS_CLOUDHSM."
  }
}

# Rotation rules:
# - Automatic rotation is only for AWS_KMS-origin symmetric ENCRYPT_DECRYPT keys.
# - When enabled, rotation_period_in_days must be 90..2560 (AWS flexible rotation).
check "keys_rotation_is_valid" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      (
        # if global rotation off -> always OK
        var.enable_automatic_rotation == false
        # if key rotation disabled -> always OK
        || cfg.enable_key_rotation == false
        # else key rotation requested -> enforce constraints
        || (
          # rotation is only for AWS_KMS-origin keys
          cfg.origin == "AWS_KMS" && cfg.custom_key_store_id == null
          # only symmetric ENCRYPT_DECRYPT
          && (
            (cfg.key_usage != null ? cfg.key_usage : (cfg.preset != "custom" ? local.presets[cfg.preset].key_usage : "")) == "ENCRYPT_DECRYPT"
          )
          && (
            (cfg.key_spec != null ? cfg.key_spec : (cfg.preset != "custom" ? local.presets[cfg.preset].key_spec : "")) == "SYMMETRIC_DEFAULT"
          )
          # flexible rotation period
          && cfg.rotation_period_in_days >= 90
          && cfg.rotation_period_in_days <= 2560
        )
      )
    ])
    error_message = "Automatic rotation is only for AWS_KMS-origin symmetric ENCRYPT_DECRYPT keys. When enabled, rotation_period_in_days must be between 90 and 2560."
  }
}

# EXTERNAL guardrails (module supports EXTERNAL via aws_kms_external_key)
check "keys_external_constraints" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      (
        cfg.origin != "EXTERNAL"
        || (
          # Terraform aws_kms_external_key imports/uses 256-bit symmetric material
          ((cfg.key_usage != null ? cfg.key_usage : (cfg.preset != "custom" ? local.presets[cfg.preset].key_usage : "")) == "ENCRYPT_DECRYPT")
          && ((cfg.key_spec != null ? cfg.key_spec : (cfg.preset != "custom" ? local.presets[cfg.preset].key_spec : "")) == "SYMMETRIC_DEFAULT")
          # automatic rotation not supported for EXTERNAL
          && (cfg.enable_key_rotation == false || var.enable_automatic_rotation == false)
        )
      )
    ])
    error_message = "For origin=EXTERNAL, this module supports only symmetric ENCRYPT_DECRYPT + SYMMETRIC_DEFAULT, and automatic rotation must be disabled."
  }
}

# AWS_CLOUDHSM (custom key store) guardrails
check "keys_cloudhsm_constraints" {
  assert {
    condition = alltrue([
      for _, cfg in var.keys :
      (
        (cfg.origin != "AWS_CLOUDHSM" && cfg.custom_key_store_id == null)
        || (
          cfg.custom_key_store_id != null
          && cfg.multi_region == false
          && (cfg.enable_key_rotation == false || var.enable_automatic_rotation == false)
          && ((cfg.key_usage != null ? cfg.key_usage : (cfg.preset != "custom" ? local.presets[cfg.preset].key_usage : "")) == "ENCRYPT_DECRYPT")
          && ((cfg.key_spec != null ? cfg.key_spec : (cfg.preset != "custom" ? local.presets[cfg.preset].key_spec : "")) == "SYMMETRIC_DEFAULT")
        )
      )
    ])
    error_message = "For Custom Key Store keys (origin=AWS_CLOUDHSM OR custom_key_store_id set), you must set custom_key_store_id; multi_region must be false; automatic rotation must be disabled; only symmetric ENCRYPT_DECRYPT + SYMMETRIC_DEFAULT is supported."
  }
}
