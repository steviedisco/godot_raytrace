@tool
extends EditorPlugin

var camera_moved_handler = null

func _enter_tree():
	camera_moved_handler = CameraMovedHandler.new()
	add_child(camera_moved_handler)

func _exit_tree():
	remove_child(camera_moved_handler)
	camera_moved_handler.queue_free()



class CameraMovedHandler:
	extends Node	

	@onready var tree = get_tree()
	@onready var tree_root = tree.get_root()	
	@onready var points_node = Node3D.new()

	var monitored_cameras = {}
	var previous_transforms = {}	
	var previous_fovs = {}
	var previous_nears = {}
	
	
	func _ready():
		tree_root.add_child.call_deferred(points_node)


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
		for camera in monitored_cameras.keys():
			if camera and camera is Camera3D:
				var current_transform = camera.global_transform
				var current_fov = camera.fov
				var current_near = camera.near
				var previous_transform = previous_transforms[camera]
				var previous_fov = previous_fovs[camera]
				var previous_near = previous_nears[camera]
				
				if (current_transform != previous_transform or 
					current_fov != previous_fov or 
					current_near != previous_near):
					DrawCameraPoints(camera)
					
					previous_transforms[camera] = current_transform
					previous_fovs[camera] = current_fov
					previous_nears[camera] = current_near


	func _on_node_removed(node):
		if node and node is Camera3D:
			monitored_cameras.erase(node)
			previous_transforms.erase(node)
			previous_fovs.erase(node)
			previous_nears.erase(node)


	func _on_node_added(node):
		if node and node is Camera3D:
			monitored_cameras[node] = true
			previous_transforms[node] = node.global_transform
			previous_fovs[node] = node.fov
			previous_nears[node] = node.near
	
	
	func DrawCameraPoints(cam: Camera3D):
		var cam_t: Transform3D = cam.global_transform
		
		var plane_height: float = 2 * cam.near * tan(deg_to_rad(cam.fov) / 2);
		var plane_width: float = plane_height * get_camera_aspect_ratio(cam)		
		var bottom_left_local = Vector3(-plane_width / 2, -plane_height / 2, -cam.near)
		
		var debugPointCountX = 9
		var debugPointCountY = 9
		
		clear_points()
		
		for x in range(debugPointCountX):
			for y in range(debugPointCountY):				
				var tx: float = x / (debugPointCountX - 1.0)		
				var ty: float = y / (debugPointCountY - 1.0)
				
				var point_local: Vector3 = bottom_left_local + Vector3(plane_width * tx, plane_height * ty, 0)
				var point: Vector3 = cam_t.origin + cam_t.basis.x * point_local.x + cam_t.basis.y * point_local.y + cam_t.basis.z * point_local.z
		
				points_node.add_child.call_deferred(point(point))
				
				
	func point(pos: Vector3, radius = 0.025, color = Color.WHITE_SMOKE) -> MeshInstance3D:
		var mesh_instance := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		var material := ORMMaterial3D.new()			

		mesh_instance.mesh = sphere_mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.position = pos
		
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2
		sphere_mesh.material = material
		
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color			
		
		return mesh_instance
		
		
	func get_camera_aspect_ratio(cam: Camera3D):
		var viewport = cam.get_viewport()
		var viewport_size = viewport.size
		return viewport_size.x / viewport_size.y
		
		
	func clear_points():
		for child in points_node.get_children():
			child.queue_free()
