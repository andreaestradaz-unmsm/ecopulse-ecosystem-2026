# Visualización 2D satelital de Lima — gestiona los sprites de nube sobre el mapa
extends Node2D

# Referencias a los sprites de nube de cada estación de monitoreo
var nube_san_borja: Sprite2D
var nube_santa_anita: Sprite2D
var nube_san_juan: Sprite2D
var nube_san_martin: Sprite2D
var nube_pariachi: Sprite2D
var nube_campo_marte: Sprite2D


# Inicializa las referencias a cada nube una vez que el nodo está listo en la escena
func _ready() -> void:
	nube_san_borja = $NubeSanBorja
	nube_santa_anita = $NubeSantaAnita
	nube_san_juan = $NubeSanJuandeLurigancho
	nube_san_martin = $NubeSanMartin
	nube_pariachi = $NubePariachi
	nube_campo_marte = $NubeCampoDeMarte

	print("Nubes de la visualización satelital enlazadas correctamente.")


# Enum para representar los tres niveles posibles de contaminación
enum NivelContaminacion { LIMPIO, INTERMEDIO, ALTO }

# Colores con opacidad para pintar las nubes según el nivel de contaminación
const COLOR_VERDE_NUBE = Color(0.0, 1.0, 0.2, 0.4)    # PM2.5 ≤ 12 µg/m³ — saludable
const COLOR_NARANJA_NUBE = Color(1.0, 0.6, 0.0, 0.65)  # PM2.5 12-35 µg/m³ — moderado
const COLOR_ROJO_NUBE = Color(0.9, 0.0, 0.0, 0.75)     # PM2.5 > 35 µg/m³ — crítico


# Recibe el JSON del backend y colorea cada nube según el PM2.5 de su estación
func actualizar_por_backend(datos_json: Dictionary) -> void:
	# Primero resetea todas las nubes a blanco (estado "sin datos")
	_resetear_todas_nubes()

	if datos_json.has("estaciones"):
		var estaciones_dict = datos_json.get("estaciones", {})

		# Itera cada estación del JSON y colorea su nube correspondiente
		for station_id_str in estaciones_dict.keys():
			var station_id = int(station_id_str)
			var datos_estacion = estaciones_dict[station_id_str]
			var pm25_value = datos_estacion.get("pm25", 0.0)
			var nombre_estacion = datos_estacion.get("nombre", "Desconocida")

			# Mapea el ID de la estación al sprite de nube correcto en el mapa
			match station_id:
				1:  # San Juan de Lurigancho
					_establecer_estado_nube(nube_san_juan, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
				2:  # San Martin de Porres
					_establecer_estado_nube(nube_san_martin, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
				3:  # Santa Anita
					_establecer_estado_nube(nube_santa_anita, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
				4:  # Pariachi
					_establecer_estado_nube(nube_pariachi, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
				5:  # Campo de Marte
					_establecer_estado_nube(nube_campo_marte, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
				6:  # San Borja
					_establecer_estado_nube(nube_san_borja, pm25_value)
					print("📍 Estación %d (%s): PM2.5 = %.2f" % [station_id, nombre_estacion, pm25_value])
	else:
		print("⚠️  No hay estaciones registradas aún. Crea una estación desde Flutter.")


# Pone todas las nubes en blanco semitransparente para indicar que no hay datos aún
func _resetear_todas_nubes() -> void:
	if nube_san_juan:
		nube_san_juan.modulate = Color(1, 1, 1, 0.3)
	if nube_san_martin:
		nube_san_martin.modulate = Color(1, 1, 1, 0.3)
	if nube_santa_anita:
		nube_santa_anita.modulate = Color(1, 1, 1, 0.3)
	if nube_pariachi:
		nube_pariachi.modulate = Color(1, 1, 1, 0.3)
	if nube_campo_marte:
		nube_campo_marte.modulate = Color(1, 1, 1, 0.3)
	if nube_san_borja:
		nube_san_borja.modulate = Color(1, 1, 1, 0.3)


# Evalúa el valor de PM2.5 y aplica el color correspondiente al sprite de nube
func _establecer_estado_nube(nube: Sprite2D, valor_estacion: float) -> void:
	if not is_node_ready() or not nube:
		return

	# Clasifica el nivel según los umbrales de la OMS para PM2.5
	var estado: NivelContaminacion
	if valor_estacion <= 12.0:
		estado = NivelContaminacion.LIMPIO
	elif valor_estacion > 12.0 and valor_estacion <= 35.0:
		estado = NivelContaminacion.INTERMEDIO
	else:
		estado = NivelContaminacion.ALTO

	# Aplica el color correspondiente al nivel de contaminación detectado
	match estado:
		NivelContaminacion.LIMPIO:
			nube.modulate = COLOR_VERDE_NUBE
		NivelContaminacion.INTERMEDIO:
			nube.modulate = COLOR_NARANJA_NUBE
		NivelContaminacion.ALTO:
			nube.modulate = COLOR_ROJO_NUBE
