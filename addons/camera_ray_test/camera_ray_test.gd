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

	var monitored_cameras = {}
	var previous_transforms = {}
	@onready var tree = get_tree()

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
				var previous_transform = previous_transforms[camera]
				if current_transform != previous_transform:
					print("Camera moved or rotated")
					previous_transforms[camera] = current_transform

	func _on_node_removed(node):
		if node and node is Camera3D:
			monitored_cameras.erase(node)
			previous_transforms.erase(node)

	func _on_node_added(node):
		if node and node is Camera3D:
			monitored_cameras[node] = true
			previous_transforms[node] = node.global_transform
