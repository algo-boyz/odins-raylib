package bass

import "core:fmt"

main :: proc() {
    Init(-1, 44100, 0, nil, nil)
    chan := StreamCreateFile(false, "../a-faded-folk-song.mp3", 0, 0, 0)
    ChannelPlay(chan, false)
    for true {
        pos := ChannelGetPosition(chan, 0)
        fmt.printf("pos: %d\n", pos)
    }
}