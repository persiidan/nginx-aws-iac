module "vpc" {
  source                           = "terraform-aws-modules/vpc/aws"
  name                             = "nginx-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = ["${var.region}a", "${var.region}b"]
  private_subnets                  = ["10.0.1.0/24"]
  public_subnets                   = ["10.0.2.0/24", "10.0.3.0/24"]
  manage_default_security_group    = false
  manage_default_network_acl       = false
  create_igw                       = true
  enable_nat_gateway               = true
  single_nat_gateway               = true
  one_nat_gateway_per_az           = false
  create_private_nat_gateway_route = true
}

locals {
  private_subnet_id  = module.vpc.private_subnets[0]
  public_subnet_1_id = module.vpc.public_subnets[0]
  public_subnet_2_id = module.vpc.public_subnets[1]
}

module "nginx" {
  source        = "./modules/Nginx"
  app_port      = var.app_port
  ec2_subnet_id = local.private_subnet_id
  vpc_id        = module.vpc.vpc_id
  alb_sg_id     = module.load_balancer.alb_sg_id
  vpc_cidr      = module.vpc.vpc_cidr_block
  key_name      = "terra_key"
}

module "load_balancer" {
  source      = "./modules/load_balancer"
  vpc_id      = module.vpc.vpc_id
  ec2_id      = module.nginx.instance_id
  pub_subnet1 = local.public_subnet_1_id
  pub_subnet2 = local.public_subnet_2_id
}
