@tool
extends EditorPlugin

var camera_changed_handler = null


func _enter_tree():
	camera_changed_handler = CameraChangedHandler.new()
	camera_changed_handler.plugin = self
	add_child(camera_changed_handler)
	

func _exit_tree():
	remove_child(camera_changed_handler)
	camera_changed_handler.queue_free()
	

class CameraChangedHandler:
	extends Node	

	@onready var tree = get_tree()
	@onready var tree_root = tree.get_root()	
	@onready var points_node = Node3D.new()

	var monitored_cameras = {}
	var previous_transforms = {}	
	var previous_fovs = {}
	var previous_nears = {}
	var previous_currents = {}
	
	var plugin
	var last_scene
	var current_scene

	const debug_point_count_x = 16
	const debug_point_count_y = 9	
	
	var points = []
	
	func _ready():
		tree_root.add_child.call_deferred(points_node)
		
		cache_points()


	func _notification(what):
		if what == NOTIFICATION_PREDELETE && tree != null:
			tree.disconnect("node_removed", _on_node_removed)
			tree.disconnect("node_added", _on_node_added)
			return

		if what == NOTIFICATION_READY && tree != null:
			tree.connect("node_removed", _on_node_removed)
			tree.connect("node_added", _on_node_added)
			set_process(true)


	func _process(delta):		
		var editor = plugin.get_editor_interface()
		
		if editor.get_edited_scene_root():
			current_scene = editor.get_edited_scene_root().get_path().hash()
		else:
			current_scene = 0			

		if last_scene and current_scene != last_scene:
			print ('scene changed')
			clear_points()
			reset_handler()

		last_scene = current_scene
		
		for camera in monitored_cameras.keys():
						
			if camera and camera is Camera3D and camera.name == 'CameraRayTest':
				var current_transform = camera.global_transform
				var current_fov = camera.fov
				var current_near = camera.near
				var current = camera.current
				
				var previous_transform = previous_transforms[camera]
				var previous_fov = previous_fovs[camera]
				var previous_near = previous_nears[camera]
				var previous_current = previous_currents[camera]
				
				if (current_transform != previous_transform or 
					current_fov != previous_fov or 
					current_near != previous_near or 
					current != previous_current):
					
					clear_points()	
					
					if (current):
						draw_camera_points(camera)
					
					previous_transforms[camera] = current_transform
					previous_fovs[camera] = current_fov
					previous_nears[camera] = current_near
					previous_currents[camera] = current


	func _on_node_removed(node):
		if node and node is Camera3D:
			monitored_cameras.erase(node)
			previous_transforms.erase(node)
			previous_fovs.erase(node)
			previous_nears.erase(node)
			previous_currents.erase(node)


	func _on_node_added(node):
		if node and node is Camera3D:
			monitored_cameras[node] = true
			previous_transforms[node] = node.global_transform
			previous_fovs[node] = node.fov
			previous_nears[node] = node.near
			previous_currents[node] = false
	
	
	func cache_points():
		for x in range(debug_point_count_x):
			points.append([])
			for y in range(debug_point_count_y):	
				var point = point(Vector3.ZERO)			
				points[x].append(point)
				points_node.add_child.call_deferred(point)
	
	
	func draw_camera_points(cam: Camera3D):
		var cam_t: Transform3D = cam.global_transform
		var cam_near = cam.near + 0.05
		
		var plane_height: float = 2 * cam_near * tan(deg_to_rad(cam.fov) / 2);
		var plane_width: float = plane_height * get_aspect_ratio()		
		var bottom_left_local = Vector3(-plane_width / 2, -plane_height / 2, -cam_near)			
		
		for x in range(debug_point_count_x):
			for y in range(debug_point_count_y):				
				var tx: float = x / (debug_point_count_x - 1.0)		
				var ty: float = y / (debug_point_count_y - 1.0)
				
				var point_local: Vector3 = bottom_left_local + Vector3(plane_width * tx, plane_height * ty, 0)
				var point: Vector3 = cam_t.origin + cam_t.basis.x * point_local.x + cam_t.basis.y * point_local.y + cam_t.basis.z * point_local.z
		
				points[x][y].transform.origin = point
				points[x][y].visible = true
				
				
	func point(pos: Vector3, radius = 0.025, color = Color.WHITE_SMOKE) -> MeshInstance3D:
		var mesh_instance := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		var material := ORMMaterial3D.new()			

		mesh_instance.mesh = sphere_mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = pos
		mesh_instance.visible = false
				
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2
		sphere_mesh.material = material
		
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color	
				
		return mesh_instance
		
		
	func get_aspect_ratio():		
		var window_size = DisplayServer.window_get_size()
		return float(window_size.x) / float(window_size.y)
		
		
	func clear_points():
		for child in points_node.get_children():
			child.visible = false
			
			
	func reset_handler():
		for camera in monitored_cameras:					
			if camera and camera is Camera3D:
				previous_transforms[camera] = camera.global_transform
				previous_fovs[camera] = camera.fov
				previous_nears[camera] = camera.near
				previous_currents[camera] = false
