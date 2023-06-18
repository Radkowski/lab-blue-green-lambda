terraform {
  required_providers {
    lambdabased = {
      source  = "SizZiKe/lambdabased"
      version = "0.1.2"
    }
  }
}

provider "lambdabased" {
  region = var.REGION
}
