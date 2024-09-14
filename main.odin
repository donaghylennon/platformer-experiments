package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

win_width :: 1600
win_height :: 900

sprite_size :: 8
scale :: 4

level_width :: 30
level_height :: 15

Window :: struct {
    pos: [2]f32,
    size: [2]f32
}

SpriteSelector :: struct {
    scale: f32,
    selection: int,
    spritesheet: rl.Texture
}

main :: proc() {
    window := Window {
        pos = {0,0},
        size = {win_width, win_height}
    }
    rl.InitWindow(win_width, win_height, "Level Editor")
    defer rl.CloseWindow()
    rl.SetTargetFPS(144)
    rl.SetExitKey(.Q)

    spritesheet := rl.LoadImage("kenney_pico-8-platformer/Transparent/Tilemap/tilemap_packed.png")
    defer rl.UnloadImage(spritesheet)
    spritesheet_texture := rl.LoadTextureFromImage(spritesheet)
    defer rl.UnloadTexture(spritesheet_texture)

    level := level_create(level_width, level_height, spritesheet_texture)
    defer level_destroy(&level)
    level_win_size := [2]f32{f32(sprite_size*level.width*scale), f32(sprite_size*level.height*scale)}

    level_win := Window {
        pos = [2]f32{window.size.x/2 - level_win_size.x/2, 0},
        size = level_win_size
    }

    editor := level_editor_create(&level, window)
    game : Game

    mode := Mode.Editing
    editing_layer := Layer.Foreground

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        rl.BeginDrawing()
            switch mode {
                case .Playing:
                    draw_game(game)
                case .Editing:
                    draw_level_editor(editor)
            }
            rl.DrawFPS(10,10)

        rl.EndDrawing()

        if rl.IsKeyPressed(.M) {
            if mode == .Editing {
                mode = .Playing
                game = game_create(editor.level, editor.level_window)
            }
            else if mode == .Playing do mode = .Editing
        }

        switch mode {
        case .Editing:
            if rl.IsKeyPressed(.RIGHT) {
                editor.sprite_selector.selection += 1
                if editor.sprite_selector.selection == 150 {
                    editor.sprite_selector.selection = 0
                }
            } else if rl.IsKeyPressed(.LEFT) {
                editor.sprite_selector.selection -= 1
                if editor.sprite_selector.selection == -1 {
                    editor.sprite_selector.selection = 149
                }
            }
            if rl.IsKeyPressed(.C) {
                editor.level.tiles = {}
            }
            if rl.IsKeyPressed(.L) {
                if editing_layer == .Background do editing_layer = .Foreground
                else if editing_layer == .Foreground do editing_layer = .Background
            }

            if rl.IsMouseButtonDown(.LEFT) {
                pos := rl.GetMousePosition()
                if pos.x >= editor.level_window.pos.x && pos.y >= editor.level_window.pos.y && pos.x < editor.level_window.pos.x + editor.level_window.size.x && pos.y < editor.level_window.pos.y + editor.level_window.size.y {
                    col := int((pos.x - editor.level_window.pos.x) / (sprite_size*scale))
                    row := int((pos.y - editor.level_window.pos.y) / (sprite_size*scale))
                    if editor.sprite_selector.selection == 90 {
                        editor.level.player.pos = {f32(col), f32(row)}
                    } else {
                        editor.level.tiles[{col,row}] = Tile {
                            sprite_id = editor.sprite_selector.selection,
                            layer = editing_layer
                        }
                    }
                } else if pos.x >= editor.sprite_selector_window.pos.x && pos.y >= editor.sprite_selector_window.pos.y && pos.x < editor.sprite_selector_window.pos.x + editor.sprite_selector_window.size.x && pos.y < editor.sprite_selector_window.pos.y + editor.sprite_selector_window.size.y {
                    col := int((pos.x - editor.sprite_selector_window.pos.x) / (sprite_size*scale))
                    row := int((pos.y - editor.sprite_selector_window.pos.y) / (sprite_size*scale))
                    editor.sprite_selector.selection = row*int(editor.level.spritesheet.width/sprite_size) + col
                }
            }
        case .Playing:
            if rl.IsKeyDown(.A) {
                speed: f32 = game.level.player.grounded ? 25 : 15
                game.level.player.vel.x -= speed*dt
            } else if rl.IsKeyDown(.D) {
                speed: f32 = game.level.player.grounded ? 25 : 15
                game.level.player.vel.x += speed*dt
            }

            if rl.IsKeyDown(.SPACE) {
                if game.level.player.grounded {
                    game.level.player.vel.y -= 12
                    game.level.player.grounded = false
                }
            }
            player_update(&game.level.player, game.level, dt)
        }
    }
}

sprite_rect :: proc(selection: int) -> rl.Rectangle {
    return rl.Rectangle{f32(selection%15)*sprite_size, f32(selection/15)*sprite_size, sprite_size, sprite_size}
}

draw_game :: proc(game: Game) {
    rl.ClearBackground(rl.BLACK)
    draw_level(game.level^, game.window)

}

draw_level_editor :: proc(level_editor: LevelEditor) {
    selection_pos := [2]f32{0, win_height-sprite_size*scale}
    rl.ClearBackground(rl.BLACK)
    selection_rect := sprite_rect(level_editor.sprite_selector.selection)
    rl.DrawTexturePro(level_editor.sprite_selector.spritesheet, selection_rect, {selection_pos.x, selection_pos.y, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE) 
    draw_level(level_editor.level^, level_editor.level_window)

    draw_selector(level_editor.sprite_selector, level_editor.sprite_selector_window)
}

draw_level :: proc(level: Level, window: Window) {
    rl.DrawRectangleGradientV(i32(window.pos.x), i32(window.pos.y), i32(window.size.x), i32(window.size.y), {50, 50, 50, 255}, {100, 100, 100, 255})
    for pos, tile in level.tiles {
        rl.DrawTexturePro(level.spritesheet, sprite_rect(tile.sprite_id), {window.pos.x + f32(pos.x)*sprite_size*scale, window.pos.y + f32(pos.y)*sprite_size*scale, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE)
    }
    draw_player(level.player, level, window)
}

draw_player :: proc(player: Player, level: Level, window: Window) {
    pos := player.pos
    rl.DrawTexturePro(level.spritesheet, sprite_rect(90), {window.pos.x + pos.x*sprite_size*scale, window.pos.y + pos.y*sprite_size*scale, sprite_size*scale, sprite_size*scale}, {0,0}, 0, rl.WHITE)
}

draw_selector :: proc(selector: SpriteSelector, window: Window) {
    rl.DrawTextureEx(selector.spritesheet, window.pos, 0, selector.scale, rl.WHITE)
}
