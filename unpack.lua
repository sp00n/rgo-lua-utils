assert("Lua 5.3" == _VERSION)

local zlib = require("zlib")
local lfs = require("lfs")

local in_file = assert(arg[1], "\n\n[ERR] no input\n")
local out_path = arg[2] or "debug"
local filter = tonumber(arg[3]) or nil

local function fromutf16le(str)
    local s = string.gsub(str, "(.)\x00", "%1")
    return s
end

local function mkdir(name)
    local fullname = out_path .. "\\" .. name
    local ok, msg = lfs.mkdir(fullname)
    if true ~= ok and "File exists" ~= msg then
        assert(false, msg)
    end
end

local r
local function uint32() return string.unpack("<I", r:read(4)) end
local function uint16() return string.unpack("<H", r:read(2)) end
local function uint8()  return string.unpack("B",  r:read(1)) end

local function savefile(offset, fullname)
    r:seek("set", offset)
    local size = uint32()
    local zsize = uint32()
    local data
    if zsize > 0 then
        data = r:read(zsize)
        local stream = zlib.inflate()
        local eof, bytes_in, bytes_out
        data, eof, bytes_in, bytes_out = stream(data)
        assert(true == eof, "\n\n[ZLIB] eof ~= true\n")
        assert(zsize == bytes_in, "\n\n[ZLIB] bytes_in mismatch\n")
        assert(size == bytes_out, "\n\n[ZLIB] bytes_out mismatch\n")
    else
        data = r:read(size)
    end
    local w = assert(io.open(fullname, "w+b"))
    w:write(data)
    w:close()
end

--[[ main ]]--------------------------------------------------------------------

r = assert(io.open(in_file, "rb"))

-- check for big files support
local r_size = r:seek("end")
assert(-1 ~= r_size, "\n\nthis version of Lua doesn't support files larger than 2 Gb\n\n")
r:seek("set")

local ver = assert(5 == uint16())   -- RG - 1, RGO - 5
assert(0 == uint32())

local filename_offset = uint32()
local filename_size = uint32()
local unknown = uint32()


r:seek("set", filename_offset)
local entries = uint32()
local count = uint32()

if "debug" == out_path then
    print(("%d %d"):format(entries, count))
end

for i = 1, count do
    local len = uint16()
    local name = r:read(len * 2)

    local current_dir = fromutf16le(name):gsub("/", "\\")
    if "debug" == out_path then
        print(("\n%d/%d %s"):format(i, count, current_dir))
    else
        mkdir(current_dir)
    end

    local count2 = uint32()
    for j = 1, count2 do
        local crc = ("%08X"):format(uint32())
        local typ = uint8()
        local len = uint16()
        local name = r:read(len * 2)
        local offset = uint32()
        local size_orig = uint32()

        local fn = fromutf16le(name)
        fn = fn:gsub("/", "\\")

        local save_pos = r:seek()
        if "debug" == out_path then
            local size, zsize = 0, 0
            if 8 ~= typ then
                r:seek("set", offset)
                size = uint32()
                zsize = uint32()
            end
            local out = "%9s %s %2d %10d (%8d) %8d <- %8d %s"
            print(out:format(j .. "/" .. count, crc, typ, offset, size_orig, size, zsize, fn))
        else
            local fullname = current_dir .. fn
            if 8 == typ then
                print("[" .. fullname .. "]")
                mkdir(fullname)
            elseif nil == filter or typ == filter then
                print(fullname)
                fullname = out_path .. "\\" .. current_dir .. typ .. "_" .. fn
                savefile(offset, fullname)
            end
        end
        r:seek("set", save_pos)

        entries = entries - 1
    end
end

if entries > 0 then
    print("[WARN] left entries: " .. entries)
end

local left = r_size - r:seek()
if left > 0 then
    print("[WARN] bytes unreaded: " .. left)
end

r:close()
