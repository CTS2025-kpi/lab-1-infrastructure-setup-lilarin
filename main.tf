# 1. Налаштування провайдера AWS
# Вказує Terraform, що ми працюємо з AWS та в якому регіоні.
provider "aws" {
  region = "eu-north-1"
}

# 2. Отримання даних про поточний акаунт, щоб не вказувати ID вручну
data "aws_caller_identity" "current" {}

# 3. Створення IAM політики "тільки для читання"
resource "aws_iam_policy" "read_only_policy" {
  name = "LabReadOnlyPolicyTerraform"
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
