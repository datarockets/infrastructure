locals {
  roles_that_terraform = {
    for key, role in var.roles:
      key => role.terraforming if role.terraforming != null
  }
}

resource "aws_iam_policy" "terraform" {
  for_each = local.roles_that_terraform

  name = "TerraformAs${aws_iam_role.this[each.key].name}"
  description = "Allows modifying terraform states"

  policy = data.aws_iam_policy_document.terraform[each.key].json
}

data "aws_iam_policy_document" "terraform" {
  for_each = local.roles_that_terraform

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]

    resources = [
      for state in each.value.states:
        "arn:aws:s3:::${each.value.state_s3_bucket}/${state}"
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${each.value.state_s3_bucket}",
      "arn:aws:s3:::${each.value.state_s3_bucket}/*"
    ]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]

    resources = [
      "arn:aws:dynamodb:${each.value.region}:${data.aws_caller_identity.current.account_id}:table/${each.value.state_dynamodb_table}"
    ]

    condition {
      test = "ForAllValues:StringEquals"
      variable = "dynamodb:LeadingKeys"
      values = flatten([
        for state in each.value.states: [
          "${each.value.state_s3_bucket}/${state}",
          "${each.value.state_s3_bucket}/${state}-md5"
        ]
      ])
    }
  }
}

resource "aws_iam_role_policy_attachment" "terraform" {
  for_each = local.roles_that_terraform

  role = aws_iam_role.this[each.key].name
  policy_arn = aws_iam_policy.terraform[each.key].arn
}
