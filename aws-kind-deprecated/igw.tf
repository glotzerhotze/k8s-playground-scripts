resource "aws_internet_gateway" "kind" {
  vpc_id = aws_default_vpc.kind.id
}