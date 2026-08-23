data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda_src.zip"
}

resource "aws_iam_role" "lambda" {
  name = "lambda-async-${local.nombre}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "sqs-consumo"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = [for q in aws_sqs_queue.this : q.arn]
    }, {
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = var.kms_key_arn
    }]
  })
}

resource "aws_lambda_function" "this" {
  for_each = var.colas

  function_name = "diplodevops-${local.nombre}-${each.key}"
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = each.value.lambda_timeout_seconds
  memory_size   = each.value.lambda_memory_mb

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      PAIS    = var.pais
      ENTORNO = var.entorno
    }
  }

  tags = { Pais = var.pais, Entorno = var.entorno, Cola = each.key }
}

resource "aws_lambda_event_source_mapping" "this" {
  for_each         = var.colas
  event_source_arn = aws_sqs_queue.this[each.key].arn
  function_name    = aws_lambda_function.this[each.key].arn
  batch_size       = 10
}
