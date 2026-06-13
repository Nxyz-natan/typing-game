extends CanvasLayer

@onready var audio_player = $audio_player
@onready var question_text = $Content/Questioninfo/Questiontext
@onready var question_image = $Content/Questioninfo/Imageholder/questionimage
@onready var buttons = [
	$Content/Questionholder/Buttonoption,
	$Content/Questionholder/Buttonoption2,
	$Content/Questionholder/Buttonoption3,
	$Content/Questionholder/Buttonoption4
]

var http_request: HTTPRequest
var image_request: HTTPRequest

var all_pokemon_names = []
var current_pokemon_name = ""
var score = 0
var round_number = 0
var total_rounds = 10

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_list_received)

	image_request = HTTPRequest.new()
	add_child(image_request)
	image_request.request_completed.connect(_on_image_received)

	question_text.text = "Loading..."
	fetch_pokemon_list()

func fetch_pokemon_list():
	http_request.request("https://pokeapi.co/api/v2/pokemon?limit=898")

func _on_list_received(result, response_code, headers, body):
	if response_code != 200:
		print("Error fetching list: ", response_code)
		return

	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var data = json.get_data()

	for p in data["results"]:
		all_pokemon_names.append(p["name"])

	http_request.request_completed.disconnect(_on_list_received)
	http_request.request_completed.connect(_on_pokemon_received)

	next_round()

func next_round():
	if round_number >= total_rounds:
		game_over()
		return

	for btn in buttons:
		btn.modulate = Color.WHITE
		btn.disabled = false
		btn.visible = true

	question_text.text = "Who's that Pokémon?"
	audio_player.play()
	question_image.texture = null

	var random_index = randi() % all_pokemon_names.size()
	current_pokemon_name = all_pokemon_names[random_index]

	var wrong_names = []
	while wrong_names.size() < 3:
		var wrong_index = randi() % all_pokemon_names.size()
		var wrong_name = all_pokemon_names[wrong_index]
		if wrong_name != current_pokemon_name and wrong_name not in wrong_names:
			wrong_names.append(wrong_name)

	var answers = wrong_names.duplicate()
	answers.append(current_pokemon_name)
	answers.shuffle()

	for i in range(buttons.size()):
		buttons[i].text = answers[i].capitalize()
		buttons[i].pressed.connect(_on_answer_pressed.bind(answers[i]))

	http_request.request("https://pokeapi.co/api/v2/pokemon/" + current_pokemon_name)

func _on_pokemon_received(result, response_code, headers, body):
	if response_code != 200:
		print("Error fetching pokemon: ", response_code)
		return

	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var data = json.get_data()

	var sprite_url = data["sprites"]["front_default"]
	if sprite_url == null:
		next_round()
		return

	image_request.request(sprite_url)

func _on_image_received(result, response_code, headers, body):
	if response_code != 200:
		print("Error fetching image: ", response_code)
		return

	var image = Image.new()
	image.load_png_from_buffer(body)

	var img = ImageTexture.create_from_image(image).get_image()
	img.convert(Image.FORMAT_RGBA8)
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var pixel = img.get_pixel(x, y)
			if pixel.a > 0.1:
				img.set_pixel(x, y, Color(0, 0, 0, pixel.a))

	question_image.texture = ImageTexture.create_from_image(img)
	question_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	question_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_answer_pressed(answer: String):
	for btn in buttons:
		btn.disabled = true
		if btn.pressed.is_connected(_on_answer_pressed):
			btn.pressed.disconnect(_on_answer_pressed)

	for btn in buttons:
		if btn.text.to_lower() == current_pokemon_name:
			btn.modulate = Color.GREEN
		elif btn.text.to_lower() == answer:
			btn.modulate = Color.RED

	if answer == current_pokemon_name:
		score += 1
		question_text.text = "Correct! It was " + current_pokemon_name.capitalize() + "!"
	else:
		question_text.text = "Wrong! It was " + current_pokemon_name.capitalize() + "!"

	reveal_pokemon()

	round_number += 1
	await get_tree().create_timer(2.0).timeout
	next_round()

func reveal_pokemon():
	image_request.request_completed.disconnect(_on_image_received)
	image_request.request_completed.connect(_on_reveal_received)
	image_request.request("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/" + str(get_pokemon_id()) + ".png")

func get_pokemon_id() -> int:
	return all_pokemon_names.find(current_pokemon_name) + 1

func _on_reveal_received(result, response_code, headers, body):
	if response_code != 200:
		return

	var image = Image.new()
	image.load_png_from_buffer(body)
	question_image.texture = ImageTexture.create_from_image(image)

	image_request.request_completed.disconnect(_on_reveal_received)
	image_request.request_completed.connect(_on_image_received)

func game_over():
	question_text.text = "Game Over! Score: " + str(score) + "/" + str(total_rounds)
	question_image.texture = null
	for btn in buttons:
		btn.visible = false
