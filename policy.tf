data "aws_iam_policy_document" "this" {
  for_each = local.resolved

  # 0) Always: root full control (prevents lockout)
  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }
  }

  # 1) Optional: same-account read-only (Describe/Get/List)
  dynamic "statement" {
    for_each = var.enable_same_account_read_only ? [1] : []
    content {
      sid       = "AllowSameAccountReadOnly"
      effect    = "Allow"
      actions   = ["kms:Describe*", "kms:Get*", "kms:List*"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }
    }
  }

  # 2) Optional: administrators (key management)
  dynamic "statement" {
    for_each = length(each.value.kms_key_administrators) > 0 ? [1] : []
    content {
      sid    = "AllowKeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
        "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
        "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
        "kms:ReplicateKey", "kms:UpdatePrimaryRegion"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.kms_key_administrators
      }
    }
  }

  # MODE A: AWS-style default (account-wide IAM permissions)
  # If NOT restricted, add a statement that enables IAM policies in this account to grant usage.
  dynamic "statement" {
    for_each = each.value.is_restricted ? [] : [1]
    content {
      sid    = "AllowAccountIAMPermissions"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }
    }
  }

  # MODE B1: Restricted to explicit IAM principals
  dynamic "statement" {
    for_each = length(each.value.kms_key_users) > 0 ? [1] : []
    content {
      sid    = "AllowExplicitKeyUsers"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.kms_key_users
      }
    }
  }

  # MODE B2: Restricted to AWS services via kms:ViaService allowlist
  dynamic "statement" {
    for_each = length(each.value.allowed_via_services) > 0 ? [1] : []
    content {
      sid    = "AllowUseViaAWSService"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]

      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values = [
          for s in each.value.allowed_via_services :
          "${s}.${local.region}.amazonaws.com"
        ]
      }
    }
  }

  # MODE B2 helper: allow grants for AWS resources (commonly required by services)
  dynamic "statement" {
    for_each = length(each.value.allowed_via_services) > 0 ? [1] : []
    content {
      sid    = "AllowGrantsForAWSResources"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
      resources = ["*"]

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }

      condition {
        test     = "StringEquals"
        variable = "kms:CallerAccount"
        values   = [local.account_id]
      }

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values = [
          for s in each.value.allowed_via_services :
          "${s}.${local.region}.amazonaws.com"
        ]
      }
    }
  }
}
