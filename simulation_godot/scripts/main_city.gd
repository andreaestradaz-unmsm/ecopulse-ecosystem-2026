extends Node3D

# Referencias a los nodos
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var visualizacion_satelital: Node2D = $VisualizacionSatelital

# URL del backend 
const BACKEND_URL : String = "http://127.0.0.1:8000/app/datos_ambientales" 
const LOGIN_URL : String = "http://127.0.0.1:8000/api/usuarios/login"

var auth_token : String = ""
var is_logging_in : bool = false

func _ready() -> void:
	print("¡Gemelo Digital inicializado con éxito!")
	http_request.request_completed.connect(_on_request_completed)
	iniciar_sesion()

func iniciar_sesion() -> void:
	print("Iniciating sesión de seguridad en el backend con credenciales...")
	is_logging_in = true
	# Mantenemos las credenciales obligatorias admin/admin de tu backend
	var body = "username=admin&password=admin"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var error = http_request.request(LOGIN_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Error al intentar enviar request de login.")

func realizar_peticion_backend() -> void:
	print("Solicitando datos en tiempo real al backend...")
	is_logging_in = false
	var headers = ["Authorization: Bearer " + auth_token]
	var error = http_request.request(BACKEND_URL, headers)
	if error != OK:
		print("Error al intentar iniciar la petición HTTP.")

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_logging_in:
		if response_code == 200:
			var json_texto = body.get_string_from_utf8()
			var json = JSON.parse_string(json_texto)
			if json and json.has("access_token"):
				auth_token = json["access_token"]
				print("Autorización Exitosa (Token obtenido). Solicitando métricas ambientales...")
				realizar_peticion_backend()
		else:
			print("Error crítico en login de seguridad. Código: ", response_code)
			await get_tree().create_timer(5.0).timeout
			iniciar_sesion()
	else:
		if response_code == 200:
			var json_texto = body.get_string_from_utf8()
			var json = JSON.parse_string(json_texto)
			
			if json:
				# 1. Mantenemos el control de la atmósfera 3D general (usando pm25 general o de una estación base)
				var pm25_general = json.get("pm25", 0.1)
				if world_environment and world_environment.environment:
					world_environment.environment.volumetric_fog_density = pm25_general / 1000.0
					world_environment.environment.volumetric_fog_albedo = Color(0.3, 0.3, 0.3) if pm25_general > 0.1 else Color(1, 1, 1)
				
				# 2. PROCESAMOS LAS 6 ESTACIONES DIRECTO AL MAPA 2D
				# Le enviamos el JSON completo recibido del backend al mapa satelital
				if visualizacion_satelital and visualizacion_satelital.has_method("actualizar_por_backend"):
					visualizacion_satelital.actualizar_por_backend(json)
					print("Datos de las 6 estaciones enviados al mapa 2D.")
		else:
			print("Error de conexión al backend. Código: ", response_code)
			if response_code == 401:
				print("Token de autorización expirado, renovando sesión...")
				iniciar_sesion()
				return
		
		# Consulta en bucle cada 5 segundos para actualización constante en la exposición
		await get_tree().create_timer(5.0).timeout
		realizar_peticion_backend()
