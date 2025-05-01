extends Control
@onready var list = $CanvasLayer/ItemList
@onready var VM = preload("res://VM.tscn")
func _ready() -> void:
	var dir = DirAccess.open("res://sb3/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			list.add_item(file_name)
			file_name = dir.get_next()


func _on_item_list_item_activated(index: int) -> void:
	#if $'../'.get_children().has("VM"):
	if $'../'.has_node("VM"):
		$'../VM'.free()
		#print($'../'.get_children())
	ProjectSettings.set_setting("global/projectfilename",list.get_item_text(index))
	print(ProjectSettings.get_setting("global/projectfilename"))
	$CanvasLayer.visible = false
	var jamal = VM.instantiate()
	jamal.name = "VM"
	$'../'.add_child(jamal)
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("projects list"): $CanvasLayer.visible = not $CanvasLayer.visible
