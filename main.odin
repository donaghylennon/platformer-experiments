package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

win_width :: 1600
win_height :: 900

sprite_size :: 8
scale :: 4

level_width :: 30
level_height :: 15

Mode :: enum {
    Editing,
    Playing
}

Level :: struct {
    tiles: [level_height][level_width]int,
    spritesheet: rl.Texture
}

LevelWindow :: struct {
    pos: [2]f32,
    size: [2]f32
}

SpriteSelector :: struct {
    pos: [2]f32,
    size: [2]f32,
    scale: f32,
    selection: int,
    spritesheet: rl.Texture
}

Player :: struct {
    pos: [2]f32,
    size: [2]f32,
    vel: [2]f32,
    grounded: bool,
    spritesheet: rl.Texture
}

main :: proc() {
    rl.InitWindow(win_width, win_height, "Level Editor")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)
    rl.SetExitKey(.Q)

    spritesheet := rl.LoadImage("kenney_pico-8-platformer/Default/Tilemap/tilemap_packed.png")
    defer rl.UnloadImage(spritesheet)
    spritesheet_texture := rl.LoadTextureFromImage(spritesheet)
    defer rl.UnloadTexture(spritesheet_texture)

    level := Level{spritesheet = spritesheet_texture}
    level_win_size := [2]f32{sprite_size*len(level.tiles[0])*scale, sprite_size*len(level.tiles)*scale}
    level_win := LevelWindow {
        pos = [2]f32{win_width/2 - level_win_size.x/2, 0},
        size = level_win_size
    }

    selection := 0
    selection_pos := [2]f32{0, win_height-sprite_size*scale}

    selector := SpriteSelector {
        pos = {level_win.pos.x, f32(win_height-scale*spritesheet_texture.height)},
        size = {f32(spritesheet.width*scale), f32(spritesheet.height*scale)},
        scale = scale,
        selection = 0,
        spritesheet = spritesheet_texture
    }

    player := Player{size={1, 1}, spritesheet = spritesheet_texture, grounded = true}

    mode := Mode.Editing

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK)
            selection_rect := sprite_rect(selection)
            rl.DrawTexturePro(spritesheet_texture, selection_rect, {selection_pos.x, selection_pos.y, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE) 
            draw_level(level, level_win)
            draw_player(player, level_win)

            if mode == .Editing {
                draw_selector(selector)
            }
            rl.DrawFPS(10,10)

        rl.EndDrawing()

        if rl.IsKeyPressed(.M) {
            if mode == .Editing do mode = .Playing
            else if mode == .Playing do mode = .Editing
        }

        switch mode {
        case .Editing:
            if rl.IsKeyPressed(.RIGHT) {
                selection += 1
                if selection == 150 {
                    selection = 0
                }
            } else if rl.IsKeyPressed(.LEFT) {
                selection -= 1
                if selection == -1 {
                    selection = 149
                }
            }
            if rl.IsKeyPressed(.C) {
                level.tiles = {}
            }

            if rl.IsMouseButtonDown(.LEFT) {
                pos := rl.GetMousePosition()
                if pos.x >= level_win.pos.x && pos.y >= level_win.pos.y && pos.x < level_win.pos.x + level_win.size.x && pos.y < level_win.pos.y + level_win.size.y {
                    col := int((pos.x - level_win.pos.x) / (sprite_size*scale))
                    row := int((pos.y - level_win.pos.y) / (sprite_size*scale))
                    if selection == 90 {
                        player.pos = {f32(col), f32(row)}
                    } else {
                        level.tiles[row][col] = selection
                    }
                } else if pos.x >= selector.pos.x && pos.y >= selector.pos.y && pos.x < selector.pos.x + selector.size.x && pos.y < selector.pos.y + selector.size.y {
                    col := int((pos.x - selector.pos.x) / (sprite_size*scale))
                    row := int((pos.y - selector.pos.y) / (sprite_size*scale))
                    selection = row*int(spritesheet.width/sprite_size) + col
                }
            }
        case .Playing:
            if rl.IsKeyDown(.A) {
                speed: f32 = player.grounded ? 25 : 15
                player.vel.x -= speed*dt
            } else if rl.IsKeyDown(.D) {
                speed: f32 = player.grounded ? 25 : 15
                player.vel.x += speed*dt
            }

            if rl.IsKeyDown(.SPACE) {
                if player.grounded {
                    player.vel.y -= 12
                    player.grounded = false
                }
            }
            player_update(&player, &level, dt)
        }
    }
}

sprite_rect :: proc(selection: int) -> rl.Rectangle {
    return rl.Rectangle{f32(selection%15)*sprite_size, f32(selection/15)*sprite_size, sprite_size, sprite_size}
}

draw_level :: proc(level: Level, window: LevelWindow) {
    for row, y in level.tiles {
        for cell, x in row {
            rl.DrawTexturePro(level.spritesheet, sprite_rect(cell), {window.pos.x + f32(x)*sprite_size*scale, window.pos.y + f32(y)*sprite_size*scale, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE)
        }
    }
}

draw_player :: proc(player: Player, window: LevelWindow) {
    pos := player.pos
    rl.DrawTexturePro(player.spritesheet, sprite_rect(90), {window.pos.x + pos.x*sprite_size*scale, window.pos.y + pos.y*sprite_size*scale, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE)
}

draw_selector :: proc(selector: SpriteSelector) {
    rl.DrawTextureEx(selector.spritesheet, selector.pos, 0, selector.scale, rl.WHITE)
}

player_update :: proc(player: ^Player, level: ^Level, dt: f32) {
    unit_scale: f32 = sprite_size*scale
    gravity: f32 = 18
    max_vel: f32 = 300
    player.vel.y += gravity*dt

    player.pos.x = player.pos.x + player.vel.x*dt

    top_left: [2]int
    player_rect: rl.Rectangle
    top_left = linalg.to_int(linalg.floor(player.pos))
    player_rect = rl.Rectangle{player.pos.x, player.pos.y, player.size.x, player.size.y}
    for rect in tiles_around(level^, top_left.x, top_left.y) {
        if rl.CheckCollisionRecs(rect, player_rect) {
            if player.vel.x > 0 {
                player.pos.x = rect.x - player.size.x
                player.vel.x = 0
            }
            if player.vel.x < 0 {
                player.pos.x = rect.x + rect.width
                player.vel.x = 0
            }
        }
    }
    player.pos.y = player.pos.y + player.vel.y*dt

    top_left = linalg.to_int(linalg.floor(player.pos))
    player_rect = rl.Rectangle{player.pos.x, player.pos.y, player.size.x, player.size.y}
    for rect in tiles_around(level^, top_left.x, top_left.y) {
        if rl.CheckCollisionRecs(rect, player_rect) {
            if player.vel.y > 0 {
                player.pos.y = rect.y - player.size.y
                player.vel.y = 0
                player.grounded = true
            }
            if player.vel.y < 0 {
                player.pos.y = rect.y + rect.height
                player.vel.y = 0
            }
        }
    }

    if math.abs(player.vel.x) > max_vel {
        player.vel.x = math.sign(player.vel.x)*max_vel
    }

    if player.vel.y < 0 {
        player.grounded = false
    }

    if player.grounded {
        player.vel.x -= 3*player.vel.x*dt
        if math.abs(player.vel.x) < 0.1 {
            player.vel.x = 0
        }
    }
}

position_is_in_level :: proc(level: Level, x, y: int) -> bool {
    return x >= 0 && y >= 0 && x < len(level.tiles[0]) && y < len(level.tiles);
}

tiles_around :: proc(level: Level, x, y: int) -> [dynamic]rl.Rectangle {
    tiles := make([dynamic]rl.Rectangle, allocator = context.temp_allocator)
    for i in x-1..=x+1 {
        for j in y-1..=y+1 {
            if position_is_in_level(level, i, j) {
                if level.tiles[j][i] > 0 {
                    append(&tiles, rl.Rectangle{f32(i), f32(j), 1, 1})
                }
            }
        }
    }
    return tiles
}
