package main

import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

Mode :: enum {
    Editing,
    Playing
}

Layer :: enum {
    Background,
    Foreground
}

Game :: struct {
    level: ^Level,
    window: Window,
}

Tile :: struct {
    sprite_id: int,
    layer: Layer
}

AnimatedSprite :: struct {
    sprite_indexes: []int,
    secs_per_frame: f32,
    secs_since_last_frame: f32,
    current_frame: int
}

PlayerState :: enum {
    Idle,
    Walking,
    Jumping
}

Player :: struct {
    pos: [2]f32,
    size: [2]f32,
    vel: [2]f32,
    grounded: bool,
    state: PlayerState,
    animations: [PlayerState]AnimatedSprite
}

Level :: struct {
    player: Player,
    tiles: map[[2]int]Tile,
    width: int,
    height: int,
    spritesheet: rl.Texture
}

LevelEditor :: struct {
    window: Window,
    level: ^Level,
    level_window: Window,
    sprite_selector_window: Window,
    sprite_selector: SpriteSelector
}

game_create :: proc(level: ^Level, window: Window) -> Game {
    return Game {
        level = level,
        window = window
    }
}

level_editor_create :: proc(level: ^Level, window: Window) -> LevelEditor {
    level_win_size := [2]f32{f32(sprite_size*level.width*scale), f32(sprite_size*level.height*scale)}
    level_win := Window {
        pos = [2]f32{window.size.x/2 - level_win_size.x/2, 0},
        size = level_win_size
    }
    selector_window := Window {
        pos = {level_win.pos.x, window.size.y-f32(scale*level.spritesheet.height)},
        size = {f32(level.spritesheet.width*scale), f32(level.spritesheet.height*scale)}
    }
    selector := SpriteSelector {
        scale = scale,
        selection = 0,
        spritesheet = level.spritesheet
    }
    return LevelEditor {
        window = window,
        level = level,
        level_window = level_win,
        sprite_selector_window = selector_window,
        sprite_selector = selector
    }
}

level_create :: proc(width, height: int, spritesheet: rl.Texture) -> Level {
    return Level {
        player = Player{
            size={1, 1},
            grounded = true,
            state = .Idle,
            animations = {
                .Idle = animated_sprite_create({90}, 0.3),
                .Walking = animated_sprite_create({91, 92}, 0.3),
                .Jumping = animated_sprite_create({92}, 0.3),
            }
        },
        tiles = make(map[[2]int]Tile),
        width = width,
        height = height,
        spritesheet = spritesheet
    }
}

level_destroy :: proc(level: ^Level) {
    delete(level.tiles)
}

player_update :: proc(player: ^Player, level: ^Level, dt: f32) {
    animated_sprite_update(&player.animations[player.state], dt)
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

    if !player.grounded {
        player.state = .Jumping
    } else if player.vel.x != 0 {
        player.state = .Walking
    } else {
        player.state = .Idle
    }
}

position_is_in_level :: proc(level: Level, x, y: int) -> bool {
    return x >= 0 && y >= 0 && x < level.width && y < level.height;
}

tiles_around :: proc(level: Level, x, y: int) -> [dynamic]rl.Rectangle {
    tiles := make([dynamic]rl.Rectangle, allocator = context.temp_allocator)
    for i in x-1..=x+1 {
        for j in y-1..=y+1 {
            if position_is_in_level(level, i, j) {
                tile, ok := level.tiles[{i,j}]
                if ok && tile.layer == .Foreground {
                    append(&tiles, rl.Rectangle{f32(i), f32(j), 1, 1})
                }
            }
        }
    }
    return tiles
}

animated_sprite_create :: proc(sprite_indexes: []int, secs_per_frame: f32) -> AnimatedSprite {
    return AnimatedSprite {
        sprite_indexes = slice.clone(sprite_indexes),
        secs_per_frame = secs_per_frame,
        secs_since_last_frame = 0,
        current_frame = 0
    }
}

animated_sprite_destroy :: proc(sprite: ^AnimatedSprite) {
    delete(sprite.sprite_indexes)
}

animated_sprite_update :: proc(sprite: ^AnimatedSprite, dt: f32) {
    sprite.secs_since_last_frame += dt
    if sprite.secs_since_last_frame >= sprite.secs_per_frame {
        sprite.secs_since_last_frame = 0
        sprite.current_frame = (sprite.current_frame + 1) % len(sprite.sprite_indexes)
    }
}
