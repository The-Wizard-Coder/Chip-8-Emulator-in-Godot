extends Node2D

@onready var grid: GridContainer = $Grid
@onready var chip8 = $Chip8
@onready var optionButton: OptionButton = $OptionButton

const GAME_ROMS = [
	{
		"id": 0,
		"title": "IBM (Demo)",
		"path": "res://roms/IBM Logo.ch8"
	},
	{
		"id": 1,
		"title": "Pong",
		"path": "res://roms/Pong (alt).ch8"
	},
	{
		"id": 2,
		"title": "Tetris",
		"path": "res://roms/tetris.ch8"
	},
	{
		"id": 3,
		"title": "Breakout",
		"path": "res://roms/breakout.c8"
	}
]

const KEYS = [
	"1", "2", "3", "4",
	"Q", "W", "E", "R",
	"A", "S", "D", "F",
	"Z", "X", "C", "V",
];

func _ready():
	init_buttons()
	init_gameroms()


func init_buttons():
	for i in range(len(KEYS)):		
		grid.add_child(create_button(KEYS[i]))

func init_gameroms():
	for game_rom in GAME_ROMS:
		optionButton.add_item(game_rom['title'], game_rom['id'])
	optionButton.selected = GAME_ROMS[0]['id']

func create_button(key):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(29, 29)
	btn.text = key
	btn.disabled=true
	return btn

func _on_load_rom_pressed():
	var fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.title = "Select Chip8 ROM file"
	fd.file_selected.connect(func(path):
		chip8.loadRom(path);
		fd.queue_free()
	)
	add_child(fd)
	fd.popup_centered()


func _on_option_button_item_selected(index):
	chip8.loadRom(GAME_ROMS[index]['path'])
