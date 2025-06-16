
```bash
    $ make -C ".../odin/bin/vendor/miniaudio/src"

    $ odin build . -build-mode:obj -extra-linker-flags:"-framework CoreAudio -framework CoreFoundation"

```

Convert mp3 to ogg:
```bash
    $ ffmpeg -i luis-humanoid_march-of-the-troopers.mp3 luis-humanoid_march-of-the-troopers.ogg
```
ogg -> 1.3MB vs mp3 -> 3.1MB