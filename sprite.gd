extends Node2D
@onready var costumes = $Costumes
var costume_names : Array = []
var data
var flagclicked : Array = []
var thread_events : Array = []
var broadcast_receivers : Dictionary = {}
var sounds : Dictionary = {}

func events_search() -> void:
	for block in data.blocks:
		var block_data = data.blocks[block]
		if typeof(block_data) != TYPE_ARRAY:
			if block_data.opcode == "event_whenflagclicked":
				if block_data.next != null:
					flagclicked.append(block)
					thread_events.append(Thread.new())
			elif block_data.opcode == "event_whenbroadcastreceived":
				if block_data.next != null:
					if not broadcast_receivers.has(block_data.fields.BROADCAST_OPTION[1]):
						broadcast_receivers.get_or_add(block_data.fields.BROADCAST_OPTION[1], [])
					broadcast_receivers[block_data.fields.BROADCAST_OPTION[1]].append(block)

func _ready() -> void:
	set_process(false)
	for event in thread_events.size():
		thread_events[event].start(start.bind(flagclicked[event], "", -1))
	fix_costume()

func start(event, loop:String, repeattimes:int):
	var active : bool = true
	var current_block
	var block_data
	var times: int = 0
	if loop == "":
		current_block = data.blocks[event].next
	else:
		current_block = event
	while active:
			times+=1
			while 1:
				block_data = data.blocks[current_block]
				call_deferred(block_data.opcode, block_data.inputs,block_data.fields)
				#callv(block_data.opcode, [block_data.inputs,block_data.fields])
				if block_data.opcode == "sound_playuntildone":
					sound_play(block_data.inputs,block_data.fields)
					var soundnode : AudioStreamPlayer = get_node_or_null(str(sounds.get(data.blocks[block_data.inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])))
					if soundnode != null:
						await get_tree().create_timer(soundnode.stream.get_length()).timeout
					
				if block_data.opcode == "motion_glidesecstoxy":
					await get_tree().create_timer(float(block_data.inputs.SECS[1][1])).timeout
				if block_data.opcode == "control_wait": #I don't know how to make it wait from another funcion... it doesn't work...
					await get_tree().create_timer(clampf(float(block_data.inputs.DURATION[1][1]),0.03,9999999999)).timeout
				if block_data.opcode == "control_repeat":
					await start(block_data.inputs.SUBSTACK[1],block_data.inputs.SUBSTACK[1], int(block_data.inputs.TIMES[1][1]))
				if block_data.next == null:
					if block_data.opcode == "control_forever":
						current_block = block_data.inputs.SUBSTACK[1]
						
						await start(block_data.inputs.SUBSTACK[1],block_data.inputs.SUBSTACK[1],-1)
					#	loop = current_block
					else:
						if loop != "" and times != repeattimes:
							current_block = loop
							break
						else:
							active = false
							break
				else:
					current_block = block_data.next
					print(str(block_data.opcode)+" | "+str(block_data.inputs))
				if active == false:
					break
			#times+=1
			await Engine.get_main_loop().process_frame

func fix_costume() -> void:
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
	if data.costumes[costumes.frame].dataFormat == "svg":
		costumes.scale = Vector2(1,1)
	elif data.costumes[costumes.frame].dataFormat == "png":
		costumes.scale = Vector2(0.5,0.5)

func control_wait(_inputs, _fields) -> void:
	pass
func control_forever(_inputs, _fields) -> void:
	pass

func motion_pointindirection(inputs, _fields) -> void:
	rotation_degrees = int(inputs.DIRECTION[1][1])-90
func motion_turnright(inputs, _fields) -> void:
	rotation_degrees+=int(inputs.DEGREES[1][1])
func motion_turnleft(inputs, _fields) -> void:
	rotation_degrees-=int(inputs.DEGREES[1][1])
func motion_movesteps(inputs, _fields) -> void:
	position+=Vector2(int(inputs.STEPS[1][1]),0).rotated(rotation)
func motion_gotoxy(inputs, _fields) -> void:
	position = Vector2(int(inputs.X[1][1]),-int(inputs.Y[1][1]))
func motion_glidesecstoxy(inputs, _fields) -> void:
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

	
func looks_nextcostume(_inputs, _fields) -> void:
	if costumes.frame == costumes.sprite_frames.get_frame_count("default")-1:
		costumes.frame=0
	else:
		costumes.frame+=1
	fix_costume()
func looks_switchcostumeto(inputs, _fields) -> void:
	costumes.frame=costume_names.find(data.blocks[inputs.COSTUME[1]].fields.COSTUME[0])
	fix_costume()
func looks_seteffectto(inputs, fields) -> void:
	if fields.EFFECT[0] == "GHOST":
		modulate = Color(1,1,1,1-float(inputs.VALUE[1][1])/100)
func looks_hide(_inputs, _fields) -> void:
	visible = false
func looks_show(_inputs, _fields) -> void:
	visible = true
func looks_setsizeto(inputs, _fields) -> void:
	scale = Vector2(1,1)*(float(inputs.SIZE[1][1])/100)
func looks_changesizeby(inputs, _fields) -> void:
	scale += Vector2(1,1)*(float(inputs.CHANGE[1][1])/100)
	
func event_broadcast(inputs, _fields) -> void:
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])
func event_broadcastandwait(inputs, _fields) -> void: # need to make work as intended
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])

func sound_playuntildone(_inputs, _fields) -> void:
	pass
func sound_play(inputs, _fields):
	var sound = get_node_or_null(str(sounds.get(data.blocks[inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])))
	if sound != null:
		sound.play()

func execute_broadcast(broadcast) -> void:
	#for receivers in broadcast_receivers:
	if broadcast_receivers.has(broadcast):
		for receiver in broadcast_receivers[broadcast]:
			var thread = Thread.new()
			thread.start(start.bind(receiver))
	pass
