### Requirements ###
###  
* At least Lua 5.3 (http://www.lua.org/download.html)
* lua-zlib (https://github.com/brimworks/lua-zlib)
* lua-lfs (https://github.com/keplerproject/luafilesystem)
---

### Unpack a .PAK file ###
###  
```text
Usage:
    lua unpack.lua <INPUT.PAK> [OUTPUT_DIR [FILTER]]

List the content of a .PAK file:
    lua unpack.lua DATA.PAK

Unpack all files to the .\work directory:
    lua unpack.lua DATA.PAK .\work

Unpack only a specific file type:
    lua unpack.lua DATA.PAK .\work 13

Filters:
1  - MESH/MDL    2 - SKELETON    3 - DDS         4 - PNG/TGA/BMP
6  - OGG/WAV     9 - MATERIAL   10 - RAW        12 - IMAGESET
13 - TTF        15 - DAT        16 - LAYOUT     17 - ANIMATION
24 - PROGRAM    25 - FONTDEF    26 - COMPOSITOR 27 - FRAG/FX/HLSL/VERT
29 - PU         30 - ANNO       31 - SBIN       32 - WDAT
```
---

### Pack a directory into a .PAK file ###
###  
```text
Usage:
    lua pack.lua <INPUT_DIR> [OUTPUT_NAME]

Pack the content of the .\import directory into .\DATA7.PAK (default name):
    lua pack.lua .\import

Pack the content of the .\import directory into .\out\DATA8.PAK (specific name):
    lua pack.lua .\import .\out\DATA8.PAK
```
---

### Convert to .lua and back ###
###  
\*.DAT, \*.IMAGESET, \*.ANIMATION and \*.WDAT can be converted.
###  
```text
Usage:
    lua dat2lua.lua <INPUT.DAT> [OUTPUT.lua]
    lua lua2dat.lua <INPUT.lua> [OUTPUT.DAT]

List the content:
    lua dat2lua.lua .\work\MEDIA\15_GLOBALS.DAT

Convert the content of a .DAT file to a specific .lua file:
    lua dat2lua.lua .\work\MEDIA\15_GLOBALS.DAT .\work\MEDIA\15_GLOBALS.DAT.lua

Convert the content of a .lua file to the default OUT.DAT file in the current directory:
    lua lua2dat.lua .\work\MEDIA\15_GLOBALS.DAT.lua

Convert the content of a .lua file to a specific .DAT file:
    lua lua2dat.lua .\work\MEDIA\15_GLOBALS.DAT.lua .\import\MEDIA\15_GLOBALS.DAT
```
---

### Convert a .LAYOUT file to .lua and back ###
###  
Handles only \*.LAYOUT files.
###  
```text
Usage:
    lua layout2lua.lua <INPUT.LAYOUT>
    lua lua2layout.lua <INPUT.lua> <OUTPUT.LAYOUT>

Convert a .LAYOUT file to a .lua file (no output file necessary!):
    lua layout2lua.lua .\work\MEDIA\16_DERPTEST.LAYOUT

Convert a .lua file back into a .LAYOUT file (an output file *is* necessary!):
    lua lua2layout.lua .\work\MEDIA\16_DERPTEST.LAYOUT.lua .\import\MEDIA\16_DERPTEST.LAYOUT
```
---