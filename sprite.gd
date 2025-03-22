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
					await get_tree().create_timer(float(evaluate_input(block_data.inputs.SECS))).timeout
				if block_data.opcode == "control_wait": #I don't know how to make it wait from another funcion... it doesn't work...
					await get_tree().create_timer(clampf(float(evaluate_input(block_data.inputs.DURATION)),0.03,9999999999)).timeout
				if block_data.opcode == "control_repeat":
					#pass
					await start(block_data.inputs.SUBSTACK[1],block_data.inputs.SUBSTACK[1], int(evaluate_input(block_data.inputs.TIMES)))
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
					#print(str(block_data.opcode)+" | "+str(block_data.inputs))
				if active == false:
					break
			#times+=1
			await Engine.get_main_loop().process_frame

func check_number(NUM):
	if NUM == null: NUM = "0"
	
	if NUM.is_valid_int():
		NUM = int(NUM)
	elif NUM.is_valid_float():
		NUM = float(NUM)
		if floor(NUM) == NUM: NUM = int(NUM)
	return NUM
func evaluate_input(arg):
	
	#match arg[0]:
	#	1.0:
	#		var block_data = data.blocks[arg[1]]
	#		return callv(block_data.opcode, [block_data.inputs,block_data.fields])
	match int(arg[0]):
		1:
			if typeof(arg[1]) == TYPE_ARRAY:
				if arg[1][0] == 11.0:
					return arg[1][2]
				else:
					return arg[1][1]
			else:
				if arg[0] == 1.0:
					var block_data = data.blocks[arg[1]]
					var execute = callv(block_data.opcode, [block_data.inputs,block_data.fields])
					return execute
				else:
					return arg[1]
		3:
			var block_data = data.blocks[arg[1]]
			var execute = callv(block_data.opcode, [block_data.inputs,block_data.fields])
			if execute == null: #if the function doesn't exist or returns null, this will at least kinda help not crash the entire project
				return "0"
			return execute
		11:
			return arg[1][2]
			
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

func operator_random(inputs, _fields):
	var FROM = check_number(evaluate_input(inputs.FROM))
	var TO = check_number(evaluate_input(inputs.TO))
	if typeof(FROM) == TYPE_FLOAT or typeof(TO) == TYPE_FLOAT:
		return str(randf_range(FROM,TO))
	else:
		return str(randi_range(FROM,TO))

func operator_add(inputs, _fields):
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1+NUM2)
func operator_subtract(inputs, _fields):
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1-NUM2)
func control_wait(_inputs, _fields) -> void:
	pass
func control_forever(_inputs, _fields) -> void:
	pass

func motion_changexby(inputs, _fields):
	position.x += float(evaluate_input(inputs.DX))
func motion_changeyby(inputs, _fields):
	position.y -= float(evaluate_input(inputs.DY))
func motion_pointindirection(inputs, _fields) -> void:
	rotation_degrees = int(evaluate_input(inputs.DIRECTION))-90
func motion_turnright(inputs, _fields) -> void:
	rotation_degrees+=int(evaluate_input(inputs.DEGREES))
func motion_turnleft(inputs, _fields) -> void:
	rotation_degrees-=int(evaluate_input(inputs.DEGREES))
func motion_movesteps(inputs, _fields) -> void:
	position+=Vector2(int(evaluate_input(inputs.STEPS)),0).rotated(rotation)
func motion_gotoxy(inputs, _fields) -> void:
	position = Vector2(int(evaluate_input(inputs.X)),-int(evaluate_input(inputs.Y)))
func motion_glidesecstoxy(inputs, _fields) -> void:
	var target_position = Vector2(int(evaluate_input(inputs.X)), -int(evaluate_input(inputs.Y)))
	var start_position = position
	
	# Try to get the duration, with a fallback
	var duration = 1.0  # Default duration
	duration = float(evaluate_input(inputs.SECS))
	
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

	
func looks_costumenumbername(_inputs, fields):
	if fields.NUMBER_NAME[0] == "number":
		return str(costumes.frame+1)
func looks_nextcostume(_inputs, _fields) -> void:
	if costumes.frame == costumes.sprite_frames.get_frame_count("default")-1:
		costumes.frame=0
	else:
		costumes.frame+=1
	fix_costume()
func looks_switchcostumeto(inputs, _fields) -> void:
	costumes.frame=costume_names.find(evaluate_input(inputs.COSTUME))
	fix_costume()
func looks_costume(_inputs, fields):
	return fields.COSTUME[0]
func looks_seteffectto(inputs, fields) -> void:
	if fields.EFFECT[0] == "GHOST":
		modulate = Color(1,1,1,1-float(evaluate_input(inputs.VALUE))/100)
func looks_hide(_inputs, _fields) -> void:
	visible = false
func looks_show(_inputs, _fields) -> void:
	visible = true
func looks_setsizeto(inputs, _fields) -> void:
	scale = Vector2(1,1)*(float(evaluate_input(inputs.SIZE))/100)
func looks_changesizeby(inputs, _fields) -> void:
	scale += Vector2(1,1)*(float(evaluate_input(inputs.CHANGE))/100)
	
func event_broadcast(inputs, _fields) -> void:
	#print("hehe")
	$'../'.broadcast(evaluate_input(inputs.BROADCAST_INPUT))
func event_broadcastandwait(inputs, _fields) -> void: # need to make work as intended
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])

func sound_playuntildone(_inputs, _fields) -> void:
	pass
func sound_play(inputs, _fields): #Have to adjust this whenever I feel it it
	var sound = get_node_or_null(str(sounds.get(data.blocks[inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])))
	if sound != null:
		sound.play()

func execute_broadcast(broadcast) -> void:
	#for receivers in broadcast_receivers:
	if broadcast_receivers.has(broadcast):
		for receiver in broadcast_receivers[broadcast]:
			var thread = Thread.new()
			thread.start(start.bind(receiver,"",-1))
	pass
