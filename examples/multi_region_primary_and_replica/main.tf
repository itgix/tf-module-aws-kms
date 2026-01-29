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
