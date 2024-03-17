resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  tags = merge(var.tags, { Name = "${var.env}-vpc" })
}

module "subnets" {
  source = "./subnets"
  for_each = var.subnets
  vpc_id = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]
  tags = var.tags
  env = var.env
  name = each.value["name"]
  azs = each.value["azs"]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.env}-igw" })
}

resource "aws_eip" "ngw" {
  count = length(var.subnets["pubilc"].cidr_block)
  domain   = "vpc"
  tags = merge(var.tags, { Name = "${var.env}-ngw" })
}

resource "aws_nat_gateway" "ngw" {
  count = length(var.subnets["pubilc"].cidr_block)
  allocation_id = aws_eip.ngw[count.index].id
  subnet_id     = module.subnets["pubilc"].subnet_ids[count.index]

  tags = merge(var.tags, { Name = "${var.env}-ngw" })
}

resource "aws_route" "igw" {
  count = length(module.subnets["pubilc"].route_table_ids)
  route_table_id = module.subnets["pubilc"].route_table_ids[count.index]
  gateway_id = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "ngw" {
  count = length(local.all_private_subnet_ids)
  route_table_id = local.all_private_subnet_ids[count.index]
  nat_gateway_id = element(aws_nat_gateway.ngw[count.index].id)
  destination_cidr_block = "0.0.0.0/0"
}

output "nat" {
  value = aws_nat_gateway.ngw
}

output "subnet" {
  value = module.subnets
}