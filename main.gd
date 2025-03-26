extends Node2D
var reader:ZIPReader
var sb3
var json
var time_start = Time.get_unix_time_from_system()
var time_now = 0
var time_elapsed = 0
var sprite_order = []

func _init() -> void:
	
	reader = ZIPReader.new()
	sb3 = reader.open("res://Project.sb3")
	json = reader.read_file("project.json").get_string_from_utf8()
	json = JSON.parse_string(json)
	
	create_sprites()
	update_sprite_layers()
func create_sprites():
	for i in json.targets.size()-1:
		sprite_order.append("")
	for target in json.targets:
		if 1:
			var Sprite = preload("res://Sprite.tscn").instantiate()
			var Costumes:AnimatedSprite2D = Sprite.get_node("Costumes")
			Costumes.set_sprite_frames(SpriteFrames.new())
			for costume in target.costumes:
				
				var image = Image.new()
				var error : Error
				#print(costume)
				var costumefilename
				if costume.has("md5ext"):
					costumefilename = costume.md5ext
				else:
					costumefilename = costume.assetId+".png"
				var imagefile = reader.read_file(costumefilename)
				if str(costumefilename).get_extension() == "svg":
					error = image.load_svg_from_buffer(imagefile)
				elif str(costumefilename).get_extension() == "png":
					error = image.load_png_from_buffer(imagefile)

				if error != OK:
					print("BRO IT FAILED")
				else:
					Costumes.get_sprite_frames().add_frame("default", ImageTexture.create_from_image(image))
					Sprite.costume_names.append(costume.name)
			for audio in target.sounds:
				var soundfile = reader.read_file(audio.md5ext)
				var sound
				if str(audio.md5ext).get_extension() == "wav":
					sound = AudioStreamWAV.new()
					sound.format=AudioStreamWAV.FORMAT_16_BITS
				elif str(audio.md5ext).get_extension() == "mp3":
					sound = AudioStreamMP3.new()
				var node = AudioStreamPlayer.new()
				node.name = audio.name
				node.stream=sound
				sound.data = soundfile
				Sprite.add_child(node)
				Sprite.sounds.get_or_add(StringName(audio.name),node.name)
			Sprite.data = target
			Sprite.name = target.name
			#print(Sprite.data.currentCostume)
			Costumes.frame = int(Sprite.data.currentCostume)
			if not target.isStage:
				Sprite.rotation_degrees = Sprite.data.direction-90
				Sprite.visible = Sprite.data.visible
				Sprite.position = Vector2(Sprite.data.x,-Sprite.data.y)
				#Sprite.z_index = Sprite.data.layerOrder
				sprite_order[Sprite.data.layerOrder-1] = Sprite.name
				Sprite.scale = Vector2(1,1)*(float(Sprite.data.size)*.01)
			Sprite.events_search()
			add_child(Sprite)
			
func change_sprite_layer(type,Sprite):
	sprite_order.remove_at(Sprite.z_index-1)
	if type == 0: #go to de back
		sprite_order.insert(0,Sprite.name)
	elif type == 1: #go to de front
		sprite_order.insert(sprite_order.size(),Sprite.name)
	update_sprite_layers()
	
func update_sprite_layers():
	var index = 0
	for sprite in sprite_order:
		index+=1
		get_node(str(sprite)).z_index = index
func broadcast(sendbroadcast):
	var sprite_order_reversed = sprite_order
	sprite_order_reversed.reverse()
	for sprite in sprite_order:
		get_node(str(sprite)).execute_broadcast(sendbroadcast)

func _process(_delta):
	time_now = Time.get_unix_time_from_system()
	time_elapsed = time_now - time_start
