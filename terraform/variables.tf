variable "ecs_cluster_name" {
  default = "loc-ecs-cluster"
}

#application load balancer
variable "alb_name" {
  default = "loc-alb"
}

variable "execution_role_arn" {
  default = "arn:aws:iam::054037109154:role/ecsTaskExecutionRole"
}

variable "og_vpc_id" {
  default = "vpc-07c18ba2d9821b698"
}

variable "igw_id" {
  default = "igw-0e85d67dbe2658e2f"
}
