resource "aws_iam_user" "this" {
  for_each = var.users

  name = coalesce(each.value.name, each.key)
  path = each.value.path

  tags = each.value.tags
}
