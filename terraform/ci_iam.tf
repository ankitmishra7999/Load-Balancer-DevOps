# A dedicated IAM identity for GitHub Actions, scoped as narrowly as AWS
# permissions allow: it can only open/close port 22 on this one security
# group, nothing else. Deliberately separate from the terraform-deploy
# user - a leaked CI credential should not carry Terraform's broader
# permissions.
data "aws_iam_policy_document" "ci_sg_toggle" {
  statement {
    sid    = "ToggleSSHIngress"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [aws_security_group.app.arn]
  }

  statement {
    # EC2 Describe* actions don't support resource-level restrictions in
    # IAM - Resource has to be "*" here. This only grants read access to
    # security group metadata (used by CI to look up the SG's current ID,
    # which changes every time the SG is recreated), not to modify
    # anything.
    sid       = "DescribeForLookup"
    effect    = "Allow"
    actions   = ["ec2:DescribeSecurityGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_user" "ci" {
  name = "${var.project_name}-ci"
}

resource "aws_iam_user_policy" "ci_sg_toggle" {
  name   = "${var.project_name}-ci-sg-toggle"
  user   = aws_iam_user.ci.name
  policy = data.aws_iam_policy_document.ci_sg_toggle.json
}

resource "aws_iam_access_key" "ci" {
  user = aws_iam_user.ci.name
}

output "ci_aws_access_key_id" {
  description = "Add as the AWS_ACCESS_KEY_ID GitHub secret."
  value       = aws_iam_access_key.ci.id
}

output "ci_aws_secret_access_key" {
  description = "Add as the AWS_SECRET_ACCESS_KEY GitHub secret."
  value       = aws_iam_access_key.ci.secret
  sensitive   = true
}
