
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "DEPLOYMENTPREFIX" {}
variable "AUTHTAGS" {}

resource "aws_iam_role" "deployment-lambda-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-deployment-lambda-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-deployment-lambda-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":*"])
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", "log-group:/aws/lambda/", var.DEPLOYMENTPREFIX, "-deployment-lambda:*"])
          ]
        }
      ]
    })
  }
}




data "archive_file" "deployment-lambda-code" {
  type        = "zip"
  output_path = "deployment-lambda-code.zip"
  source {
    content  = <<EOF
import json
def lambda_handler(event, context):
    return ('Hello from version 1 - it is time to update it !!!')

EOF
    filename = "lambda_function.py"
  }
}


resource "aws_lambda_function" "deployment-lambda" {
  description      = "Lambda function - B/G deployment [RadkowskiLab]"
  architectures    = ["arm64"]
  filename         = data.archive_file.deployment-lambda-code.output_path
  source_code_hash = data.archive_file.deployment-lambda-code.output_base64sha256
  role             = aws_iam_role.deployment-lambda-role.arn
  function_name    = join("", [var.DEPLOYMENTPREFIX, "-deployment-lambda"])
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 15
  memory_size      = 128
  publish          = true
  tags             = var.AUTHTAGS
}



output "LAMBDA_DETAILS" {
  value = { 
    "arn" : aws_lambda_function.deployment-lambda.arn
    "name" :  aws_lambda_function.deployment-lambda.function_name
  }
}

