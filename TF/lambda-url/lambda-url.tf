variable LAMBDA_DETAILS {
    
}
resource "aws_lambda_function_url" "alias_url" {
  function_name      = var.LAMBDA_DETAILS.name
  qualifier          = join("", [var.LAMBDA_DETAILS.name, "-alias"])
  authorization_type = "NONE"
}


output "ALIAS_URL_DETAILS" {
  value = aws_lambda_function_url.alias_url
}