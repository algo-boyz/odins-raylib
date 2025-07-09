package spatial

import "core:fmt"
import rl "vendor:raylib"
import "core:encoding/json"

MAX_SOUND_DISTANCE :: 10

Audio :: struct {
    sound: rl.Sound,
    position, _target: rl.Vector3,
    strength: f32,
    can_play: bool,
}

init :: proc(position: rl.Vector3, s_sound: rl.Sound) -> Audio {
    return Audio {
        sound = s_sound,
        position = position,
        strength = 1,
        can_play = true
    };
}

play :: proc(using self: ^Audio) {
    if (!rl.IsSoundPlaying(sound) && can_play) {
        rl.PlaySound(sound)
    }
}

update :: proc(position, target: rl.Vector3, sound: rl.Sound) {
    dist := rl.Vector3Distance(target, position);
    strength := 1.0 / (dist / MAX_SOUND_DISTANCE + 1.0);
    strength = clamp(strength, 0.0, 1.0); 

    rl.SetSoundVolume(sound, strength);
}
