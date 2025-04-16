data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    visibility = "public"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    visibility = "private"
  }
}

data "aws_subnets" "runner" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    visibility = "private"
    domain     = "runner"
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.key
}


data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.key
}

data "aws_subnet" "runner" {
  for_each = toset(data.aws_subnets.runner.ids)
  id       = each.key
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnets = {
    private = {
      ids   = setsubtract(data.aws_subnets.private.ids, data.aws_subnets.runner.ids),
      cidrs = setsubtract(values(data.aws_subnet.private)[*].cidr_block, values(data.aws_subnet.runner)[*].cidr_block),
    }
    public = {
      ids   = data.aws_subnets.public.ids,
      cidrs = values(data.aws_subnet.public)[*].cidr_block,
    }
    runner = {
      ids   = data.aws_subnets.runner.ids
      cidrs = values(data.aws_subnet.runner)[*].cidr_block
    }
  }
}
