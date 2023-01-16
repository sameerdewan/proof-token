provider "aws" {
  region = "us-west-2"
}

resource "aws_kms_key" "dynamodb_key" {
  description = "Encryption key for DynamoDB table"
}

resource "aws_kms_key_alias" "dynamodb_alias" {
  name              = "alias/dynamodb_key"
  target_key_id = aws_kms_key.dynamodb_key.id
}

resource "aws_iam_role" "dynamodb_role" {
  name = "dynamodb_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "dynamodb.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "dynamodb_policy" {
  name = "dynamodb_policy"
  policy = <<EOF
{
resource "aws_iam_policy" "dynamodb_policy" {
  name = "dynamodb_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ],
      "Resource": "${aws_kms_key.dynamodb_key.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": "${aws_kms_key.dynamodb_key.arn}",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": true
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "dynamodb_attach" {
  role = aws_iam_role.dynamodb_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_dynamodb_table" "mint_jobs" {
  name           = "mint_jobs"
  hash_key       = "id"
  autoscaling {
    read_capacity {
      max_capacity = 100
      min_capacity = 10
    }
    write_capacity {
      max_capacity = 100
      min_capacity = 10
    }
  }
  server_side_encryption {
    kms_key_arn = aws_kms_key_alias.dynamodb_alias.arn
  }
}

resource "aws_dynamodb_table" "terraform_state" {
  name           = "terraform_state"
  hash_key       = "lock_id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "lock_id"
    type = "S"
  }
}

terraform {
  backend "dynamodb" {
    table_name = "terraform_state"
    region = "us-west-2"
    lock = true
    lock_table = "terraform_state_lock"
  }
}
