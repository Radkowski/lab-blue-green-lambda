variable "DEPLOYMENTPREFIX" {}
variable "AUTHTAGS" {}
variable "REGION" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role" "codebuild-layer-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-codebuild-layer-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-codebuild-layer-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":log-group:/aws/codebuild/", var.DEPLOYMENTPREFIX, "-build-layer"]),
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":log-group:/aws/codebuild/", var.DEPLOYMENTPREFIX, "-build-layer:*"])
          ],
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
        },
        {
          "Effect" : "Allow",
          "Resource" : [
            join("", ["arn:aws:s3:::codepipeline-", data.aws_region.current.name, "-*"])
          ],
          "Action" : [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation"
          ]
        },
        {
          "Effect" : "Allow",
          "Resource" : [
            join("", ["arn:aws:lambda:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":layer:radlab-yaml"])
          ],
          "Action" : [
            "lambda:PublishLayerVersion",
          ]
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages"
          ],
          "Resource" : [
            join("", ["arn:aws:codebuild:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":report-group/", var.DEPLOYMENTPREFIX, "-build-layer-*"])
          ]
        }
      ]
    })
  }
}


resource "aws_iam_role" "lambda-exec-deploy-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-lambda-exec-role"])
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
    name = join("", [var.DEPLOYMENTPREFIX, "-lambda-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "log0",
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":*"])
        },
        {
          "Sid" : "log1",
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", "log-group:/aws/lambda/", var.DEPLOYMENTPREFIX, "-layer-build-trigger:*"])
          ]
        },
        {
          "Sid" : "runcodebuild",
          "Effect" : "Allow",
          "Action" : ["codebuild:StartBuild","codebuild:BatchGetBuilds"],
          "Resource" : join("", ["arn:aws:codebuild:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":project/", var.DEPLOYMENTPREFIX, "-build-layer"])
        }
      ]
    })
  }
}


resource "aws_codebuild_project" "layer-deployer" {
  name          = join("", [var.DEPLOYMENTPREFIX, "-build-layer"])
  description   = "CodeBuild to create lambda layer [RadkowskiLab]"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild-layer-role.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  source {
    type      = "NO_SOURCE"
    buildspec = <<STARTCODE
            version: 0.2      
            phases:
              install:
                  commands:
                    - yum -y install python3 zip unzip
                    - curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
                    - unzip -u awscliv2.zip
                    - ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
                    - aws --version

              build:
                  on-failure: ABORT 
                  commands:
                    - mkdir -p yaml-layer/python
                    - echo "pyyaml" > ./yaml-layer/requirements.txt
                    - pip3 install -r ./yaml-layer/requirements.txt -t ./yaml-layer/python
                    - cd yaml-layer
                    - zip -r ../yaml_layer.zip ./
                    - cd ..
                    - aws lambda publish-layer-version --layer-name radlab-yaml --zip-file fileb://yaml_layer.zip --compatible-architectures arm64 --compatible-runtimes python3.7 python3.8 python3.9
STARTCODE
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "public.ecr.aws/amazonlinux/amazonlinux:2.0.20230530.0-arm64v8"
    type         = "ARM_CONTAINER"
  }
  logs_config {
    cloudwatch_logs {
      group_name = join("", ["/aws/codebuild/", var.DEPLOYMENTPREFIX, "-build-layer"])
    }

  }
}


data "archive_file" "lambda-code" {
  type        = "zip"
  output_path = "lambda-code.zip"
  source {
    content  = <<EOF
import boto3
import logging
import os
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def check_loop(build_id):
    client_build = boto3.client('codebuild')
    logger.info ('Tracking build: '+str(build_id))
    while True:
        response1 = client_build.batch_get_builds(ids=[build_id])
        buildstatus = response1['builds'][0]['buildStatus']
        buildcomplete = response1['builds'][0]['buildComplete']
        if buildcomplete:
            logger.info ('FINALLY !!! Status/Cpmplete is: '+str(buildstatus)+'/'+str(buildcomplete))
            return 0
        logger.info ('Status/Complete is still: '+ str(buildstatus)+'/'+str(buildcomplete))
        time.sleep(5.0)
    return 1

def lambda_handler(event, context):
    client_build = boto3.client('codebuild')
    response = client_build.start_build(projectName=(os.environ.get('BUILD_LAMBDA_LAYER')))
    check_loop(response['build']['id'])
    return 0


EOF
    filename = "lambda_function.py"
  }
}


resource "aws_lambda_function" "lambda-codebuild-exec" {
  description      = "Deploy lambda layer using CodeBuild Project [RadkowskiLab]"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda-code.output_path
  source_code_hash = data.archive_file.lambda-code.output_base64sha256
  role             = aws_iam_role.lambda-exec-deploy-role.arn
  function_name    = join("", [var.DEPLOYMENTPREFIX, "-layer-build-trigger"])
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 90
  memory_size      = 128
  tags             = var.AUTHTAGS
  environment {
    variables = {
      BUILD_LAMBDA_LAYER = aws_codebuild_project.layer-deployer.name
    }
  }
}





resource "lambdabased_resource" "lambda_task" {
  function_name = aws_lambda_function.lambda-codebuild-exec.function_name
  triggers = {
    trigger_a = "a-trigger-value-24"
  }
  input = jsonencode({
    param = {
    }
  })
  conceal_input  = true
  conceal_result = true
  finalizer {
    function_name = aws_lambda_function.lambda-codebuild-exec.function_name
    input = jsonencode({
      param = {}
    })
  }
}
