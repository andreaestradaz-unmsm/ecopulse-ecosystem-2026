extends Node3D

# Referencias a los nodos
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var http_request: HTTPRequest = $HTTPRequest

# URL del backend 
const BACKEND_URL : String = "http://127.0.0.1:8000/app/datos_ambientales" 

func _ready() -> void:
	print("¡Gemelo Digital inicializado con éxito!")
	http_request.request_completed.connect(_on_request_completed)
	actualizar_contaminacion(0.25, Color(1, 1, 1)) 
	realizar_peticion_backend()

func realizar_peticion_backend() -> void:
	print("Solicitando datos al backend...")
	var error = http_request.request(BACKEND_URL)
	if error != OK:
		print("Error al intentar iniciar la petición HTTP.")

# Dividimos los argumentos en líneas para evitar cortes y limpiar warnings de variables no usadas
func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json_texto = body.get_string_from_utf8()
		var json = JSON.parse_string(json_texto)
		
		if json and json.has("pm25"):
			var nivel_pm25 = json["pm25"]
			var color_clima = Color(0.3, 0.3, 0.3) if nivel_pm25 > 0.1 else Color(1, 1, 1)
			actualizar_contaminacion(nivel_pm25, color_clima)
	else:
		print("No se pudo conectar al backend. Código de respuesta: ", response_code)

func actualizar_contaminacion(nivel_pm25: float, color_humo: Color) -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.volumetric_fog_density = nivel_pm25
		world_environment.environment.volumetric_fog_albedo = color_humo
		print("Atmósfera sincronizada con el Backend. Densidad: ", nivel_pm25)
