variable "users" {
  type = map(
    object({
      username = optional(string)
      path     = optional(string, "/")
      tags     = optional(map(string), {})
    })
  )
  default = {}
}

variable "roles" {
  type = map(
    object({
      name = optional(string)
      path = optional(string, "/")
      assumers = object({
        iam_users = optional(list(object({
          arn = string
        })), [])
      })
      policies = optional(list(string), [])
      terraforming = optional(object({
        state_s3_bucket      = string
        state_dynamodb_table = string
        region               = string
        states               = list(string)
      }))
    })
  )
  default = {}
}
