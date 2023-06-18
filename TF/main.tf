

module "LAYER-BUILDER" {
  source           = "./layer-builder"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  AUTHTAGS         = local.AUTHTAGS
  REGION           = local.REGION
}

module "LAMBDA-INIT" {
  source           = "./lambda-init"
  depends_on       = [module.LAYER-BUILDER]
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  AUTHTAGS         = local.AUTHTAGS
}

module "LAMBDA-ALIAS" {
  source         = "./lambda-alias"
  depends_on     = [module.LAMBDA-INIT]
  LAMBDA_DETAILS = module.LAMBDA-INIT.LAMBDA_DETAILS
}

module "INFRA" {
  depends_on       = [module.LAMBDA-ALIAS]
  source           = "./infra"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
}

module "CICD" {
  depends_on       = [module.INFRA]
  source           = "./cicd"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  S3_DETAILS       = module.INFRA.S3_DETAILS
  AUTHTAGS         = local.AUTHTAGS
  CODEPIPELINE     = local.CODEPIPELINE
  LAMBDA_DETAILS   = module.LAMBDA-INIT.LAMBDA_DETAILS
}

module "LAMBDA-URL" {
  source         = "./lambda-url"
  depends_on     = [module.CICD]
  LAMBDA_DETAILS = module.LAMBDA-INIT.LAMBDA_DETAILS
}


output "ALIAS_URL" {
  value = module.LAMBDA-URL.ALIAS_URL_DETAILS.function_url
}

