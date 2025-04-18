extends Node2D
@onready var costumes = $Costumes
@onready var Stage = $'../Stage'
var costume_names : Array = []
var data : Dictionary
var flagclicked : Array = []
var thread_events : Array = []
var broadcast_receivers : Dictionary = {}
var start_as_a_clone : Array = []
var sounds : Dictionary = {}
var active_threads : Array = []
var is_clone : bool = false

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
			elif block_data.opcode == "control_start_as_clone":
				if block_data.next != null:
					start_as_a_clone.append(block)
func _ready() -> void:
	fix_costume()
	if is_clone:
		#print("AHH")
		for block in start_as_a_clone:
			thread_events.append(Thread.new())
			thread_events[thread_events.size()-1].start(start.bind(block, "", -1))
func begin():
	for event in thread_events.size():
		thread_events[event].start(start.bind(flagclicked[event], "", -1))

#@warning_ignore("")
func start(event, loop:String="", repeattimes:int=0, nextblock:bool=true):
	var active : bool = true
	var current_block: String
	var block_data : Dictionary
	var times: int = 0
	if loop == "" and nextblock:
		current_block = data.blocks[event].next
	else:
		current_block = event
	while active:
			times+=1
			while 1:
				block_data = data.blocks[current_block]
				call_deferred(block_data.opcode, block_data.inputs,block_data.fields)
				#print(block_data)
				#callv(block_data.opcode, [block_data.inputs,block_data.fields])
				match block_data.opcode:
					"sound_playuntildone":
						sound_play(block_data.inputs,block_data.fields)
						var soundnode : AudioStreamPlayer = get_node_or_null(str(sounds.get(data.blocks[block_data.inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])))
						if soundnode != null:
							await get_tree().create_timer(soundnode.stream.get_length()).timeout
					"motion_glidesecstoxy":
						await get_tree().create_timer(float(evaluate_input(block_data.inputs.SECS))).timeout
					"control_wait":
						await get_tree().create_timer(clampf(float(evaluate_input(block_data.inputs.DURATION)),0.03,9999999999)).timeout
					"control_repeat":
						await start(block_data.inputs.SUBSTACK[1],block_data.inputs.SUBSTACK[1], int(evaluate_input(block_data.inputs.TIMES)))
					"control_if":
						var statement = data.blocks[block_data.inputs.CONDITION[1]]
						if callv(statement.opcode, [statement.inputs, statement.fields]):
							await start(block_data.inputs.SUBSTACK[1], "", -1,false)
				if block_data.next == null:
					if block_data.opcode == "control_forever":
						current_block = block_data.inputs.SUBSTACK[1]
						
						await start(current_block,current_block,-1)
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
				if active == false:
					break
			#times+=1
			if nextblock:
				await Engine.get_main_loop().process_frame
func check_number(NUM) -> Variant:
	match NUM:
		
		null:
			NUM = "0"
		false:
			NUM = "0"
		true:
			NUM = "1"
	
	if NUM.is_valid_int():
		NUM = int(NUM)
	elif NUM.is_valid_float():
		NUM = float(NUM)
		if floor(NUM) == NUM: 
			NUM = int(NUM)
	else: NUM = 0
	return NUM
func evaluate_input(arg) -> Variant:
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
			var block_data
			if typeof(arg[1]) == TYPE_ARRAY:
				if arg[1][0] == 12.0:
					return str(getvariable(arg[1][2])[1])
				block_data = data.blocks[arg[1][1]]
			else:
				block_data = data.blocks[arg[1]]
			var execute = callv(block_data.opcode, [block_data.inputs,block_data.fields])
			if execute == null: #if the function doesn't exist or returns null, this will at least kinda help not crash the entire project
				return "0"
			return execute
	return null
			
func fix_costume() -> void:
	var costumefilename
	if data.costumes[costumes.frame].has("md5ext"):
		costumefilename = data.costumes[costumes.frame].md5ext
	else:
		costumefilename = data.costumes[costumes.frame].assetId+".png"
	if str(costumefilename.get_extension()) == "svg":
		costumes.position = Vector2(
						costumes.sprite_frames.get_frame_texture("default",costumes.frame).get_width()*.5,
						costumes.sprite_frames.get_frame_texture("default",costumes.frame).get_height()*.5  # Fix: Use -1 instead of 0
					)
		costumes.offset = Vector2(
						data.costumes[costumes.frame].rotationCenterX * -1,
						data.costumes[costumes.frame].rotationCenterY * -1  # Fix: Use -1 instead of 0
					)
	if data.costumes[costumes.frame].dataFormat == "svg":
		costumes.scale = Vector2(1,1)
	elif data.costumes[costumes.frame].dataFormat == "png":
		costumes.scale = Vector2(0.5,0.5)

func operator_lt(inputs, _fields) -> bool:
	var OPERAND1 = check_number(evaluate_input(inputs.OPERAND1))
	var OPERAND2 = check_number(evaluate_input(inputs.OPERAND2))
	if OPERAND1 < OPERAND2: return true
	return false
func operator_gt(inputs, _fields) -> bool:
	var OPERAND1 = check_number(evaluate_input(inputs.OPERAND1))
	var OPERAND2 = check_number(evaluate_input(inputs.OPERAND2))
	
	if OPERAND1 > OPERAND2: return true
	return false
func operator_equals(inputs, _fields) -> bool:
	var OPERAND1 = check_number(evaluate_input(inputs.OPERAND1))
	var OPERAND2 = check_number(evaluate_input(inputs.OPERAND2))
	
	if OPERAND1 == OPERAND2: return true
	return false
func operator_random(inputs, _fields) -> Variant:
	var FROM = check_number(evaluate_input(inputs.FROM))
	var TO = check_number(evaluate_input(inputs.TO))
	if typeof(FROM) == TYPE_FLOAT or typeof(TO) == TYPE_FLOAT:
		return str(randf_range(FROM,TO))
	else:
		return str(randi_range(FROM,TO))
func operator_not(inputs, _fields) -> bool:
	var block = data.blocks[inputs.OPERAND[1]]
	return not callv(block.opcode,[block.inputs,block.fields])
func operator_contains(inputs, _fields) -> bool:
	var STRING1:String = evaluate_input(inputs.STRING1)
	var STRING2:String = evaluate_input(inputs.STRING2)
	return STRING1.contains(STRING2)
func operator_add(inputs, _fields) -> String:
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1+NUM2)
func operator_subtract(inputs, _fields) -> String:
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1-NUM2)
func operator_multiply(inputs, _fields) -> String:
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1*NUM2)
func operator_divide(inputs, _fields) -> String:
	var NUM1 = check_number(evaluate_input(inputs.NUM1))
	var NUM2 = check_number(evaluate_input(inputs.NUM2))
	return str(NUM1/NUM2)
func operator_round(inputs, _fields) -> String:
	return str(round(check_number(evaluate_input(inputs.NUM))))
func operator_mathop(inputs, fields) -> String:
	var NUM = check_number(evaluate_input(inputs.NUM))
	match fields.OPERATOR[0]:
		"abs":
			return str(abs(NUM))
		"floor":
			return str(floor(NUM))
		"ceiling":
			return str(ceil(NUM))
		"sqrt":
			return str(sqrt(NUM))
		"cos":
			return str(cos(deg_to_rad(NUM)))
		"sin":
			return str(sin(deg_to_rad(NUM)))
		"tan":
			return str(tan(NUM))
		"asin":
			return str(rad_to_deg(asin(NUM)))
		"acos":
			return str(rad_to_deg(acos(NUM)))
		"atan":
			return str(rad_to_deg(atan(NUM)))
		"ln":
			return str(log(NUM))
		"log":
			return str(log(NUM) / log(10))
		"e ^":
			return str(exp(log(NUM)))
		"10 ^":
			return str(pow(NUM,10))
	return "0"
func control_wait(_inputs, _fields) -> void: pass
func control_forever(_inputs, _fields) -> void: pass
func control_repeat(_inputs, _fields) -> void: pass
func control_if(_inputs, _fields)  -> void: pass
func control_create_clone_of(inputs, _fields) -> void:
	var menu = evaluate_input(inputs.CLONE_OPTION)
	if menu == "_myself_":
		#print(is_clone)
		var clone = self.duplicate()
		clone.is_clone = true
		clone.costume_names = costume_names
		#print(is_clone)
		clone.sounds = sounds
		clone.broadcast_receivers = broadcast_receivers
		#Dictionary
		clone.data.merge(data.duplicate(true))
		clone.name = name+"_clone"+str(randi_range(1,99999))
		clone.start_as_a_clone = start_as_a_clone
		$'../'.add_child(clone)
		$'../'.add_sprite_to_layer(clone,z_index+1)
		#print(is_clone)
func control_create_clone_of_menu(_inputs, fields) -> String: return fields.CLONE_OPTION[0]
func motion_changexby(inputs, _fields) -> void:
	position.x += check_number(evaluate_input(inputs.DX))
func motion_changeyby(inputs, _fields) -> void:
	position.y -= check_number(evaluate_input(inputs.DY))
func motion_xposition(_inputs, _fields) -> void: return str(position.x)
func motion_yposition(_inputs, _fields) -> void: return str(-position.y)
func motion_pointindirection(inputs, _fields) -> void:
	rotation_degrees = check_number(evaluate_input(inputs.DIRECTION))-90
func motion_turnright(inputs, _fields) -> void:
	rotation_degrees+=check_number(evaluate_input(inputs.DEGREES))
func motion_turnleft(inputs, _fields) -> void:
	rotation_degrees-=check_number(evaluate_input(inputs.DEGREES))
func motion_movesteps(inputs, _fields) -> void:
	position+=Vector2(check_number(evaluate_input(inputs.STEPS)),0).rotated(rotation)
func motion_gotoxy(inputs, _fields) -> void:
	position = Vector2(check_number(evaluate_input(inputs.X)),-check_number(evaluate_input(inputs.Y)))
func motion_sety(inputs, _fields) -> void:
	position.y = -check_number(evaluate_input(inputs.Y))
func motion_setx(inputs, _fields) -> void:
	position.x = check_number(evaluate_input(inputs.X))
func motion_glidesecstoxy(inputs, _fields) -> void:
	var target_position = Vector2(check_number(evaluate_input(inputs.X)), -check_number(evaluate_input(inputs.Y)))
	var start_position = position
	
	# Try to get the duration, with a fallback
	var duration = 1.0  # Default duration
	duration = check_number((evaluate_input(inputs.SECS)))
	
	var elapsed_time = 0.0
	
	while position != target_position:
		# Yield control back to the engine for one frame
		await get_tree().process_frame
		
		# Update elapsed time
		elapsed_time += get_process_delta_time()
		var t = min(elapsed_time / duration, 1)
		
		# Update position using lerp
		position = start_position.lerp(target_position, t)
		
		# If we've reached the end of the animation, exit the loop
		if t >= 1.0:
			position = target_position
			break

	
func looks_gotofrontback(_inputs, fields) -> void:
	var type = fields.FRONT_BACK[0]
	match type:
		"front":
			$'../'.change_sprite_layer(1, self)
		"back":
			$'../'.change_sprite_layer(0, self)
func looks_costumenumbername(_inputs, fields) -> String:
	if fields.NUMBER_NAME[0] == "number":
		return str(costumes.frame+1)
	return "0"
func looks_nextcostume(_inputs, _fields) -> void:
	if costumes.frame == costumes.sprite_frames.get_frame_count("default")-1:
		costumes.frame=0
	else:
		costumes.frame+=1
	fix_costume()
func looks_switchcostumeto(inputs, _fields) -> void:
	costumes.frame=costume_names.find(evaluate_input(inputs.COSTUME))
	fix_costume()
func looks_size(_inputs, _fields) -> String:
	return str(scale.x*100)
func looks_costume(_inputs, fields) -> String:
	return fields.COSTUME[0]
func looks_seteffectto(inputs, fields) -> void:
	if fields.EFFECT[0] == "GHOST":
		modulate.a = 1-float(evaluate_input(inputs.VALUE))*.01
func looks_changeeffectby(inputs, fields) -> void:
	if fields.EFFECT[0] == "GHOST":
		modulate.a -= float(evaluate_input(inputs.CHANGE))*.01
func looks_cleargraphiceffects(_inputs, _fields) -> void: modulate = Color(1,1,1,1)
func looks_hide(_inputs, _fields) -> void:
	visible = false
func looks_show(_inputs, _fields) -> void:
	visible = true
func looks_setsizeto(inputs, _fields) -> void:
	scale = Vector2(1,1)*(float(evaluate_input(inputs.SIZE))*.01)
func looks_changesizeby(inputs, _fields) -> void:
	scale += Vector2(1,1)*(float(evaluate_input(inputs.CHANGE))*.01)
	
func event_broadcast(inputs, _fields) -> void:
	$'../'.broadcast(evaluate_input(inputs.BROADCAST_INPUT))
func event_broadcastandwait(inputs, _fields) -> void: # need to make work as intended
	$'../'.broadcast(inputs.BROADCAST_INPUT[1][2])

func sound_playuntildone(_inputs, _fields) -> void:
	pass
func sound_play(inputs, _fields) -> void: #Have to adjust this whenever I feel it it
	var sound = get_node_or_null(str(sounds.get(data.blocks[inputs.SOUND_MENU[1]].fields.SOUND_MENU[0])))
	if sound != null:
		sound.play()

func sensing_mousedown(_inputs, _fields) -> bool:
	return Input.is_action_pressed("mouse down")
func sensing_mousex(_inputs, _fields) -> String:
	return str(get_global_mouse_position().x)
func sensing_mousey(_inputs, _fields) -> String:
	return str(-get_global_mouse_position().y)
func sensing_timer(_inputs, _fields) -> String:
	return str($'../'.time_elapsed)
func sensing_resettimer(_inputs, _fields) -> void:
	$'../'.time_start = Time.get_unix_time_from_system()
func sensing_keypressed(inputs, _fields) -> bool:
	if Input.is_anything_pressed():
		var input = evaluate_input([3,inputs.KEY_OPTION])
		if input == "any":
			return true
		elif Input.is_action_pressed(input):
			return true
	return false
func sensing_keyoptions(_inputs, fields) -> String:
	return fields.KEY_OPTION[0]
func sensing_username(_inputs, _fields) -> String:
	return "GodotScratch"
#func sensing_touchingobject(_inputs, _fields):
#	return true

func data_changevariableby(inputs, fields) -> void:
	var variable = getvariable(fields.VARIABLE[1])
	variable[1] = str(check_number(variable[1])+check_number(evaluate_input((inputs.VALUE))))
func data_setvariableto(inputs, fields)  -> void:
	var variable = getvariable(fields.VARIABLE[1])
	variable[1] = evaluate_input((inputs.VALUE))

func execute_broadcast(broadcast) -> void:
	#for receivers in broadcast_receivers:
	if broadcast_receivers.has(broadcast):
		for receiver in broadcast_receivers[broadcast]:
			var thread = Thread.new()
			thread.start(start.bind(receiver,"",-1))
			thread_events.append(thread)
	pass

func getvariable(variable) -> Array:
	#print(variable)
	if data.variables.has(variable):
		return data.variables[variable]
	else:
		#print($'../Stage'.data.variables)
		#print(ba)
		return Stage.data.variables[variable]

func _exit_tree() -> void:
	for thread in thread_events:
		if thread.is_alive():
			thread.wait_to_finish()
	thread_events.clear()
