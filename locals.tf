locals {
  presets = {
    symmetric = {
      key_usage = "ENCRYPT_DECRYPT"
      key_spec  = "SYMMETRIC_DEFAULT"
    }
    asymmetric_sign = {
      key_usage = "SIGN_VERIFY"
      key_spec  = "RSA_2048"
    }
    hmac = {
      key_usage = "GENERATE_VERIFY_MAC"
      key_spec  = "HMAC_256"
    }
  }

  account_id       = data.aws_caller_identity.current.account_id
  account_root_arn = "arn:aws:iam::${local.account_id}:root"
  region           = data.aws_region.current.region

  resolved = {
    for name, cfg in var.keys : name => {
      description = cfg.description
      preset      = cfg.preset

      key_usage = cfg.key_usage != null ? cfg.key_usage : local.presets[cfg.preset].key_usage
      key_spec  = cfg.key_spec != null ? cfg.key_spec : local.presets[cfg.preset].key_spec

      # If a custom key store is supplied, treat this key as AWS_CLOUDHSM.
      origin              = cfg.custom_key_store_id != null ? "AWS_CLOUDHSM" : cfg.origin
      custom_key_store_id = cfg.custom_key_store_id

      # External key material (EXTERNAL only). If null, key will be created in PendingImport state (must remain disabled).
      key_material_base64 = cfg.key_material_base64

      multi_region            = cfg.multi_region
      enable_key_rotation     = cfg.enable_key_rotation
      rotation_period_in_days = cfg.rotation_period_in_days
      deletion_window_in_days = cfg.deletion_window_in_days
      is_enabled              = cfg.is_enabled

      primary_alias = cfg.primary_alias
      extra_aliases = distinct(cfg.extra_aliases)

      kms_key_administrators = distinct(cfg.kms_key_administrators)
      kms_key_users          = distinct(cfg.kms_key_users)

      allowed_via_services = distinct(cfg.allowed_via_services)

      policy_json = cfg.policy_json

      tags = merge(var.tags, cfg.tags)

      # mode detection
      is_restricted = (length(cfg.kms_key_users) > 0) || (length(cfg.allowed_via_services) > 0)
    }
  }

  keys_kms = {
    for k, v in local.resolved : k => v if v.origin != "EXTERNAL"
  }

  keys_external = {
    for k, v in local.resolved : k => v if v.origin == "EXTERNAL"
  }
}
