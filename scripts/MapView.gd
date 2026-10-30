extends Node2D

signal province_selected(province_id: String)

var camera: Camera2D
var dragging: bool = false
var drag_start: Vector2
var last_touch_pos: Vector2
var pinch_start_distance: float = 0.0
var pinch_start_zoom: float = 1.0

var provinces_visual: Dictionary = {}
var selected_province: String = ""

# Map bounds
const MAP_WIDTH = 1200
const MAP_HEIGHT = 800
const MAP_OFFSET = Vector2(360, 140)

func _ready():
	camera = $Camera2D
	camera.position = Vector2(MAP_WIDTH / 2 + MAP_OFFSET.x, MAP_HEIGHT / 2 + MAP_OFFSET.y)
	generate_province_visuals()

func generate_province_visuals():
	# Generate polygons for provinces based on their positions
	var provinces = GameManager.provinces
	
	for prov_id in provinces:
		var prov = provinces[prov_id]
		var pos = Vector2(prov["position"][0], prov["position"][1]) + MAP_OFFSET
		
		# Create a simple hexagon-ish shape for each province
		var polygon = PackedVector2Array()
		var radius = 60.0
		for i in range(6):
			var angle = i * PI / 3.0 + randf_range(-0.2, 0.2)
			var point = pos + Vector2(cos(angle), sin(angle)) * (radius + randf_range(-10, 10))
			polygon.append(point)
		
		provinces_visual[prov_id] = {
			"polygon": polygon,
			"center": pos
		}

func _draw():
	# Draw background
	draw_rect(Rect2(MAP_OFFSET, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.15, 0.25, 0.15, 1))
	
	# Draw provinces
	for prov_id in provinces_visual:
		var prov = GameManager.provinces[prov_id]
		var visual = provinces_visual[prov_id]
		var owner = prov["owner"]
		var country = GameManager.countries[owner]
		
		# Get country color
		var color = Color(
			country["color"][0] / 255.0,
			country["color"][1] / 255.0,
			country["color"][2] / 255.0,
			1.0
		)
		
		# Darken if selected
		if prov_id == selected_province:
			color = color.lightened(0.3)
		
		# Draw province polygon
		draw_colored_polygon(visual["polygon"], color)
		
		# Draw border
		var border_color = Color.BLACK
		draw_polyline(visual["polygon"] + PackedVector2Array([visual["polygon"][0]]), border_color, 2.0)
		
		# Draw province name
		draw_string(ThemeDB.fallback_font, visual["center"] - Vector2(30, 0), prov["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE)
		
		# Draw unit count if any
		if GameManager.units.has(prov_id) and GameManager.units[prov_id].size() > 0:
			var unit_count = GameManager.units[prov_id].size()
			var unit_text = "⚔ " + str(unit_count)
			draw_string(ThemeDB.fallback_font, visual["center"] + Vector2(-20, 20), unit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color.YELLOW)
	
	# Draw connections
	for prov_id in GameManager.provinces:
		var prov = GameManager.provinces[prov_id]
		var visual = provinces_visual[prov_id]
		for conn_id in prov["connections"]:
			if provinces_visual.has(conn_id):
				var conn_visual = provinces_visual[conn_id]
				draw_line(visual["center"], conn_visual["center"], Color(0.3, 0.3, 0.3, 0.3), 1.0)

func _input(event):
	# Handle touch/mouse input for pan and zoom
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			dragging = true
			drag_start = event.position
			last_touch_pos = event.position
			
			# Check if clicked on a province
			var touch_pos = get_viewport_transform().affine_inverse() * event.position
			touch_pos = camera.get_global_transform().affine_inverse() * touch_pos
			check_province_click(touch_pos)
		else:
			dragging = false
	
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and dragging):
		if dragging:
			var delta = event.position - last_touch_pos
			camera.position -= delta / camera.zoom
			last_touch_pos = event.position
	
	# Handle pinch zoom (for mobile)
	elif event is InputEventMagnifyGesture:
		camera.zoom *= event.factor
		camera.zoom.x = clamp(camera.zoom.x, 0.5, 3.0)
		camera.zoom.y = clamp(camera.zoom.y, 0.5, 3.0)
	
	# Mouse wheel zoom
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
		camera.zoom.x = clamp(camera.zoom.x, 0.5, 3.0)
		camera.zoom.y = clamp(camera.zoom.y, 0.5, 3.0)

func check_province_click(pos: Vector2):
	for prov_id in provinces_visual:
		var visual = provinces_visual[prov_id]
		if Geometry2D.is_point_in_polygon(pos, visual["polygon"]):
			selected_province = prov_id
			emit_signal("province_selected", prov_id)
			queue_redraw()
			return
