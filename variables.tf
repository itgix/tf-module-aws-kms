# Common inputs
variable "tags" {
  description = "Tags applied to all resources (merged with per-key tags; per-key wins)."
  type        = map(string)
  default     = {}
}

variable "enable_automatic_rotation" {
  description = "Global toggle for KMS automatic rotation (EnableKeyRotation)."
  type        = bool
  default     = true
}

variable "enable_same_account_read_only" {
  description = "If true, allows same-account read-only access (Describe/List/Get) to keys."
  type        = bool
  default     = false
}

# KMS keys definition
variable "keys" {
  description = "Map of KMS keys to create in this region (region comes from the AWS provider)."

  type = map(object({
    description = string

    # Presets: symmetric | asymmetric_sign | hmac | custom
    preset = optional(string, "symmetric")

    # Required when preset = custom
    key_usage = optional(string)
    key_spec  = optional(string)

    # Origin selector (module uses different resources based on this)
    # AWS_KMS      -> aws_kms_key (AWS generates key material)
    # EXTERNAL     -> aws_kms_external_key (imported key material)
    # AWS_CLOUDHSM -> aws_kms_key + custom_key_store_id
    origin              = optional(string, "AWS_KMS")
    custom_key_store_id = optional(string)

    # External key material (EXTERNAL only)
    # Base64 encoded 256-bit (32 bytes) symmetric key material.
    key_material_base64 = optional(string)

    # Lifecycle
    multi_region            = optional(bool, false)
    enable_key_rotation     = optional(bool, true)
    rotation_period_in_days = optional(number, 365)
    deletion_window_in_days = optional(number, 30)
    is_enabled              = optional(bool, true)

    # Aliases (WITHOUT alias/)
    primary_alias = string
    extra_aliases = optional(list(string), [])

    # Access model
    kms_key_administrators = optional(list(string), [])
    kms_key_users          = optional(list(string), [])

    # Service scoping (AWS service names, e.g. s3, ec2, logs, secretsmanager)
    allowed_via_services = optional(list(string), [])

    # Escape hatch
    policy_json = optional(string)

    # Per-key tags
    tags = optional(map(string), {})
  }))

  default = {}
}
