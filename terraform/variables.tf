variable "region" {
  default = "eu-west-3"
}

variable "ssh_key_name" {
  description = "Nom de la clé SSH pour accéder aux nodes"
  default     = "ec2-chrisley75-sshkey-c6r"
}
