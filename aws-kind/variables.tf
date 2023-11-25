variable "region" {
  type = string
  default = "eu-central-1"
  #default = "us-east-1"
}

variable "ami" {
  type = string
  default = "ami-0c9354388bb36c088"
  #default = "ami-0a5f04cdf7758e9f0"
}

variable "instance_type" {
  type = string
  default = "t3.xlarge"
}
