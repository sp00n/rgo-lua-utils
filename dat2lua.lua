if ( tonumber(_VERSION:match("%d+%.?%d?")) < 5.3 ) then
    error("You need to use at least LUA version 5.3!")
end

local in_file = assert(arg[1], "\n\n[ERR] no input\n")
local out_file = arg[2] or nil

-- binary read
local r
local function sint64(v) return string.unpack("<i8", v or r:read(8)) end
local function uint32(v) return string.unpack("<I4", v or r:read(4)) end
local function sint32(v) return string.unpack("<i4", v or r:read(4)) end
local function uint16(v) return string.unpack("<H",  v or r:read(2)) end
local function uint8(v)  return string.unpack("B",   v or r:read(1)) end
local function float(v)  return string.unpack("f",   v or r:read(4)) end


-- utils

-- Get the OS type
local function get_os_type()
     local dir_separator = package.config:sub(1,1)

     if ( dir_separator == "\\\\" or dir_separator == "\\") then
        return "win"
    elseif ( dir_separator == "/" ) then
        return "unix"
    end

    return "unknown"
end


-- Get the path the script is running in
local function get_script_path()
    local os_type = get_os_type()
    local path_str = debug.getinfo(2, "S").source:sub(2)

    if ( os_type == "win" ) then
        return path_str:match("(.*[/\\])") or ""
    elseif ( os_type == "unix" ) then
        return path_str:match("(.*/)") or "."
    end

    return ""
end


local function tab(level)
    return ((" "):rep(2 * level))
end

local output = {}
local function tprint(fmt, ...)
    if fmt == "+" then
        -- append ... to last element
        output[#output] = output[#output] .. ...
    else
        -- insert new element
        table.insert(output, fmt:format(...))
    end
end

local function errlog(err)
    io.stderr:write(err)
end


-- path
local script_path = get_script_path()

-- dictionaries
local dict_i = {name = "internal"}  -- from current file
local dict_e = {name = "external"}  -- from dict_external
local dict_t = {name = "types"}     -- from dict_type
local dict_u = {name = "missed"}
local d_use = 1                     -- usage index

local function dict(t, key)
    local k = t[key]

    if t.name == "internal" then
        if not k[4] then
            k[4] = d_use
            d_use = d_use + 1
        end
        k = k[2]
    end

    if nil == k then
        if not dict_u[key] then
            dict_u[key] = 1
            errlog("[WARN] unknown " .. t.name .. " key $" .. key .. "\n")
        end
        k = "$" .. key
    end
    return k
end


-- parse
local function read_var(level, idx)
    local nam = uint32()
    local typ = uint32()
    local val   -- get below

    local link
    if     typ == 1 then    -- int
        val = sint32()
    elseif typ == 2 then    -- float
        val = float()
--  elseif typ == 3 then    -- ???
--      val = ???()
--  elseif typ == 4 then    -- ???
--      val = ???()
    elseif typ == 5 then    -- string from internal dict
        val = uint32()
        dict_i[val][3] = "S"    -- mark basic string
        --val = dict(dict_i, val)
        link = " --> " .. dict(dict_i, val)
    elseif typ == 6 then    -- bool
        val = uint32()
        val = (val == 0) and "false" or "true"
    elseif typ == 7 then    -- int64
        val = sint64()
    elseif typ == 8 then    -- localized string
        val = uint32()
        dict_i[val][3] = "T"    -- mark localized string
        --val = dict(dict_i, val)
        link = " --> " .. dict(dict_i, val)
    else
        assert(false, "\n\n[ERR] unknown type " .. typ .. "\n")
    end

    nam = dict(dict_e, nam)
    typ = dict(dict_t, typ)

    tprint("%s{ n=\"%s\", t=\"%s\", v=%s },%s", tab(level), nam, typ, val, link or "")
end


local function read_tag(level, idx)
    local tag = uint32()
    tag = dict(dict_e, tag)

    -- tag name
    tprint("%sn=\"%s\"", tab(level), tag)

    -- vars
    local num_vars = uint32()
    if num_vars > 0 then
        tprint("+", ",")

        tprint("%svars = {", tab(level))

        for i = 1, num_vars do
            read_var(level+1, i)
        end

        tprint("%s}", tab(level))
    end

    -- inner tags
    local num_tags = uint32()
    if num_tags > 0 then
        tprint("+", ",")

        tprint("%stags = {", tab(level))

        for i = 1, num_tags do
            local level = level + 1
            if i == 1 then
                tprint("%s{    --%s[%d]", tab(level), tag, i)
            else
                tprint("%s}, { --%s[%d]", tab(level), tag, i)
            end

            read_tag(level+1, i)
        end
        -- close var
        tprint("%s}", tab(level+1))

        tprint("%s}", tab(level))
    end
end

--[[ main ]]--------------------------------------------------------------------

r = assert(io.open(in_file, "rb"))
assert(6 == uint8(), "\n\n[ERR] looks like not a DAT-file\n")

-- generate types dictionary
local d = dofile(script_path .. "dict_types.lua")
for i = 1, #d, 2 do
    dict_t[d[i]] = d[i+1]
end

-- generate external dictionary
d = dofile(script_path .. "dict_external.lua")
for i = 1, #d, 2 do
    dict_e[d[i]] = d[i+1]
end

-- generate internal dictionary
local count = uint32()

for i = 1, count do
    local idx = uint32()
    local len = uint16()
    -- use escapes
    local str = ("%q"):format(r:read(len))

    local d = dict_i[idx]
    if d ~= nil then
        if d ~= str then
            local fmt = "!!! COLLISION: idx=%d, old=%s, new=%s\n"
            io.stderr:write(fmt:format(idx, d, str))
        end
    end
    dict_i[idx] = { i, str }
end

d = nil


-- start parse
read_tag(1, 1)


r:close()

-------------------------------------------------------------------------------
local out = io.stdout

if out_file then
    out = assert(io.open(out_file, "w+"))
end


-- print internal dict (sorted by usage)
out:write("local L = {\n")

local t1 = {}   -- strings
local t2 = {}   -- translates
for k, v in pairs(dict_i) do
    if type(k) == "number" then -- skip name and size keys
        if     v[3] == "T" then
            table.insert(t2, {k, v})
        elseif v[3] == "S" then
            table.insert(t1, {k, v})
        else
            assert(false, v[3])
        end
    end
end
table.sort(t1, function (a, b) return (a[2][4] < b[2][4]) end)
table.sort(t2, function (a, b) return (a[2][4] < b[2][4]) end)

local fmt = "  [%d] = { %4d, %s },\n"
out:write("  size = " .. #t1 + #t2 .. ",\n")

out:write("  -- <TRANSLATE>\n")
for _, v in ipairs(t2) do
    out:write(fmt:format(v[1], v[2][1], v[2][2]))
end

out:write("  -- <STRING>\n")
for _, v in ipairs(t1) do
    out:write(fmt:format(v[1], v[2][1], v[2][2]))
end

out:write("}\n")
out:write(("--------"):rep(10))
out:write("\n")


-- print content
out:write("-- n -> name, t -> type, v -> value\n")
out:write("local content = {\n")
out:write(table.concat(output, "\n"))
out:write("\n}\nreturn L, content\n")


if out_file then
    out:close()
    print(string.format("Created %s", out_file))
end
