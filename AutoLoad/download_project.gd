extends Button
var response
var ongoing_requests:int

@onready var ID:String
@onready var loading = $'../../Loading'
@onready var loadingbar = $'../../Loading/ProgressBar'



func _http_request_completed(_result, _response_code, _headers, body):
	print(body.get_string_from_utf8())
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	response = json.get_data()
	ongoing_requests-=1
	print("request")
	#print(body)
	#print(response)


func _on_pressed() -> void:
	ID = $'../ID'.text
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._http_request_completed)
	# Perform a GET request. The URL below returns JSON as of writing.
	ongoing_requests+=1
	var error = http_request.request("https://api.scratch.mit.edu/projects/"+ID)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
	else:
		$'../'.visible = false
		loading.visible = true
		await get_tree().create_timer(1).timeout
		ongoing_requests+=1
		error = http_request.request("https://api.scratch.mit.edu/projects/"+ID)
		await get_tree().create_timer(1).timeout
		http_request.download_file = "temp/project.json"
		print(response.has("project_token"))
		if not response.has("project_token"):
			print("Failed to download project!")
			$'../'.visible = true
			loading.visible = false
		else:
			ongoing_requests+=1
			error = http_request.request("https://projects.scratch.mit.edu/"+ID+"?token="+response.project_token, ["Content-Type: application/json"])
			print("https://projects.scratch.mit.edu/"+ID+"?token="+response.project_token)
			await get_tree().create_timer(3).timeout
			var download := []
			DirAccess.open("res://").make_dir("temp")
			await get_tree().create_timer(3).timeout
			
			var project = FileAccess.open("res://temp/project.json", FileAccess.READ)
			var json = project.get_as_text()
			json = JSON.parse_string(json)
			var progress_size:int
			loadingbar.max_value = progress_size
			for target in json.targets:
				for costume in target.costumes:
					download.append(costume.md5ext)
					loadingbar.max_value += 1
				for audio in target.sounds:
					download.append(audio.md5ext)
					loadingbar.max_value += 1
			
			#loadingbar.max_value
			var number:int = 0
			var current:int = 0
			for file in download:
				loadingbar.value += 1
				number+=1
				current+=1
				if current == 250:
					await get_tree().create_timer(2).timeout
					current=0
				var request = HTTPRequest.new()
				add_child(request)
				request.name = str(number)
				request.download_file = "temp/"+file
				ongoing_requests+=1
				request.request("https://cdn.assets.scratch.mit.edu/internalapi/asset/"+file+"/get/")
			print("done")
			await get_tree().create_timer(10).timeout
			for child in download.size():
				get_node(str(child+1)).queue_free()
				
			DirAccess.make_dir_absolute("res://sb3/")
			var writer = ZIPPacker.new()
			writer.open("res://sb3/"+ID+".sb3")
			download.append("project.json")
			for file in download:
				loadingbar.value += 1
				print(ongoing_requests)
				var asset = FileAccess.open("res://temp/"+file, FileAccess.READ)
				writer.start_file(file)
				writer.write_file(asset.get_buffer(asset.get_length()))
				writer.close_file()
				#await get_tree().process_frame
			writer.close()
			$'../../'.update_list()
			$'../'.visible = true
			loading.visible = false
