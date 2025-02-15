# [ufbx](https://github.com/ufbx/ufbx) bindings for Odin

- `/ufbx` simply copy into your project and import 
- `/deps` contains the C source to build `ufbx.lib` and license

From this directory, simply run `odin run .` You should see a spinning head.

## Compiling

On Windows, `ufbx.lib` is produced with:

```powershell
clang -c deps/ufbx.c -o deps/ufbx.obj -target x86_64-pc-windows-msvc -O3
lib /OUT:ufbx/ufbx.lib deps/ufbx.obj
rm deps/ufbx.obj
```

On Linux, `ufbx.a` is produced with:

```bash
clang -c deps/ufbx.c -o deps/ufbx.o -target amd64-linux -O3
clang -shared -o ufbx/ufbx.a deps/ufbx.o
rm deps/ufbx.o
```

On Mac, `ufbx.dylib` is produced with:

```bash
clang -c deps/ufbx.c -o deps/ufbx.o -target arm64-apple-darwin -O3
clang -dynamiclib -o ufbx/ufbx.dylib deps/ufbx.o
rm deps/ufbx.o
```

Ported from: [github.com/cshenton/odin-ufbx](https://github.com/cshenton/odin-ufbx)