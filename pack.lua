if ( tonumber(_VERSION:match("%d+%.?%d?")) < 5.3 ) then
    error("You need to use at least LUA version 5.3!")
end

local zlib = require("zlib")
local lfs = require("lfs")

local in_path = assert(arg[1], "\n\n[ERR] no input\n")
local out_file = arg[2] or "./DATA7.PAK"
local filter = arg[3]   -- ".DAT" for example

if in_path:sub(-1) ~= "\\" then
    in_path = in_path .. "\\"
end


local entries = 0
local dirs = 0
local offset = 18

local header = {}
local w

local function uint32(i) return string.pack("<I", i) end
local function uint16(i) return string.pack("<H", i) end
local function uint8(i)  return string.pack("B",  i) end


local function scan(path)
    local count = 0
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            count = count + 1
        end
    end

    local t = {}
    local idx = 0

    for file in lfs.dir(path) do
        if file == "." or file == ".." then
            goto next_file
        end
        
        -- filter by extension
        local fullpath = path .. file
        local attr = lfs.attributes(fullpath)
        if attr.mode == "file" then
            if filter and filter ~= file:sub(-4) then
                goto next_file
            end
        end

        idx = idx + 1
        entries = entries + 1

        local crc, typ, off, size_orig, size, zsize, fname = 0, 8, 0, 0, 0, 0, ""

        if attr.mode == "directory" then
            fname = file .. "/"

        else
            for t, f in file:gmatch("(%d+)_(.+)") do
                typ = tonumber(t)
                fname = f
            end

            -- read & pack
            local r = assert(io.open(fullpath, "rb"))
            local data = r:read("*a")
            size_orig = r:seek()
            r:close()

            crc = zlib.crc32()(data)
            off = offset
            -- deflate only specific types
            if typ > 8 then
                local eof = false
                data, eof, size, zsize = zlib.deflate()(data, "finish")
                offset = offset + zsize + 8
            else
                size = size_orig
                offset = offset + size_orig + 8
            end
            -- append data
            w:write(uint32(size))
            w:write(uint32(zsize))
            w:write(data)
        end

        local itr = idx .. "\\" .. count
        print(("%9s %08X %2d %10d (%8d) %8d <- %8d %s"):format(itr, crc, typ, off, size_orig, size, zsize, fname))
        t[idx] = {crc, typ, #fname, fname:gsub("(.)", "%1\x00"), off, size_orig}

        ::next_file::
    end

    table.insert(header, t)
end


local function dir(path)
    for file in lfs.dir(path) do
        if file == "." or file == ".." then
            goto next_dir
        end

        local fullpath = path .. file
        local attr = lfs.attributes(fullpath)
        if attr.mode == "directory" then
            dirs = dirs + 1
            fullpath = fullpath .. "\\"
            local fp = fullpath:gsub(in_path, "")

            print()
            print(dirs, fp)

            fp = fp:gsub("\\", "/")
            table.insert(header, {#fp, fp:gsub("(.)", "%1\x00")})

            scan(fullpath)

            dir(fullpath)
        end
        ::next_dir::
    end
end


--[[ main ]]--------------------------------------------------------------------

w = assert(io.open(out_file, "w+b"))

w:write(uint16(5))  -- version
w:write(uint32(0))
w:write(uint32(0))  -- dummy filenames offset
w:write(uint32(0))  -- dummy filenames sizes
w:write(uint32(0))  -- unknown

-- append files
dir(in_path)

-- filenames data
local filenames_offset = w:seek()
w:write(uint32(entries))
w:write(uint32(dirs))

for k, v in ipairs(header) do
    if type(v[1]) == "number" then
        --print(table.concat(v, "\t"))
        w:write(uint16(v[1]))       -- #dirname
        w:write(v[2])               -- dirname (utf16le)
    else
        w:write(uint32(#v))         -- count
        for i, j in ipairs(v) do
            --print(table.concat(j, "\t"))
            w:write(uint32(j[1]))   -- crc
            w:write(uint8( j[2]))   -- type
            w:write(uint16(j[3]))   -- fname len
            w:write(       j[4])    -- fname
            w:write(uint32(j[5]))   -- offset
            w:write(uint32(j[6]))   -- orig size
        end
    end
end

local filenames_size = w:seek() - filenames_offset
w:close()

-- update
w = assert(io.open(out_file, "r+b"))
w:seek("set", 6)
w:write(uint32(filenames_offset))
w:write(uint32(filenames_size))
w:close()
