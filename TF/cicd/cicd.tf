data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_lambda_layer_version" "check_latest_layer" {
  layer_name = "radlab-yaml"
}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

variable "DEPLOYMENTPREFIX" {}
variable "S3_DETAILS" {}
variable "AUTHTAGS" {}
variable "CODEPIPELINE" {}
variable LAMBDA_DETAILS {}

resource "aws_iam_role" "event-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-eventbridge-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-event-policy"])
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "codepipeline:StartPipelineExecution"
          ],
          "Resource" : [aws_codepipeline.bg-pipeline.arn]
        }
      ]
    })
  }
}


resource "aws_iam_role" "lambda-deploy-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-lambda-deploy-role"])
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
    name = join("", [var.DEPLOYMENTPREFIX, "-lambda-deploy-policy"])

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
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", "log-group:/aws/lambda/", var.DEPLOYMENTPREFIX, "-lambda-deploy:*"])
          ]
        },
        {
          "Sid" : "codepipeline",
          "Effect" : "Allow",
          "Action" : [
            "codepipeline:StopPipelineExecution",
            "codepipeline:PutJobSuccessResult",
            "codepipeline:GetPipelineState"
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "s3",
          "Effect" : "Allow",
          "Action" : [
            "s3:PutObject",
            "s3:GetObject"
          ],
          "Resource" : "arn:aws:s3:::*/*"
        },
        {
          "Sid" : "lambda",
          "Effect" : "Allow",
          "Action" : [
            "lambda:GetFunction",
            "lambda:PublishVersion",
            "lambda:GetFunctionConfiguration",
            "lambda:UpdateFunctionCode",
          ],
          "Resource" : "*"
        },
        {
          "Sid" : "s3objlambda",
          "Effect" : "Allow",
          "Action" : "s3-object-lambda:*",
          "Resource" : "*"
        }
      ]
    })
  }
}



resource "aws_iam_role" "codebuild-transform-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-codebuild-transform-role"])
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
    name = join("", [var.DEPLOYMENTPREFIX, "-codebuild-transform-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":log-group:/aws/codebuild/", var.DEPLOYMENTPREFIX, "-transform"]),
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":log-group:/aws/codebuild/", var.DEPLOYMENTPREFIX, "-transform:*"])
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
          "Action" : [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages"
          ],
          "Resource" : [
            join("", ["arn:aws:codebuild:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":report-group/", var.DEPLOYMENTPREFIX, "-transform-*"])
          ]
        }
      ]
    })
  }
}


resource "aws_iam_role" "codedeploy-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-codedeploy-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"]
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-codedeploy-inline-policy"])
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "s3",
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject*"
          ],
          "Resource" : "arn:aws:s3:::*/*"
        }
      ]
    })
  }
}

resource "aws_iam_role" "codepipeline-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-codepipeline-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-codepipeline-inline-policy"])
    policy = jsonencode({
      "Statement" : [
        {
          "Action" : [
            "iam:PassRole"
          ],
          "Resource" : "*",
          "Effect" : "Allow",
          "Condition" : {
            "StringEqualsIfExists" : {
              "iam:PassedToService" : [
                "cloudformation.amazonaws.com",
                "elasticbeanstalk.amazonaws.com",
                "ec2.amazonaws.com",
                "ecs-tasks.amazonaws.com"
              ]
            }
          }
        },
        {
          "Action" : [
            "codecommit:CancelUploadArchive",
            "codecommit:GetBranch",
            "codecommit:GetCommit",
            "codecommit:GetRepository",
            "codecommit:GetUploadArchiveStatus",
            "codecommit:UploadArchive"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codedeploy:CreateDeployment",
            "codedeploy:GetApplication",
            "codedeploy:GetApplicationRevision",
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig",
            "codedeploy:RegisterApplicationRevision"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codestar-connections:UseConnection"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "elasticbeanstalk:*",
            "ec2:*",
            "elasticloadbalancing:*",
            "autoscaling:*",
            "cloudwatch:*",
            "s3:*",
            "sns:*",
            "cloudformation:*",
            "rds:*",
            "sqs:*",
            "ecs:*",
            "ecr:*"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "lambda:InvokeFunction",
            "lambda:ListFunctions"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "opsworks:CreateDeployment",
            "opsworks:DescribeApps",
            "opsworks:DescribeCommands",
            "opsworks:DescribeDeployments",
            "opsworks:DescribeInstances",
            "opsworks:DescribeStacks",
            "opsworks:UpdateApp",
            "opsworks:UpdateStack"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "cloudformation:CreateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:UpdateStack",
            "cloudformation:CreateChangeSet",
            "cloudformation:DeleteChangeSet",
            "cloudformation:DescribeChangeSet",
            "cloudformation:ExecuteChangeSet",
            "cloudformation:SetStackPolicy",
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "codebuild:BatchGetBuildBatches",
            "codebuild:StartBuildBatch"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "devicefarm:ListProjects",
            "devicefarm:ListDevicePools",
            "devicefarm:GetRun",
            "devicefarm:GetUpload",
            "devicefarm:CreateUpload",
            "devicefarm:ScheduleRun"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "servicecatalog:ListProvisioningArtifacts",
            "servicecatalog:CreateProvisioningArtifact",
            "servicecatalog:DescribeProvisioningArtifact",
            "servicecatalog:DeleteProvisioningArtifact",
            "servicecatalog:UpdateProduct"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:DescribeImages"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "states:DescribeExecution",
            "states:DescribeStateMachine",
            "states:StartExecution"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "appconfig:StartDeployment",
            "appconfig:StopDeployment",
            "appconfig:GetDeployment"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:GetPublicKey",
            "kms:DescribeKey"
          ],
          "Resource" : data.aws_kms_alias.s3.target_key_arn
        }
      ],
      "Version" : "2012-10-17"
      }
    )
  }
}




data "archive_file" "lambda-deploy-code" {
  type        = "zip"
  output_path = "lambda-deploy-code.zip"
  source {
    content  = <<EOF
import boto3
import pprint
import json
import yaml
import os
import logging
import zipfile



logger = logging.getLogger()
logger.setLevel(logging.INFO)



def publish_lambda_waiter(lambda_arn):
    client_lambda = boto3.client('lambda')
    waiter = client_lambda.get_waiter('function_updated')
    waiter.wait(
        FunctionName=lambda_arn,
        WaiterConfig={'Delay': 2,'MaxAttempts': 30}
    )
    return 0


def publish_lambda(lambda_arn, s3_name, s3_key):
    client_lambda = boto3.client('lambda')
    publish_lambda_waiter(lambda_arn)
    response = client_lambda.update_function_code(
        FunctionName=lambda_arn,
        S3Bucket=s3_name,S3Key=s3_key,
        Publish=True,Architectures=['arm64']
        )
    lambda_new_version = response['FunctionArn']
    return lambda_new_version.split(':')[7]


def swap_arn_with_name(lambda_arn):
    client_lambda = boto3.client('lambda')
    response = client_lambda.get_function(FunctionName=lambda_arn)
    return (response['Configuration']['FunctionName'])


def return_latest_version(lambda_arn):
        client_lambda = boto3.client('lambda')
        function_name = swap_arn_with_name(lambda_arn)
        response = client_lambda.get_function(
            FunctionName=function_name,
            Qualifier= (function_name + '-alias')
            )
        return (response['Configuration']['Version'])


def upload_file(s3_details,s3_credentials,properties):       
        session = boto3.session.Session(
            aws_access_key_id=s3_credentials['accessKeyId'],
            aws_secret_access_key=s3_credentials['secretAccessKey'],
            aws_session_token=s3_credentials['sessionToken']
        )
        content = """
        version: 0.0
        Resources:
        - RadLabLambdaFunction:
            Type: AWS::Lambda::Function
            Properties:
                Name: "%s"
                Alias: "%s"
                CurrentVersion: "%s"
                TargetVersion: "%s"
        """ % (properties['Name'],properties['Alias'],properties['CurrentVersion'],properties['TargetVersion'])
        yaml_content = yaml.safe_load(content)
        os.chdir ('/tmp')
        with open('./appspec.yaml', 'w') as file:
            yaml.dump(yaml_content, file)

        with zipfile.ZipFile('./output.zip', 'w') as zip:
                zip.write("./appspec.yaml")
        client = boto3.client('s3')
        transfer = boto3.s3.transfer.S3Transfer(client=client)
        transfer.upload_file('./output.zip',
                            s3_details['bucketName'], 
                            s3_details['objectKey'],
                            extra_args={'ServerSideEncryption':'aws:kms'}
        )
        return 0


def put_job_success(job):
    client_code_pipeline = boto3.client('codepipeline')
    print('Putting job ',job,' success')
    client_code_pipeline.put_job_success_result(jobId=job)
    return 0


def stop_pipeline(name):
    client_code_pipeline = boto3.client('codepipeline')
    response = client_code_pipeline.get_pipeline_state(name=name)
    exec_id = (response['stageStates'][0]['latestExecution']['pipelineExecutionId'])
    response2 = client_code_pipeline.stop_pipeline_execution(
        pipelineName=name,
        pipelineExecutionId=exec_id,
        abandon=False,
        reason='The same lambdas'
    )
    return 0



def lambda_handler(event, context):

    # DeploymentPrefix = 'bglambda'
    # s3_bucket_name = 'blue-green-lambda'
    # s3_bucket_key = 'lambda-code/lambda.zip'
    # lambda_arn = 'arn:aws:lambda:eu-central-1:316795178806:function:RadLab-lambda'
    # pipeline_name = 'radlab-test'
    
    s3_bucket_name = os.environ['s3_bucket_name']
    s3_bucket_key = os.environ['s3_bucket_key']
    lambda_arn = os.environ['lambda_arn']
    pipeline_name = os.environ['pipeline_name']


    alias_current_v = return_latest_version(lambda_arn)
    alias_new_v = publish_lambda(lambda_arn, s3_bucket_name, s3_bucket_key)

    if  alias_current_v == alias_new_v:
        stop_pipeline(pipeline_name)
        logger.info ('Both versions are the same - next time Use the Force, Luke ')
        put_job_success(event['CodePipeline.job']['id'])
    else:   
        logger.info ('The Force Is with You, Luke. Replacing '+ alias_current_v +' with '+ alias_new_v)
        function_name = swap_arn_with_name(lambda_arn)
        properties = {
                        "Name" : function_name,
                        "Alias" : function_name + '-alias',
                        "CurrentVersion" : alias_current_v,
                        "TargetVersion" : alias_new_v
        }
        upload_file(
            event['CodePipeline.job']['data']['outputArtifacts'][0]['location']['s3Location'],
            event['CodePipeline.job']['data']['artifactCredentials'],
            properties = {
                "Name" : function_name,
                "Alias" : function_name + '-alias',
                "CurrentVersion" : alias_current_v,
                "TargetVersion" : alias_new_v
                        }
        )
        logger.info ('Appspec successfully sent to CodeBuild')

    put_job_success(event['CodePipeline.job']['id'])
    return 0

EOF
    filename = "lambda_function.py"
  }
}



resource "aws_lambda_function" "lambda-deploy" {
  description      = "Publish new version and create AppSpec file [RadkowskiLab]"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda-deploy-code.output_path
  source_code_hash = data.archive_file.lambda-deploy-code.output_base64sha256
  role             = aws_iam_role.lambda-deploy-role.arn
  function_name    = join("", [var.DEPLOYMENTPREFIX, "-lambda-deploy"])
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  tags             = var.AUTHTAGS
  layers           = [data.aws_lambda_layer_version.check_latest_layer.arn]
    environment {
      variables = {
        s3_bucket_name = var.S3_DETAILS.bucket
        s3_bucket_key = "lambda-code/lambda.zip"
        lambda_arn = var.LAMBDA_DETAILS.arn
        pipeline_name = join("", [var.DEPLOYMENTPREFIX, "-pipeline"])

      }
  }
}




resource "aws_codebuild_project" "transform" {
  name          = join("", [var.DEPLOYMENTPREFIX, "-transform"])
  description   = "CodeBuild to transform zip into appspec file [RadkowskiLab]"
  build_timeout = "60"
  service_role  = aws_iam_role.codebuild-transform-role.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  source {
    type      = "NO_SOURCE"
    buildspec = <<STARTCODE
          version: 0.2
          phases:
            build:
              commands:
                - ls -la
                - cat appspec.yaml
          artifacts:
            files:
              - 'appspec.yaml'
            name: CBOut
STARTCODE
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "public.ecr.aws/amazonlinux/amazonlinux:2.0.20230530.0-arm64v8"
    type         = "ARM_CONTAINER"
  }
  logs_config {
    cloudwatch_logs {
      group_name = join("", ["/aws/codebuild/", var.DEPLOYMENTPREFIX, "-transform"])
    }

  }
}




resource "aws_codedeploy_app" "cdp-app" {
  compute_platform = "Lambda"
  name             = join("", [var.DEPLOYMENTPREFIX, "-app"])
}


resource "aws_codedeploy_deployment_config" "custom-deployment-config" {
  deployment_config_name = join("", [var.DEPLOYMENTPREFIX, "-deployment-config"])
  compute_platform       = "Lambda"
  traffic_routing_config {
    type = "TimeBasedCanary"
    time_based_canary {
      interval   = 2
      percentage = 25
    }
  }
}

resource "aws_codedeploy_deployment_group" "cd_deployment_group" {
  app_name               = aws_codedeploy_app.cdp-app.name
  deployment_config_name = aws_codedeploy_deployment_config.custom-deployment-config.id
  deployment_group_name  = join("", [var.DEPLOYMENTPREFIX, "-deployment-grp"])
  service_role_arn       = aws_iam_role.codedeploy-role.arn
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
}


resource "aws_codepipeline" "bg-pipeline" {
  name     = join("", [var.DEPLOYMENTPREFIX, "-pipeline"])
  role_arn = aws_iam_role.codepipeline-role.arn
  artifact_store {
    location = var.CODEPIPELINE.DefaultLocation
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Read_source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        S3Bucket             = var.S3_DETAILS.bucket
        S3ObjectKey          = "lambda-code/lambda.zip"
        PollForSourceChanges = false
      }
    }
  }
  stage {
    name = "Lambda-predeploy"
    action {
      name             = "Publish_and_create"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "Lambda"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["AppSpec"]
      configuration = {
        FunctionName = aws_lambda_function.lambda-deploy.function_name
      }
    }
  }
  stage {
    name = "Transform"
    action {
      name             = "Transfort_artifact"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["AppSpec"]
      output_artifacts = ["CBOut"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.transform.name

      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Deploy_lambda"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["CBOut"]
      version         = "1"
      configuration = {
        ApplicationName     = aws_codedeploy_app.cdp-app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.cd_deployment_group.deployment_group_name
      }
    }
  }
}


resource "aws_cloudwatch_event_rule" "start-pipeline-after-s3-push" {
  name        = join("", [var.DEPLOYMENTPREFIX, "-rule"])
  description = "Starts pipeline once lambda zip is pushed into s3"
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["AWS API Call via CloudTrail"],
    "detail": {
      "eventSource": ["s3.amazonaws.com"],
      "eventName": ["PutObject", "CompleteMultipartUpload", "CopyObject"],
      "requestParameters": {
        "bucketName": [var.S3_DETAILS.bucket],
        "key": ["lambda-code/lambda.zip"]
      }
  }})
}


resource "aws_cloudwatch_event_target" "codepipeline" {
  rule      = aws_cloudwatch_event_rule.start-pipeline-after-s3-push.name
  target_id = join("", [var.DEPLOYMENTPREFIX, "-triggerCP"])
  arn       = aws_codepipeline.bg-pipeline.arn
  role_arn  = aws_iam_role.event-role.arn
}


