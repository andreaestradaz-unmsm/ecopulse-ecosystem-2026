# Controlador principal del Gemelo Digital 3D — orquesta la comunicación con el backend
extends Node3D

# Referencias a los nodos de la escena que este script controla
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var visualizacion_satelital: Node2D = $VisualizacionSatelital

# URLs del backend FastAPI
const BACKEND_URL : String = "http://127.0.0.1:8000/app/datos_ambientales"
const LOGIN_URL : String = "http://127.0.0.1:8000/api/usuarios/login"

var auth_token : String = ""     # Token JWT activo para autorizar las peticiones
var is_logging_in : bool = false # Indica si la petición HTTP en curso es un login


# Al iniciar la escena, conecta el callback de HTTP y arranca el flujo de autenticación
func _ready() -> void:
	print("¡Gemelo Digital inicializado con éxito!")
	http_request.request_completed.connect(_on_request_completed)
	iniciar_sesion()


# Envía las credenciales admin/admin al backend para obtener un JWT de acceso
func iniciar_sesion() -> void:
	print("Iniciating sesión de seguridad en el backend con credenciales...")
	is_logging_in = true
	var body = "username=admin&password=admin"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var error = http_request.request(LOGIN_URL, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("Error al intentar enviar request de login.")


# Solicita los datos ambientales al backend usando el JWT obtenido en el login
func realizar_peticion_backend() -> void:
	print("Solicitando datos en tiempo real al backend...")
	is_logging_in = false
	var headers = ["Authorization: Bearer " + auth_token]
	var error = http_request.request(BACKEND_URL, headers)
	if error != OK:
		print("Error al intentar iniciar la petición HTTP.")


# Callback que procesa todas las respuestas HTTP (tanto del login como de los datos)
func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_logging_in:
		# Respuesta del login: extrae el token JWT si fue exitoso
		if response_code == 200:
			var json_texto = body.get_string_from_utf8()
			var json = JSON.parse_string(json_texto)
			if json and json.has("access_token"):
				auth_token = json["access_token"]
				print("Autorización Exitosa (Token obtenido). Solicitando métricas ambientales...")
				realizar_peticion_backend()
		else:
			print("Error crítico en login de seguridad. Código: ", response_code)
			# Reintenta el login después de 5 segundos si falló
			await get_tree().create_timer(5.0).timeout
			iniciar_sesion()
	else:
		# Respuesta de datos ambientales: actualiza la escena con los nuevos valores
		if response_code == 200:
			var json_texto = body.get_string_from_utf8()
			var json = JSON.parse_string(json_texto)

			if json:
				# Ajusta la niebla volumétrica 3D según el PM2.5 global del sistema
				var pm25_general = json.get("pm25", 0.1)
				if world_environment and world_environment.environment:
					world_environment.environment.volumetric_fog_density = pm25_general / 1000.0
					# Niebla gris si hay contaminación, blanca si el aire está limpio
					world_environment.environment.volumetric_fog_albedo = Color(0.3, 0.3, 0.3) if pm25_general > 0.1 else Color(1, 1, 1)

				# Envía el JSON completo al mapa 2D para colorear las nubes de cada estación
				if visualizacion_satelital and visualizacion_satelital.has_method("actualizar_por_backend"):
					visualizacion_satelital.actualizar_por_backend(json)
					print("Datos de las 6 estaciones enviados al mapa 2D.")
		else:
			print("Error de conexión al backend. Código: ", response_code)
			if response_code == 401:
				# Token expirado: reinicia el flujo de autenticación
				print("Token de autorización expirado, renovando sesión...")
				iniciar_sesion()
				return

		# Repite la consulta cada 5 segundos para mantener la visualización actualizada
		await get_tree().create_timer(5.0).timeout
		realizar_peticion_backend()
