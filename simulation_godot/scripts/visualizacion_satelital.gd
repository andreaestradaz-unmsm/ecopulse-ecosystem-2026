extends Node2D

# Referencias exactas a tus 6 nubes (las declaramos sin asignar valor al inicio)
var nube_san_borja: Sprite2D
var nube_santa_anita: Sprite2D
var nube_san_juan: Sprite2D
var nube_san_martin: Sprite2D
var nube_pariachi: Sprite2D
var nube_campo_marte: Sprite2D

# Esta es la función que se ejecuta cuando el nodo ya está listo
func _ready() -> void:
	# Ahora sí, jalamos los nodos con total seguridad
	nube_san_borja = $NubeSanBorja
	nube_santa_anita = $NubeSantaAnita
	nube_san_juan = $NubeSanJuandeLurigancho
	nube_san_martin = $NubeSanMartin
	nube_pariachi = $NubePariachi
	nube_campo_marte = $NubeCampoDeMarte
	
	print("Nubes de la visualización satelital enlazadas correctamente.")

# Rangos de niveles de contaminación
enum NivelContaminacion { LIMPIO, INTERMEDIO, ALTO }

# Colores de nubes con opacidad para la ejemplificación en el mapa de Lima
const COLOR_VERDE_NUBE = Color(0.0, 1.0, 0.2, 0.4)    # Contaminación baja
const COLOR_NARANJA_NUBE = Color(1.0, 0.6, 0.0, 0.65)  # Contaminación moderada
const COLOR_ROJO_NUBE = Color(0.9, 0.0, 0.0, 0.75)     # Contaminación crítica

# Procesa el diccionario JSON crudo directo del Backend
func actualizar_por_backend(datos_json: Dictionary) -> void:
	# Intentamos jalar el valor global de pm25 enviado del backend por defecto
	var pm25_global = datos_json.get("pm25", 0.0)
	
	# Mapeamos los valores de las 6 estaciones desde el JSON.
	# Si tu backend envía claves individuales (ej: "pm25_san_borja"), las leerá directamente.
	# Si no existen, usará el pm25_global aplicando variaciones proporcionales para la simulación.
	var val_san_borja   = datos_json.get("pm25_3", pm25_global * 0.4) # Estacion SB (ID 3)
	var val_santa_anita = datos_json.get("pm25_4", pm25_global * 1.2) # ESA (ID 4)
	var val_san_juan    = datos_json.get("pm25_6", pm25_global * 1.6) # ESJL (ID 6)
	var val_san_martin  = datos_json.get("pm25_2", pm25_global * 0.9) # CDB/SMP (ID 2)
	var val_pariachi    = datos_json.get("pm25_5", pm25_global * 1.1) # EP (ID 5)
	var val_campo_marte = datos_json.get("pm25_1", pm25_global * 0.3) # Donofrio (ID 1)
	
	# Aplicamos los estados de color en base a los datos validados del backend
	_establecer_estado_nube(nube_san_borja, val_san_borja)
	_establecer_estado_nube(nube_santa_anita, val_santa_anita)
	_establecer_estado_nube(nube_san_juan, val_san_juan)
	_establecer_estado_nube(nube_san_martin, val_san_martin)
	_establecer_estado_nube(nube_pariachi, val_pariachi)
	_establecer_estado_nube(nube_campo_marte, val_campo_marte)

# Evalúa los límites ppm/ugm3 y pinta la nube correspondiente
func _establecer_estado_nube(nube: Sprite2D, valor_estacion: float) -> void:
	if not is_node_ready() or not nube:
		return
		
	var estado: NivelContaminacion
	if valor_estacion <= 12.0:
		estado = NivelContaminacion.LIMPIO
	elif valor_estacion > 12.0 and valor_estacion <= 35.0:
		estado = NivelContaminacion.INTERMEDIO
	else:
		estado = NivelContaminacion.ALTO
		
	match estado:
		NivelContaminacion.LIMPIO:
			nube.modulate = COLOR_VERDE_NUBE
		NivelContaminacion.INTERMEDIO:
			nube.modulate = COLOR_NARANJA_NUBE
		NivelContaminacion.ALTO:
			nube.modulate = COLOR_ROJO_NUBE
