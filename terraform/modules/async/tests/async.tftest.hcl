# =============================================================================
# Tests: Módulo Async — SQS + Lambda
# Ejecución: ./scripts/run-tests-localstack.sh
# =============================================================================

variables {
  pais        = "ar"
  entorno     = "prod"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/test"

  colas = {
    procesamiento_recetas = {
      visibility_timeout_seconds = 60
      lambda_timeout_seconds     = 30
      lambda_memory_mb           = 256
    }
    notificaciones = {
      visibility_timeout_seconds = 30
      lambda_timeout_seconds     = 15
      lambda_memory_mb           = 128
    }
  }
}

# -----------------------------------------------------------------------------
# Test 1: Se crean 2 colas SQS
# -----------------------------------------------------------------------------
run "sqs_queues_count" {
  command = plan

  assert {
    condition     = length(aws_sqs_queue.this) == 2
    error_message = "Deben existir 2 colas SQS"
  }
}

# -----------------------------------------------------------------------------
# Test 2: Las colas SQS tienen cifrado con KMS
# -----------------------------------------------------------------------------
run "sqs_queues_encrypted" {
  command = plan

  assert {
    condition     = alltrue([for q in aws_sqs_queue.this : q.kms_master_key_id != null])
    error_message = "Las colas SQS deben estar cifradas con KMS"
  }
}

# -----------------------------------------------------------------------------
# Test 3: Se crean 2 Lambdas (una por cola)
# -----------------------------------------------------------------------------
run "lambda_functions_count" {
  command = plan

  assert {
    condition     = length(aws_lambda_function.this) == 2
    error_message = "Deben existir 2 funciones Lambda (una por cola)"
  }
}

# -----------------------------------------------------------------------------
# Test 4: Las Lambdas tienen tiempo de ejecución configurable
# -----------------------------------------------------------------------------
run "lambda_timeout_configurable" {
  command = plan

  assert {
    condition     = aws_lambda_function.this["procesamiento_recetas"].timeout == 30
    error_message = "Lambda de procesamiento_recetas debe tener timeout de 30 segundos"
  }

  assert {
    condition     = aws_lambda_function.this["notificaciones"].timeout == 15
    error_message = "Lambda de notificaciones debe tener timeout de 15 segundos"
  }
}

# -----------------------------------------------------------------------------
# Test 5: Las Lambdas tienen memoria configurable
# -----------------------------------------------------------------------------
run "lambda_memory_configurable" {
  command = plan

  assert {
    condition     = aws_lambda_function.this["procesamiento_recetas"].memory_size == 256
    error_message = "Lambda de procesamiento_recetas debe tener 256 MB de memoria"
  }

  assert {
    condition     = aws_lambda_function.this["notificaciones"].memory_size == 128
    error_message = "Lambda de notificaciones debe tener 128 MB de memoria"
  }
}

# -----------------------------------------------------------------------------
# Test 6: Las Lambdas tienen permisos para recibir de SQS
# -----------------------------------------------------------------------------
run "lambda_sqs_permissions" {
  command = plan

  assert {
    condition     = length(aws_lambda_event_source_mapping.this) == 2
    error_message = "Cada Lambda debe tener un event source mapping de SQS"
  }
}
