resource "aws_iam_policy" "manage_own_credentials" {
  name = "ManageOwnCredentials"
  description = "Allows changing own password, MFA devices, access keys, etc"
  policy = data.aws_iam_policy_document.manage_own_credentials.json
}

data "aws_iam_policy_document" "manage_own_credentials" {
  statement {
    sid = "AllowIndividualUserToSeeAndManageTheirOwnAccountInformation"
    actions = [
      "iam:ChangePassword",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:DeleteAccessKey",
      "iam:DeleteLoginProfile",
      "iam:GetAccountPasswordPolicy",
      "iam:GetLoginProfile",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
      "iam:UpdateLoginProfile",
      "iam:ListSigningCertificates",
      "iam:DeleteSigningCertificate",
      "iam:UpdateSigningCertificate",
      "iam:UploadSigningCertificate",
      "iam:ListSSHPublicKeys",
      "iam:GetSSHPublicKey",
      "iam:DeleteSSHPublicKey",
      "iam:UpdateSSHPublicKey",
      "iam:UploadSSHPublicKey",
      "iam:GetUser",
      "iam:GetAccessKeyLastUsed",
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }
  statement {
    sid = "AllowIndividualUserToManageTheirOwnMFA"
    actions = [
      "iam:ListVirtualMFADevices",
      "iam:ListMFADevices",
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice"
    ]
    resources = [
      "arn:aws:iam::*:mfa/$${aws:username}*",
      "arn:aws:iam::*:user/$${aws:username}"
    ]
  }
}
