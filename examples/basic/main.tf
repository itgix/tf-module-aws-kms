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
