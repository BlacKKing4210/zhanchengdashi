extends Node

const CLIENT_SCENE = preload("res://scenes/main.tscn")
const SERVER_SCENE = preload("res://scenes/server.tscn")


func _ready() -> void:
	var target_scene = SERVER_SCENE if OS.has_feature("dedicated_server") else CLIENT_SCENE
	call_deferred("_change_to_target_scene", target_scene)


func _change_to_target_scene(target_scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(target_scene)
