variable LAMBDA_DETAILS {}

data "aws_lambda_function" "existing" {
   function_name = var.LAMBDA_DETAILS.name
}



resource "aws_lambda_alias" "deployment-lambda-alias" {
  name             = join("", [var.LAMBDA_DETAILS.name, "-alias"])
  description      = "Lambda alias [RadkowskiLab]"
  function_name    = var.LAMBDA_DETAILS.arn
  function_version = data.aws_lambda_function.existing.version
}






