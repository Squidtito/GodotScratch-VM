extends Node2D
@onready var costumes = $Costumes
var costume_names : Array = []
var data
var flagclicked : Array = []
var thread_events : Array = []
var broadcast_receivers : Dictionary = {}

func events_search() -> void:
	#print(broadcast_receivers)
	#print(data.blocks)
	for block in data.blocks:
		#print(data.blocks[block])
		
		#if typeof(data.blocks[block]) is Array:
		#	print("OH DADDY")
		#print("please")
		#print(data.blocks[block])
		#print(name)
		if typeof(data.blocks[block]) != TYPE_ARRAY:
			if data.blocks[block].opcode == "event_whenflagclicked":
				flagclicked.append(block)
				thread_events.append(Thread.new())
			elif data.blocks[block].opcode == "event_whenbroadcastreceived":
				print(data.blocks[block])
				if not broadcast_receivers.has(data.blocks[block].fields.BROADCAST_OPTION[1]):
					broadcast_receivers.get_or_add(data.blocks[block].fields.BROADCAST_OPTION[1], [])
				#broadcast_recievers.set(data.blocks[block].fields.BROADCAST_OPTION[1],)
				broadcast_receivers[data.blocks[block].fields.BROADCAST_OPTION[1]].append(block)
				
	#print(flagclicked)

func _ready() -> void:
	set_process(false)
	for event in thread_events.size():
		thread_events[event].start(start.bind(flagclicked[event]))
	center_costume()

func start(event):
	var active : bool = true
	var current_block
	var loop:String = ""
	current_block = data.blocks[event].next
	while active:
			#print(data.blocks[current_block].opcode)
			while 1:
				#if data.blocks[current_block].opcode != "control_if":
				#if typeof(data.blocks[current_block]) != TYPE_ARRAY:
				#print("hehe")
				#print(data.blocks[current_block])
				call_deferred(data.blocks[current_block].opcode, data.blocks[current_block].inputs,data.blocks[current_block].fields)
				if data.blocks[current_block].opcode == "sound_playuntildone":
					sound_play(data.blocks[current_block].inputs,data.blocks[current_block].fields)
					var soundnode : AudioStreamPlayer = get_node_or_null(data.blocks[data.blocks[current_block].inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])
					if soundnode != null:
						await get_tree().create_timer(soundnode.stream.get_length()).timeout
					
				if data.blocks[current_block].opcode == "motion_glidesecstoxy":
					await get_tree().create_timer(float(data.blocks[current_block].inputs.SECS[1][1])).timeout
				if data.blocks[current_block].opcode == "control_wait": #I don't know how to make it wait from another funcion... it doesn't work...
					await get_tree().create_timer(clampf(float(data.blocks[current_block].inputs.DURATION[1][1]),0.001,9999999999)).timeout
				if data.blocks[current_block].next == null:
					if data.blocks[current_block].opcode == "control_forever":
						current_block = data.blocks[current_block].inputs.SUBSTACK[1]
						loop = current_block
					#elif data.blocks[current_block].next == null:
					#	pass
					else:
						if loop != "":
							current_block = loop
							break
						else:
							active = false
							break
				else:
					current_block = data.blocks[current_block].next
					print(str(data.blocks[current_block].opcode)+" | "+str(data.blocks[current_block].inputs))
				if active == false:
					break
				#await get_tree().create_timer(int(1)).timeout
			#await get_tree().create_timer(int(1)).timeout
			#print("BALLS")
			if active == false:
				break
			#print(active)
			await Engine.get_main_loop().process_frame

func center_costume():
	var costumefilename
	if data.costumes[costumes.frame].has("md5ext"):
		costumefilename = data.costumes[costumes.frame].md5ext
	else:
		costumefilename = data.costumes[costumes.frame].assetId+".png"
	if str(costumefilename.get_extension()) == "svg":
		costumes.position = Vector2(
						costumes.sprite_frames.get_frame_texture("default",costumes.frame).get_width()/2,
						costumes.sprite_frames.get_frame_texture("default",costumes.frame).get_height()/2  # Fix: Use -1 instead of 0
					)
		costumes.offset = Vector2(
						data.costumes[costumes.frame].rotationCenterX * -1,
						data.costumes[costumes.frame].rotationCenterY * -1  # Fix: Use -1 instead of 0
					)

func control_wait(_inputs, _fields):
	pass
	#await get_tree().create_timer(int(1)).timeout
func control_forever(_inputs, _fields):
	pass
	
func motion_turnright(inputs, _fields):
	rotation_degrees+=int(inputs.DEGREES[1][1])
func motion_turnleft(inputs, _fields):
	rotation_degrees-=int(inputs.DEGREES[1][1])
func motion_movesteps(inputs, _fields):
	position+=Vector2(int(inputs.STEPS[1][1]),0).rotated(rotation)
func motion_gotoxy(inputs, _fields):
	position = Vector2(int(inputs.X[1][1]),-int(inputs.Y[1][1]))
func motion_glidesecstoxy(inputs, _fields):
	var target_position = Vector2(int(inputs.X[1][1]), -int(inputs.Y[1][1]))
	var start_position = position
	
	# Try to get the duration, with a fallback
	var duration = 1.0  # Default duration
	duration = float(inputs.SECS[1][1])
	
	var elapsed_time = 0.0
	
	while position != target_position:
		# Yield control back to the engine for one frame
		await get_tree().process_frame
		
		# Update elapsed time
		elapsed_time += get_process_delta_time()
		var t = min(elapsed_time / duration, 1.0)
		
		# Update position using lerp
		position = start_position.lerp(target_position, t)
		
		# If we've reached the end of the animation, exit the loop
		if t >= 1.0:
			position = target_position
			break

	
func looks_nextcostume(_inputs, fields):
	if costumes.frame == costumes.sprite_frames.get_frame_count("default")-1:
		costumes.frame=0
	else:
		costumes.frame+=1
	if data.costumes[costumes.frame].dataFormat == "svg":
		costumes.scale = Vector2(1,1)
	elif data.costumes[costumes.frame].dataFormat == "png":
		costumes.scale = Vector2(0.5,0.5)
	center_costume()
	#costumes.offset = Vector2(data.costumes[costumes.frame].rotationCenterX,data.costumes[costumes.frame].rotationCenterY)
func looks_switchcostumeto(inputs, fields):
	costumes.frame=costume_names.find(inputs.COSTUME[1])
	center_costume()
	#position -= Vector2(data.costumes[costumes.frame].rotationCenterX,data.costumes[costumes.frame].rotationCenterY)
	#costumes.offset = Vector2(data.costumes[costumes.frame].rotationCenterX,data.costumes[costumes.frame].rotationCenterY)
func looks_seteffectto(inputs, fields):
	if fields.EFFECT[0] == "GHOST":
		modulate = Color(1,1,1,1-int(inputs.VALUE[1][1])/100)
func looks_hide(_inputs, _fields):
	visible = false
func looks_show(_inputs, _fields):
	visible = true
func looks_setsizeto(inputs, _fields):
	scale = Vector2(1,1)*(float(inputs.SIZE[1][1])/100)
func looks_changesizeby(inputs, _fields):
	scale += Vector2(1,1)*(float(inputs.CHANGE[1][1])/100)
	
func event_broadcast(inputs, _fields):
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])
func event_broadcastandwait(inputs, _fields): # need to make work as intended
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])

func sound_playuntildone(_inputs, _fields):
	pass
func sound_play(inputs, _fields):
	print("heh" +inputs.SOUND_MENU[1][1])
	print(data.blocks[inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])
	print("Sprite: "+name)
	var sound = get_node_or_null(data.blocks[inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])
	if sound != null:
		sound.play()

func execute_broadcast(broadcast):
	#for receivers in broadcast_receivers:
	print("executing")
	if broadcast_receivers.has(broadcast):
		print("executed")
		for receiver in broadcast_receivers[broadcast]:
			var thread = Thread.new()
			thread.start(start.bind(receiver))
			#start(receiver)
	pass
