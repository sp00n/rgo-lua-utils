### Requirements ###

* Lua 5.3 (http://www.lua.org/download.html)
* lua-zlib (https://github.com/brimworks/lua-zlib)
* lua-lfs (https://github.com/keplerproject/luafilesystem)

### Unpack ###
````
usage:
    lua unpack.lua <INPUT.PAK> [OUTPUT_DIR [FILTER]]

list content:
    lua unpack.lua DATA.PAK

full unpack to .\work directory:
    lua unpack.lua DATA.PAK .\work

unpack only fonts:
    lua unpack.lua DATA.PAK .\work 13

filters:
1  - MESH/MDL    2 - SKELETON    3 - DDS         4 - PNG/TGA/BMP
6  - OGG/WAV     9 - MATERIAL   10 - RAW        12 - IMAGESET
13 - TTF        15 - DAT        16 - LAYOUT     17 - ANIMATION
24 - PROGRAM    25 - FONTDEF    26 - COMPOSITOR 27 - FRAG/FX/HLSL/VERT
29 - PU         30 - ANNO       31 - SBIN       32 - WDAT
````

### Pack ###
````
usage:
    lua pack.lua <INPUT_DIR> [OUTPUT_NAME]

pack content of .\work directory to .\DATA7.PAK (default name):
    lua pack.lua .\work

pack content of .\work directory to .\out\DATA8.PAK (specific name):
    lua pack.lua .\work .\out\DATA8.PAK
````
