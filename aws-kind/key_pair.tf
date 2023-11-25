resource "aws_key_pair" "kind" {
  key_name   = "kind-access-key"
  public_key = file("~/.ssh/id_rsa.pub")
}
