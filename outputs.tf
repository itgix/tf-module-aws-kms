output "keys" {
  description = "Map of created keys with ids/arns/aliases."
  value = {
    for k, cfg in local.resolved : k => {
      key_id        = local.key_id_by_key[k]
      arn           = local.key_arn_by_key[k]
      multi_region  = local.key_multi_region_by_key[k]
      enabled       = local.key_enabled_by_key[k]
      primary_alias = aws_kms_alias.primary[k].name
      extra_aliases = [
        for a_key, a in aws_kms_alias.extra :
        a.name if startswith(a_key, "${k}:")
      ]
    }
  }
}
