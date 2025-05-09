resource "aws_iam_role" "this" {
  for_each = var.roles

  name = title(coalesce(each.value.name, each.key))
  path = each.value.path

  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[each.key].json
}

data "aws_iam_policy_document" "assume_role_policy" {
  for_each = var.roles

  dynamic "statement" {
    for_each = length(each.value.assumers.iam_users) > 0 ? {
      iam_users = each.value.assumers.iam_users
    } : {}

    content {
      actions = [
        "sts:AssumeRole",
      ]

      principals {
        type        = "AWS"
        identifiers = [for assumer in statement.value : assumer.arn]
      }
    }
  }
}

locals {
  role_policy_attachments = flatten(values({
    for key, role in var.roles : key => [
      for policy in role.policies : {
        role_key   = key
        policy_arn = policy
        name       = "${key}-${regex(".*/([^/]+)$", policy)[0]}"
      }
    ]
  }))
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    for attachment in local.role_policy_attachments :
    attachment.name => attachment
  }

  role       = aws_iam_role.this[each.value.role_key].name
  policy_arn = each.value.policy_arn
}
