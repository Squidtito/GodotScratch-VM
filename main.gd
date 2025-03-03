extends Node2D
var reader:ZIPReader
var sb3
var json

func _init() -> void:
	
	reader = ZIPReader.new()
	sb3 = reader.open("res://augustus poop.sb3")
	json = reader.read_file("project.json").get_string_from_utf8()
	json = JSON.parse_string(json)
	
	create_sprites()

func create_sprites():
	for target in json.targets:
		if 1: #not target.isStage:
			var Sprite = preload("res://Sprite.tscn").instantiate()
			var Costumes:AnimatedSprite2D = Sprite.get_node("Costumes")
			Costumes.set_sprite_frames(SpriteFrames.new())
			for costume in target.costumes:
				
				var image = Image.new()
				var error : Error
				var imagefile = reader.read_file(costume.md5ext)
				if str(costume.md5ext).get_extension() == "svg":
					var TempFile = FileAccess.open("user://temp.svg", FileAccess.WRITE) 
					TempFile.store_string(imagefile.get_string_from_utf8())
					TempFile.close()

					error = image.load("user://temp.svg")
				elif str(costume.md5ext).get_extension() == "png":
					error = image.load_png_from_buffer(imagefile)

				#print(imagefile)
				if error != OK:
					print("BRO IT FAILED")
				else:
					Costumes.get_sprite_frames().add_frame("default", ImageTexture.create_from_image(image))
					Sprite.costume_names.append(costume.md5ext)
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
				#reader.close()
			Sprite.data = target
			Sprite.name = target.name
			print(Sprite.data.currentCostume)
			Costumes.frame = int(Sprite.data.currentCostume)
			if not target.isStage:
				Sprite.visible = Sprite.data.visible
				Sprite.position = Vector2(Sprite.data.x,Sprite.data.y*-1)
				Sprite.z_index = Sprite.data.layerOrder
				Sprite.scale = Vector2(1,1)*(float(Sprite.data.size)/100)
				#print(Costumes.sprite_frames.get_frame_texture("default",Sprite.data.currentCostume).get_width()/2)
				#Sprite.position -= Vector2(Sprite.data.costumes[Costumes.frame].rotationCenterX*0.5,Sprite.data.costumes[Costumes.frame].rotationCenterY*0.5)
			Sprite.events_search()
			add_child(Sprite)
			#Sprite.center_costume()
			
func broadcast(broadcast):
	for sprite in get_children():
		if not sprite.name == "Camera2D":
			sprite.execute_broadcast(broadcast)
