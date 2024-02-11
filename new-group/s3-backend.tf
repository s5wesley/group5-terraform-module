
## Terraform block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  alias  = "state"
  region = var.aws_region_main
}

provider "aws" {
  alias  = "backup"
  region = var.aws_region_backup
}


## create IAM role with replication 

resource "aws_iam_role" "replication" {
  provider = "aws.state"
  name     = format("%s-%s-%s-s3-replication-role", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
  tags               = var.common_tags
}






resource "aws_iam_policy" "replication" {
  provider = "aws.state"
  name     = format("%s-%s-%s-s3-replication-policy", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.state.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.state.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.backup.arn}/*"
    }
  ]
}
POLICY
}



resource "aws_iam_policy_attachment" "replication" {
  provider   = "aws.state"
  name       = format("%s-%s-%s-s3-replication-policy-attachment", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])
  roles      = ["${aws_iam_role.replication.name}"]
  policy_arn = aws_iam_policy.replication.arn
}



resource "aws_s3_bucket" "state" {
  provider = "aws.state"
  bucket   = format("%s-%s-%s-tf-state", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])
  acl      = "private"
  versioning {
    enabled = true
  }

  replication_configuration {
    role = aws_iam_role.replication.arn

    rules {
      id     = "StateReplicationAll"
      prefix = ""
      status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.backup.arn
        storage_class = "STANDARD"
      }
    }
  }
  tags = var.common_tags
}

resource "aws_s3_bucket" "backup" {
  provider = "aws.backup"
  bucket   = format("%s-%s-%s-tf-state-backup", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])
  acl      = "private"
  versioning {
    enabled = true
  }
  tags = var.common_tags
}


resource "aws_dynamodb_table" "tf-state-lock" {
  provider       = "aws.state"
  name           = format("%s-%s-%s-tf-state-lock", var.common_tags["id"], var.common_tags["environment"], var.common_tags["project"])
  hash_key       = "LockID"
  read_capacity  = 20
  write_capacity = 20
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = var.common_tags
}



variable "aws_region_main" {
  type    = string
  default = "us-east-1"
}

variable "aws_region_backup" {
  type    = string
  default = "us-east-2"
}

variable "common_tags" {
  type = map(any)
default = {
  "id"             = "6000"
  "owner"          = "group-work"
  "teams"          = "team-work"
  "environment"    = "s5-team"
  "project"        = "s5-homework-group"
  "create_by"      = "s5-group-terraform"
  "cloud_provider" = "aws"
}
}
