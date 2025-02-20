# Bass audio library

Go to [bass audio website](https://www.un4seen.com/) 
download lib for your OS and place it in this directory:

```odin
main :: proc() {
    bass.Init(-1, 44100, 0, nil, nil)
    chan := bass.StreamCreateFile(false, "audio.mp3", 0, 0, 0)
    bass.ChannelPlay(chan, false)
    for true {
        pos := bass.ChannelGetPosition(chan, 0)
        fmt.printf("pos: %d\n", pos)
    }
}
```
