# 1. Налаштування провайдера AWS
# Вказує Terraform, що ми працюємо з AWS та в якому регіоні.
provider "aws" {
  region = "eu-north-1"
}

# 2. Отримання даних про поточний акаунт, щоб не вказувати ID вручну
data "aws_caller_identity" "current" {}

# 3. Створення IAM політики "тільки для читання"
resource "aws_iam_policy" "read_only_policy" {
  name        = "LabReadOnlyPolicyTerraform"
  description = "A read-only policy for lab created with Terraform"

  # JSON-документ, що описує дозволи.
  # Дозволяє переглядати інформацію про EC2, S3 та IAM.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:Describe*",
          "s3:List*",
          "iam:ListUsers",
          "iam:ListRoles",
        ],
        Resource = "*"
      }
    ]
  })
}

# 4. Створення IAM ролі
resource "aws_iam_role" "read_only_role" {
  name = "LabReadOnlyRoleTerraform"

  # Політика довіри: вказує, ХТО може "приміряти" цю роль.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/readonly-user"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# 5. Прив'язка політики до ролі
# Поєднує створену політику (п.3) зі створеною роллю (п.4).
resource "aws_iam_role_policy_attachment" "attach_read_only_policy" {
  role       = aws_iam_role.read_only_role.name
  policy_arn = aws_iam_policy.read_only_policy.arn
}

# --------------------------------------------------------------------------------

# 6. Створення VPC
resource "aws_vpc" "lab_vpc_tf" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "lab-project-vpc-terraform"
  }
}

# 7. Створення Інтернет-шлюзу (IGW) для нового VPC
resource "aws_internet_gateway" "lab_igw_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id

  tags = {
    Name = "lab-project-igw-terraform"
  }
}

# 8. Створення ПУБЛІЧНОЇ підмережі в новому VPC
resource "aws_subnet" "public_subnet_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id
  cidr_block              = "10.1.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab-project-public-subnet-terraform"
  }
}

# 9. Створення ПРИВАТНОЇ підмережі в новому VPC
resource "aws_subnet" "private_subnet_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "lab-project-private-subnet-terraform"
  }
}

# 10. Створення таблиці маршрутизації для ПУБЛІЧНОЇ підмережі
resource "aws_route_table" "public_rt_tf" {
  vpc_id = aws_vpc.lab_vpc_tf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw_tf.id
  }

  tags = {
    Name = "lab-project-public-rt-terraform"
  }
}

# 11. Асоціація публічної таблиці маршрутизації до публічної підмережі
resource "aws_route_table_association" "public_assoc_tf" {
  subnet_id      = aws_subnet.public_subnet_tf.id
  route_table_id = aws_route_table.public_rt_tf.id
}
