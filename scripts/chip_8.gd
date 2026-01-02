extends ColorRect

const CPU_HZ := 500        # instructions per second
const TIMER_HZ := 60

const START_ADDRESS = 0x200; # memory location where rom instruction starts
const FONT_SET_START_ADDRESS = 0x50; # memory location where font set starts

const pixelScale = 4.5;

const VIDEO_WIDTH = 64;
const VIDEO_HEIGHT = 32;

# Below is Font set representation for character F 
# 11110000
# 10000000
# 11110000
# 10000000
# 10000000
# These are basically used as sprite to print character on screen
const FONT_SET = [
	0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
	0x20, 0x60, 0x20, 0x20, 0x70, # 1
	0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
	0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
	0x90, 0x90, 0xF0, 0x10, 0x10, # 4
	0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
	0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
	0xF0, 0x10, 0x20, 0x40, 0x40, # 7
	0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
	0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
	0xF0, 0x90, 0xF0, 0x90, 0x90, # A
	0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
	0xF0, 0x80, 0x80, 0x80, 0xF0, # C
	0xE0, 0x90, 0x90, 0x90, 0xE0, # D
	0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
	0xF0, 0x80, 0xF0, 0x80, 0x80  # F
]

var registers = []; # V0 to VF (size: 16)
var memory = []; # Store processing data (size: 4096)
var index = 0;  # Index Register: Holds memory address in use
var pc = 0; # Program Counter: Next executing instruction
var stack = [] # Call stack for holding PC values during CALL (size: 16) 
var sp = 0; # Stack Pointer
var keys = [] # keyboard buttons (size: 16)
var video = [] # Screen Graphics (size: 64 * 32)
var opcode = 0; # Store current opcode 

# Chip8 Timer (ticks down from set CPU rate down to 0)
var delayTimer = 0;
var soundTimer = 0;

# Status
var isROMLoaded = false;
var needsRedraw = false;

# To store leftover time between frames
var cpu_accumulator := 0.0
var timer_accumulator := 0.0

func initChip8():
	# Initialize Arrays
	init_array(registers, 16, 0);
	init_array(memory, 4096, 0);
	init_array(stack, 16, 0);
	init_array(keys, 16, 0);
	init_array(video, 64 * 32, 0);

	# init vars
	opcode = 0;
	index = 0;
	sp = 0;
	delayTimer = 0;
	soundTimer = 0;
	pc = START_ADDRESS  # Point PC to start address of ROM instruction
	
	# Load fontset into memory (starts at 0x50 for chip8)
	for i in range(FONT_SET.size()):
		memory[FONT_SET_START_ADDRESS + i] = FONT_SET[i];

	# Some state variable to control Godot
	isROMLoaded = false;
	needsRedraw = false;

func loadRom(path: String):
	if FileAccess.file_exists(path):
		# Reset Chip8 state
		initChip8();
		
		# We will read byte data from ROM file 
		var file = FileAccess.open(path, FileAccess.READ)
		var offset = 0
		
		# Read a byte from the file and store it in the memory
		while ! file.eof_reached():
			# Offset the instruction storage by starting address (0x200)
			memory[START_ADDRESS + offset] = file.get_8()
			offset += 1
		file.close()
		isROMLoaded = true;
		print("Loaded ROM from path: " + path)
	else:
		isROMLoaded = false;
		print("ROM path not found: " + path)

func canRun():
	return isROMLoaded;

func init_array(array: Array, length: int, value: int = 0):
	# Initialize array
	if len(array) != length:
		array.resize(length)
	for i in range(length):
		array[i] = value

func randByte():
	# Random byte value
	return randi() % 256

func execute_opcode():
	if !canRun():
		return

	# Fetch
	opcode = (memory[pc] << 8) | memory[pc + 1];
	
	# increment Pc to next instruction
	pc += 2
	
	# Decode & Execute
	match (opcode & 0xF000):
		0x0000:
			match (opcode & 0x0FFF):
				0x00E0: OP_00E0()
				0x00EE: OP_00EE()
				_: OP_1NNN() # SYS addr (Used by older implementation)
		0x1000: OP_1NNN()
		0x2000: OP_2NNN()
		0x3000: OP_3XNN()
		0x4000: OP_4XNN()
		0x5000: OP_5XY0()
		0x6000: OP_6XNN()
		0x7000: OP_7XNN()
		0x8000:
			match (opcode & 0x000F):
				0x0000: OP_8XY0()
				0x0001: OP_8XY1()
				0x0002: OP_8XY2()
				0x0003: OP_8XY3()
				0x0004: OP_8XY4()
				0x0005: OP_8XY5()
				0x0006: OP_8XY6()
				0x0007: OP_8XY7()
				0x000E: OP_8XYE()
				_: print("Unsupported opcode: " + str(opcode))
		0x9000: OP_9XY0()
		0xA000: OP_ANNN()
		0xB000: OP_BNNN()
		0xC000: OP_CXNN()
		0xD000: OP_DXYN()
		0xE000:
			match opcode & 0x00FF:
				0x009E: OP_EX9E()
				0x00A1: OP_EXA1()
				_: print("Unsupported opcode: " + str(opcode))
		0xF000:
			match opcode & 0x00FF:
				0x0007: OP_FX07()
				0x000A: OP_FX0A()
				0x0015: OP_FX15()
				0x0018: OP_FX18()
				0x001E: OP_FX1E()
				0x0029: OP_FX29()
				0x0033: OP_FX33()
				0x0055: OP_FX55()
				0x0065: OP_FX65()
				_: print("Unsupported opcode: " + str(opcode))
		_: print("Unsupported opcode: " + str(opcode))
	
	# Redraw if stuff changed
	if needsRedraw:
		needsRedraw = false;
		queue_redraw()

func _ready():
	randomize()
	# loadRom("res://roms/tetris.ch8")
	loadRom("res://roms/IBM Logo.ch8")

func _process(delta):
	if !canRun():
		return
	
	# --- CPU timing ---
	cpu_accumulator += delta
	var cpu_step = 1.0 / CPU_HZ
	
	var cycles := 0
	while cpu_accumulator >= cpu_step and cycles < 50:
		execute_opcode()
		cpu_accumulator -= cpu_step
		cycles += 1
	
	# --- Timer timing (60 Hz) ---
	timer_accumulator += delta
	var timer_step := 1.0 / TIMER_HZ
	
	while timer_accumulator >= timer_step:
		if delayTimer > 0:
			delayTimer -= 1
		if soundTimer > 0:
			soundTimer -= 1
			if soundTimer == 1:
				# beep trigger
				pass
		timer_accumulator -= timer_step

func _draw():
	for i in range(video.size()):
		var x		= i % VIDEO_WIDTH
		@warning_ignore("integer_division")
		var y		= int(i / VIDEO_WIDTH)
		var pixelColor	= Color.BLACK

		if (video[i] == 1):
			pixelColor = Color.WEB_GREEN

		draw_rect(Rect2(x * pixelScale, y * pixelScale, pixelScale, pixelScale), pixelColor)

func _input(event):
	if event is InputEventKey:
		for i in range(16):
			var key = "%X" % i
			if event.is_action("key" + key):
				keys[i] = 1 if event.pressed else 0
				break

### Opcode functions

func OP_00E0():
	# CLS
	# Clear the display by setting video buffers to zero
	init_array(video, len(video), 0)

func OP_00EE():
	# RET
	# Return from a subroutine.
	# The top of the stack contains address of next instruction of the CALL statement, so we place it back to PC. 
	# so we can put that back into the PC.
	if sp == 0:
		push_error("Stack underflow")
		return
	sp -= 1;
	pc = stack[sp];

func OP_1NNN():
	# JP addr
	# Jump to location nnn
	# The interpreter sets the program counter to nnn.
	# 0x0FFF is a mask to fetch the last 3 nibbles from the opcode
	pc = opcode & 0x0FFF;

func OP_2NNN():
	# CALL addr
	# Call subroutine at nnn.

	# Get new CALL address at opcode
	var address = opcode & 0x0FFF;
	
	if sp >= 16:
		push_error("Stack overflow")
		return
	
	# Push Current PC value into stack
	stack[sp] = pc;
	
	# Stack pointer updated to next empty location
	sp += 1;
	
	# Move PC to new CALL address
	pc = address

func OP_3XNN():
	# SE Vx, byte
	# Skip next instruction if Vx = NN.

	# Extract value of Vx from opcode
	var Vx = (opcode & 0x0F00) >> 8
	var byte = opcode & 0x00FF
	
	if registers[Vx] == byte:
		# PC incremented by 2 as each instruction is 2 bytes long
		pc += 2

func OP_4XNN():
	# SNE Vx, byte
	# Skip next instruction if Vx != kk.
	# Similar to OP_3XNN, but change condition
	var Vx = (opcode & 0x0F00) >> 8
	var byte = opcode & 0x00FF

	if registers[Vx] != byte:
		pc += 2

func OP_5XY0():
	# SE Vx, Vy
	# Skip next instruction if Vx = Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4

	if registers[Vx] == registers[Vy]:
		pc += 2

func OP_6XNN():
	# LD Vx, byte
	# Set Vx = kk.
	var Vx = (opcode & 0x0F00) >> 8
	var byte = opcode & 0x00FF
	registers[Vx] = byte;

func OP_7XNN():
	# ADD Vx, byte
	# Set Vx = Vx + kk.
	var Vx = (opcode & 0x0F00) >> 8
	var byte = opcode & 0x00FF
	# Do the & to avoid overfitting register value above 1 byte
	registers[Vx] = (registers[Vx] + byte) & 0xFF;

func OP_8XY0():
	# LD Vx, Vy
	# Set Vx = Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	registers[Vx] = registers[Vy]

func OP_8XY1():
	# OR Vx, Vy
	# Set Vx = Vx OR Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	registers[Vx] = registers[Vx] | registers[Vy]

func OP_8XY2():
	# AND Vx, Vy
	# Set Vx = Vx AND Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	registers[Vx] = registers[Vx] & registers[Vy]

func OP_8XY3():
	# XOR Vx, Vy
	# Set Vx = Vx XOR Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	registers[Vx] = registers[Vx] ^ registers[Vy]

func OP_8XY4():
	# Set Vx = Vx + Vy, set VF = carry.
	# The values of Vx and Vy are added together. If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	
	var sum = registers[Vx] + registers[Vy]
	
	if sum > 255:
		registers[0xF] = 1;
	else:
		registers[0xF] = 0;
	
	# Store the lowest 8 bits of the result
	registers[Vx] = sum & 0x00FF

func OP_8XY5():
	# Set Vx = Vx - Vy, set VF = NOT borrow.
	# If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4

	if registers[Vx] > registers[Vy]:
		registers[0xF] = 1
	else:
		registers[0xF] = 0
	
	registers[Vx] = (registers[Vx] - registers[Vy]) & 0xFF

func OP_8XY6():
	# Set Vx = Vx SHR 1.
	# If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
	var Vx = (opcode & 0x0F00) >> 8
	
	# Save LSB in VF
	registers[0xF] = (registers[Vx] & 0x1)
	
	# Divide by 2
	registers[Vx] = (registers[Vx] >> 1) & 0x00FF

func OP_8XY7():
	# SUBN Vx, Vy
	# Set Vx = Vy - Vx, set VF = NOT borrow.
	# If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4

	if registers[Vy] > registers[Vx]:
		registers[0xF] = 1
	else:
		registers[0xF] = 0
	
	registers[Vx] = (registers[Vy] - registers[Vx]) & 0x00FF

func OP_8XYE():
	# SHL Vx {, Vy}
	# Set Vx = Vx SHL 1.
	# If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
	var Vx = (opcode & 0x0F00) >> 8
	
	# Save MSB in VF
	registers[0xF] = (registers[Vx] & 0x80) >> 7
	
	# Multiply by 2
	registers[Vx] = (registers[Vx] << 1 ) & 0x00FF

func OP_9XY0():
	# SNE Vx, Vy
	# Skip next instruction if Vx != Vy.
	var Vx = (opcode & 0x0F00) >> 8
	var Vy = (opcode & 0x00F0) >> 4
	
	if registers[Vx] != registers[Vy]:
		pc += 2

func OP_ANNN():
	# LD I, addr
	# Set I = NNN.
	index = opcode & 0x0FFF

func OP_BNNN():
	# JP V0, addr
	# Jump to location NNN + V0.
	var address = (opcode & 0x0FFF);
	pc = registers[0] + address;

func OP_CXNN():
	# RND Vx, byte
	# Set Vx = random byte AND kk.
	var Vx = (opcode & 0x0F00) >> 8;
	var byte = opcode & 0x00FF;
	registers[Vx] = randByte() & byte;

func OP_DXYN():
	# TODO: Understand the code
	# DRW Vx, Vy, nibble
	# Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
	# Sprite is 8 pixels wide
	var Vx = (opcode & 0x0F00) >> 8;
	var Vy = (opcode & 0x00F0) >> 4;
	var nibble = opcode & 0x000F;
	
	# Wrap if going beyond screen boundaries
	var xPos = registers[Vx] % VIDEO_WIDTH;
	var yPos = registers[Vy] % VIDEO_HEIGHT;

	# Set VF = 0
	registers[0xF] = 0;
	
	for row in range(0, nibble):
		# Get the Nth byte of sprite data, counting from the memory address in the I register 
		var spriteByte = memory[index + row]
		
		# Each sprite is 8 pixel wide
		for col in range(0, 8):
			var spritePixel = spriteByte & (0x80 >> col) 

			# If pixel needs to be set
			if spritePixel != 0:
				var totalX = (xPos + col) % VIDEO_WIDTH
				var totalY = (yPos + row) % VIDEO_HEIGHT
				# Index in graphics array
				var screenPixel = (totalY * VIDEO_WIDTH) + totalX;
				
				if video[screenPixel] == 1:
					registers[0xF] = 1
				
				video[screenPixel] = video[screenPixel] ^ 1

	needsRedraw = true;

func OP_EX9E():
	# SKP Vx
	# Skip next instruction if key with the value of Vx is pressed.
	var Vx = (opcode & 0x0F00) >> 8;
	var key = registers[Vx];
	if keys[key]:
		pc += 2

func OP_EXA1():
	# SKNP Vx
	# Skip next instruction if key with the value of Vx is not pressed.
	var Vx = (opcode & 0x0F00) >> 8;
	var key = registers[Vx];
	if !keys[key]:
		pc += 2

func OP_FX07():
	# LD Vx, DT
	# Set Vx = delay timer value.
	var Vx = (opcode & 0x0F00) >> 8;
	registers[Vx] = delayTimer;

func OP_FX0A():
	# LD Vx, K
	# Wait for a key press, store the value of the key in Vx.
	var Vx = (opcode & 0x0F00) >> 8;
	
	for i in range(0, 16):
		if keys[i]:
			registers[Vx] = i
			return

	# We wait for key press by decrementing PC, so it goes back to same command again
	pc = pc - 2

func OP_FX15():
	# LD DT, Vx
	# Set delay timer = Vx.
	var Vx = (opcode & 0x0F00) >> 8;
	delayTimer = registers[Vx];

func OP_FX18():
	# LD ST, Vx
	# Set sound timer = Vx.
	var Vx = (opcode & 0x0F00) >> 8;
	soundTimer = registers[Vx];

func OP_FX1E():
	# ADD I, Vx
	# Set I = I + Vx.
	var Vx = (opcode & 0x0F00) >> 8;
	index = index + registers[Vx];

func OP_FX29():
	# LD F, Vx
	# Set I = location of sprite for digit Vx.
	var Vx = (opcode & 0x0F00) >> 8;
	var digit = registers[Vx];
	
	# font located at 0x50, and each font character is 5 bytes
	index = FONT_SET_START_ADDRESS + (5 * digit);

func OP_FX33():
	# LD B, Vx
	# Store BCD representation of Vx in memory locations I, I+1, and I+2.
	
	# The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
	
	var Vx = (opcode & 0x0F00) >> 8;
	var value = registers[Vx];
	
	# ones place
	memory[index + 2] = value % 10;
	value = int(value / 10);
	# tens place
	memory[index + 1] = value % 10;
	value = int(value / 10);
	# hundreads place
	memory[index] = value % 10;

func OP_FX55():
	# LD [I], Vx
	# Store registers V0 through Vx in memory starting at location I.
	var Vx = (opcode & 0x0F00) >> 8;
	for i in range(0, Vx + 1):
		memory[index + i] = registers[i];

func OP_FX65():
	# LD Vx, [I]
	# Read registers V0 through Vx from memory starting at location I.
	var Vx = (opcode & 0x0F00) >> 8;
	for i in range(0, Vx + 1):
		registers[i] = memory[index + i];

func OP_NULL():
	pass
