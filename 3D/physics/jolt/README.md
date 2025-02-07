## How to compile jolt for your os

```bash
git clone https://github.com/amerkoleci/joltc.git
```

linux:
```bash
clang -c src/joltc.c -o build/joltc.o -target amd64-linux -O3 -Iinclude/
clang -shared -o joltc.a build/joltc.o
```

macos:
```bash
clang -c src/joltc.c -o build/joltc.o -target arm64-apple-darwin -O3 -Iinclude/
clang -dynamiclib -o joltc.dylib build/joltc.o
==============================================
Undefined symbols for architecture arm64:
  "_JOLT_JobSystem_Create", referenced from:
      _jolt.main in jolt.o
ld: symbol(s) not found for architecture arm64
```

```bash
odin run .
```