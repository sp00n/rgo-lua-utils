assert("Lua 5.3" == _VERSION)

local in_file = assert(arg[1], "\n\n[ERR] no input\n")
local out_file = arg[2] or "OUT.DAT"
local fix_file = arg[3]


-- binary write
local w
local function sint64(v) return string.pack("<i8", v) end
local function uint32(v) return string.pack("<I4", v) end
local function sint32(v) return string.pack("<i4", v) end
local function uint16(v) return string.pack("<H",  v) end
local function uint8(v)  return string.pack("B",   v) end
local function float(v)  return string.pack("f",   v) end


-- dictionaries
local dict_i = {name = "internal"}  -- from current file
local dict_e = {name = "external"}  -- from dict_ext
--local dict_p = {name = "parsed"}    -- from dict_parsed
local dict_t = {name = "types"}     -- from dict_type
local dict_f = {name = "fixes"}     -- from optional arg[3] (list_duped_ids_lang.lua)
local dict_u = {name = "unknown"}   -- TODO: collect all missed keys


local function read_tag(t, l)
    local tag = dict_e[t.n]
    if nil == tag then
        --print(t.n)
        tag = tonumber(t.n:sub(2, -1))
    end
    w:write(uint32(tag))

    if t.vars then
        w:write(uint32(#t.vars))
        
        for _, v in ipairs(t.vars) do
            local typ = dict_t[v.t]
            
            local name = dict_e[v.n]
            if not name then
                name = tonumber(v.n:sub(2))
            end
            
            local value
            if     typ == 1 then    -- INTEGER
                value = sint32(v.v)
            elseif typ == 2 then    -- FLOAT
                value = float(v.v)
            elseif typ == 5 then    -- STRING
                value = uint32(v.v)
            elseif typ == 6 then    -- BOOL
                value = uint32(v.v and 1 or 0)
            elseif typ == 7 then    -- INT64
                value = sint64(v.v)
            elseif typ == 8 then    -- TRANSLATE
                value = uint32(v.v)
            end
            assert(value)
            
            w:write(uint32(name))
            w:write(uint32(typ))
            w:write(value)
        end
    else
        w:write(uint32(0))
    end

    if t.tags then
        w:write(uint32(#t.tags))
        
        for _, v in ipairs(t.tags) do
            read_tag(v, l+1)
        end
    else
        w:write(uint32(0))
    end
end

-------------------------------------------------------------------------------

-- generate types dictionary
local d = dofile("dict_types.lua")
for i = 1, #d, 2 do
    dict_t[d[i+1]] = d[i]
end

-- generate external dictionary
d = dofile("dict_external.lua")
for i = 1, #d, 2 do
    dict_e[d[i+1]] = d[i]
end

--[=[ update external dictionary
d = dofile("dict_parsed.lua")
for i = 1, #d, 2 do
    dict_e[d[i+1]] = d[i]
end
]=]

-- generate fix dictionary
if fix_file then
    dict_f = dofile(fix_file)
end

-- generate internal dictionary
local LS = {}   -- [idx]=key
local L, content = dofile(in_file)

for k, v in pairs(L) do
    if type(k) == "number" then
        LS[v[1]] = k

        -- try to fix string
        local f = dict_f[k]
        if f then
            L[k][2] = f
        end
    end
end
-- check
assert(L.size == #LS)


w = assert(io.open(out_file, "w+b"))
w:write(uint8(6))

-- write dictionary
w:write(uint32(L.size))
for i = 1, #LS do
    local idx = LS[i]
    local str = L[idx][2]
    w:write(uint32(idx))
    w:write(uint16(#str))
    w:write(str)
end

read_tag(content, 0)

w:close()
