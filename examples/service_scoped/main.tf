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
