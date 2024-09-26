package tetris

import "core:fmt"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"


draw_grid :: proc() {
	for y in 0 ..< ROWS {
		for x in 0 ..= COLS {
			rl.DrawLine(i32(x * CELL_SIZE), 0, i32(x * CELL_SIZE), WIN_H, rl.DARKGRAY)
			rl.DrawLine(0, i32(y * CELL_SIZE), BOARD_W, i32(y * CELL_SIZE), rl.DARKGRAY)
		}
	}
}

draw_tetromino :: proc(tet: Tetromino, offset := rl.Vector2{}) {
	shape := Tetrominos[tet.type][tet.rot]
	for row, y in shape {
		for col, x in row {
			// i dont like too much indenting
			if col == 0 {continue}
			rl.DrawRectangle(
				i32(int(offset.x) + int(tet.x) * CELL_SIZE + x * CELL_SIZE),
				i32(int(offset.y) + int(tet.y) * CELL_SIZE + y * CELL_SIZE),
				CELL_SIZE,
				CELL_SIZE,
				Colors[tet.type],
			)
		}
	}
}

draw_board :: proc() {
	for row, y in board {
		for col, x in row {
			rl.DrawRectangle(
				i32(x * CELL_SIZE),
				i32(y * CELL_SIZE),
				CELL_SIZE,
				CELL_SIZE,
				Colors[col],
			)
		}
	}
}


add_tetromino :: proc() -> Tetromino {
	arr := []u8{'I', 'O', 'Z', 'S', 'T', 'J', 'L'}
	type := rand.choice(arr)
	return {x = 4, y = 0, rot = 0, type = type}
}


intersects :: proc(tet: Tetromino) -> Intersect {
	shape := Tetrominos[tet.type][tet.rot]
	for row, y in shape {
		for col, x in row {
			if col == 0 {continue}
			glob_x := int(tet.x) + x
			glob_y := int(tet.y) + y
			if glob_x >= COLS {
				return .Right
			} else if glob_x < 0 {
				return .Left
			} else if glob_y >= ROWS {
				return .Down
			} else if glob_y < 0 {
				return .Up
			}
			if board[glob_y][glob_x] != 0 {
				return .Other
			}
		}
	}
	return .None
}


check_below :: proc(tet: Tetromino) -> bool {
	shape := Tetrominos[tet.type][tet.rot]
	for row, y in shape {
		for col, x in row {
			if col == 0 {continue}
			if int(tet.y) + y + 1 >= ROWS {
				return true
			}
			if board[int(tet.y) + y + 1][int(tet.x) + x] != 0 {
				return true
			}
		}
	}
	return false
}


update_board :: proc(tet: Tetromino) {
	shape := Tetrominos[tet.type][tet.rot]
	for &row, y in shape {
		for col, x in row {
			if col == 0 {continue}
			board[int(tet.y) + y][int(tet.x) + x] = tet.type
		}
	}
	// clear filled row
	for &row, y in board {
		if slice.contains(row[:], 0) {continue}
		ordered_remove(&board, y)
		inject_at(&board, 0, [COLS]u8{})
		score += 10
		if best_score < score {
			best_score = score
		}
	}
}


freeze :: proc(tet: Tetromino) {
	update_board(tet)
	if !slice.all_of(board[0][:], 0) {
		state = .Over
	}
	current = next
	next = add_tetromino()
}


rush :: proc(tet: ^Tetromino) {
	for !check_below(tet^) {
		move_down(tet)
	}
	freeze(tet^)
}


move_down :: proc(tet: ^Tetromino) {
	tet.y += 1
	if intersects(tet^) == .Down {
		tet.y -= 1
	}
}

move_dir :: proc(tet: ^Tetromino, dir: MoveDir) {
	#partial switch dir {
	case .Left:
		tet.x -= 1
		if intersects(tet^) != .None {
			tet.x += 1
		}
	case .Right:
		tet.x += 1
		if intersects(tet^) != .None {
			tet.x -= 1
		}
	}
}

rotate :: proc(tet: ^Tetromino) {
	tet.rot = (tet.rot + 1) % u8(len(Tetrominos[tet.type]))
	#partial switch intersects(tet^) {
	case .Right:
		for intersects(tet^) != .None {
			tet.x -= 1
		}
	case .Left:
		for intersects(tet^) != .None {
			tet.x += 1
		}
	case .Other, .Down:
		tet.rot = (tet.rot - 1) % u8(len(Tetrominos[tet.type]))
	}
}

control :: proc(tet: ^Tetromino) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		rotate(tet)
	}

	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		move_dir(tet, .Right)
	} else if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		move_dir(tet, .Left)
	}
	if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
		move_repeat -= dt
		if move_repeat <= 0 {
			moving = .Right
		}
	} else if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
		move_repeat -= dt
		if move_repeat <= 0 {
			moving = .Left
		}
	} else {
		move_repeat = REPEAT_DELAY
		moving = .None
	}

	if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
		tick = fast_tick
	} else if rl.IsKeyUp(.S) || rl.IsKeyUp(.DOWN) {
		tick = DEFAULT_TICK
	}

	if rl.IsKeyPressed(.SPACE) {
		rush(tet)
	}
}


Intersect :: enum {
	Left,
	Right,
	Up,
	Down,
	Other,
	None,
}
MoveDir :: enum {
	Left,
	Right,
	None,
}

Colors := map[u8]rl.Color {
	'I' = rl.RED,
	'O' = rl.YELLOW,
	'L' = rl.BLUE,
	'J' = rl.PURPLE,
	'T' = rl.GREEN,
	'S' = rl.ORANGE,
	'Z' = rl.LIME,
}
Tetrominos := map[u8][][4][4]u8 {
	'I' =  {
		{{1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 0, 1, 0}, {0, 0, 1, 0}, {0, 0, 1, 0}, {0, 0, 1, 0}},
		{{0, 0, 0, 0}, {1, 1, 1, 1}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 1, 0, 0}, {0, 1, 0, 0}, {0, 1, 0, 0}, {0, 1, 0, 0}},
	},
	'O' = {{{1, 1, 0, 0}, {1, 1, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}},
	'L' =  {
		{{0, 0, 1, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{1, 0, 0, 0}, {1, 0, 0, 0}, {1, 1, 0, 0}, {0, 0, 0, 0}},
		{{0, 0, 0, 0}, {1, 1, 1, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 0, 0, 0}, {1, 1, 0, 0}, {0, 1, 0, 0}, {0, 1, 0, 0}},
	},
	'T' =  {
		{{0, 1, 0, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 1, 0, 0}, {0, 1, 1, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}},
		{{0, 0, 0, 0}, {1, 1, 1, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}},
		{{0, 1, 0, 0}, {1, 1, 0, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}},
	},
	'J' =  {
		{{1, 0, 0, 0}, {1, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{1, 1, 0, 0}, {1, 0, 0, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}},
		{{1, 1, 1, 0}, {0, 0, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 1, 0, 0}, {0, 1, 0, 0}, {1, 1, 0, 0}, {0, 0, 0, 0}},
	},
	'S' =  {
		{{0, 1, 1, 0}, {1, 1, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{1, 0, 0, 0}, {1, 1, 0, 0}, {0, 1, 0, 0}, {0, 0, 0, 0}},
	},
	'Z' =  {
		{{1, 1, 0, 0}, {0, 1, 1, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},
		{{0, 1, 0, 0}, {1, 1, 0, 0}, {1, 0, 0, 0}, {0, 0, 0, 0}},
	},
}

Tetromino :: struct {
	x:    i32,
	y:    i32,
	rot:  u8,
	type: u8,
}

State :: enum {
	Start,
	Going,
	Over,
}

CELL_SIZE :: 30
ROWS, COLS :: 20, 10
BOARD_W :: COLS * CELL_SIZE
WIN_W, WIN_H :: BOARD_W + CELL_SIZE * 5, ROWS * CELL_SIZE
DEFAULT_TICK :: 0.7
REPEAT_DELAY :: 0.2

tick, fast_tick: f32 = DEFAULT_TICK, 0.05
timer, fast_timer: f32

current: Tetromino
next: Tetromino

// dynamic rows makes clearing row much easier
// remove filled row and push empty one
board: [dynamic][COLS]u8

moving: MoveDir = .None
move_repeat: f32 = REPEAT_DELAY

score := 0
best_score := score
state := State.Start
dt: f32

main :: proc() {
	// by default dynamic arr has 0 len (obviously)
	board = make([dynamic][COLS]u8, ROWS)
	current = add_tetromino()
	next = add_tetromino()


	rl.InitWindow(WIN_W, WIN_H, "tetris")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	music := rl.LoadMusicStream("./res/music.mp3")
	fmt.println(music)
	rl.PlayMusicStream(music)
	defer rl.CloseAudioDevice()
	defer rl.UnloadMusicStream(music)

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		switch state {
		case .Going:
			timer += dt
			fast_timer += dt
			if timer > tick {
				timer = 0
				if check_below(current) {
					freeze(current)
				} else { 	// without else block next tetromino moves down before drawing it
					move_down(&current)
				}
			}
			if fast_timer > fast_tick {
				fast_timer = 0
				move_dir(&current, moving)
			}
			control(&current)
		case .Start:
			if rl.IsKeyPressed(.SPACE) {
				state = .Going
			}
		case .Over:
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.BLACK)
		draw_grid()
		draw_board()
		rl.DrawText("Score", BOARD_W + 28, 500, 32, rl.SKYBLUE)
		rl.DrawText(rl.TextFormat("%d", score), BOARD_W + 28, 540, 42, rl.RAYWHITE)
		rl.DrawText("Best", BOARD_W + 28, 400, 32, rl.GOLD)
		rl.DrawText(rl.TextFormat("%d", best_score), BOARD_W + 28, 440, 42, rl.RAYWHITE)
		switch state {
		case .Going:
			draw_tetromino(current)
			draw_tetromino(next, offset = {7 * CELL_SIZE, 3 * CELL_SIZE})
			rl.DrawText("Next", BOARD_W + 23, 30, 48, rl.RAYWHITE)
		case .Start, .Over:
			font_size: i32 = 32
			start_message: cstring = "Press Space\n\n\nto Start"
			message_w := rl.MeasureText(start_message, font_size)

			if state == .Over {
				over_message: cstring = "Game Over"
				message_w := rl.MeasureText(over_message, font_size)
				rl.DrawText(over_message, (BOARD_W - message_w) / 2, 50, font_size, rl.RAYWHITE)
				start_message = "Press Space\n\n\nto Restart"
				message_w = rl.MeasureText(start_message, font_size)
			}

			rl.DrawText(
				start_message,
				(BOARD_W - message_w) / 2,
				WIN_H / 2 - font_size,
				font_size,
				rl.RAYWHITE,
			)
		}
	}
}
