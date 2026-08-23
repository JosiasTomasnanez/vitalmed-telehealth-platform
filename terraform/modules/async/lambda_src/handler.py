def handler(event, context):
    """
    Placeholder — reemplazar con la lógica real de procesamiento.
    Recibe records de SQS (event["Records"]) y los procesa.
    """
    print(f"Procesando {len(event.get('Records', []))} mensajes")
    return {"statusCode": 200}
