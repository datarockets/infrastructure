output "roles" {
  value = {
    for key, role in var.roles:
      key => {
        name = aws_iam_role.this[key].name
        arn = aws_iam_role.this[key].arn
      }
  }
}
