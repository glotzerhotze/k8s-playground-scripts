resource "aws_default_subnet" "kind" {
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
}
