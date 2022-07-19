if ( tonumber(_VERSION:match("%d+%.?%d?")) < 5.3 ) then
    error("You need to use at least LUA version 5.3!")
end

local in_file  = assert(arg[1], "\n\n[ERROR] no input file provided!\n")
local out_file = assert(arg[2], "\n\n[ERROR] no output file provided!\n")




local persistence = (function()
    -- Internal persistence library

    --[[ Provides ]]
    -- persistence.store(path, ...): Stores arbitrary items to the file at the given path
    -- persistence.load(path): Loads files that were previously stored with store and returns them

    --[[ Limitations ]]
    -- Does not export userdata, threads or most function values
    -- Function export is not portable

    --[[ License: MIT (see bottom) ]]

    local write, writeIndent, writers, refCount;

    persistence = {
        store = function (path, ...)
            local file, e = io.open(path, "w");
            if not file then
                return error(e);
            end
            local n = select("#", ...);
            
            -- Count references
            local objRefCount = {}; -- Stores reference that will be exported
            for i = 1, n do
                refCount(objRefCount, (select(i,...)));
            end;

            -- Export Objects with more than one ref and assign name
            -- First, create empty tables for each
            local objRefNames = {};
            local objRefIdx = 0;

            if #objRefCount > 0 then
                file:write("-- Persistent Data\n");
                file:write("local multiRefObjects = {\n");
            end;

          
            for obj, count in pairs(objRefCount) do
                if count > 1 then
                    objRefIdx = objRefIdx + 1;
                    objRefNames[obj] = objRefIdx;
                    file:write("{};"); -- table objRefIdx
                end;
            end;
            
            if #objRefCount > 0 then
                file:write("\n} -- multiRefObjects\n");
            end;
            


            -- Then fill them (this requires all empty multiRefObjects to exist)
            for obj, idx in pairs(objRefNames) do
                for k, v in pairs(obj) do
                    file:write("multiRefObjects["..idx.."][");
                    write(file, k, 0, objRefNames);
                    file:write("] = ");
                    write(file, v, 0, objRefNames);
                    file:write(";\n");
                end;
            end;


            -- Create the remaining objects
            for i = 1, n do
                file:write("local ".."obj"..i.." = ");
                write(file, (select(i,...)), 0, objRefNames);
                file:write("\n");
            end
            -- Return them
            if n > 0 then
                file:write("return obj1");
                for i = 2, n do
                    file:write(" ,obj"..i);
                end;
                file:write("\n");
            else
                file:write("return\n");
            end;
            if type(path) == "string" then
                file:close();
            end;
        end;

        load = function (path)
            local f, e;
            if type(path) == "string" then
                f, e = loadfile(path);
            else
                f, e = path:read('*a')
            end
            if f then
                return f();
            else
                return nil, e;
            end;
        end;
    }

    -- Private methods

    -- write thing (dispatcher)
    write = function (file, item, level, objRefNames)
        writers[type(item)](file, item, level, objRefNames);
    end;

    -- write indent
    writeIndent = function (file, level)
        for i = 1, level do
            file:write("\t");
        end;
    end;

    -- recursively count references
    refCount = function (objRefCount, item)
        -- only count reference types (tables)
        if type(item) == "table" then
            -- Increase ref count
            if objRefCount[item] then
                objRefCount[item] = objRefCount[item] + 1;
            else
                objRefCount[item] = 1;
                -- If first encounter, traverse
                for k, v in pairs(item) do
                    refCount(objRefCount, k);
                    refCount(objRefCount, v);
                end;
            end;
        end;
    end;

    -- Format items for the purpose of restoring
    writers = {
        ["nil"] = function (file, item)
            file:write("nil");
        end;
        ["number"] = function (file, item)
            file:write(tostring(item));
        end;
        ["string"] = function (file, item)
            file:write(string.format("%q", item));
        end;
        ["boolean"] = function (file, item)
            if item then
                file:write("true");
            else
                file:write("false");
            end
        end;
        ["table"] = function (file, item, level, objRefNames)
            local refIdx = objRefNames[item];
            if refIdx then
                -- Table with multiple references
                file:write("multiRefObjects["..refIdx.."]");
            else
                -- Single use table
                file:write("{\n");
                for k, v in pairs(item) do
                    writeIndent(file, level+1);
                    file:write("[");
                    write(file, k, level+1, objRefNames);
                    file:write("] = ");
                    write(file, v, level+1, objRefNames);
                    file:write(";\n");
                end
                writeIndent(file, level);
                file:write("}");
            end;
        end;
        ["function"] = function (file, item)
            -- Does only work for "normal" functions, not those
            -- with upvalues or c functions
            local dInfo = debug.getinfo(item, "uS");
            if dInfo.nups > 0 then
                file:write("nil --[[functions with upvalue not supported]]");
            elseif dInfo.what ~= "Lua" then
                file:write("nil --[[non-lua function not supported]]");
            else
                local r, s = pcall(string.dump,item);
                if r then
                    file:write(string.format("loadstring(%q)", s));
                else
                    file:write("nil --[[function could not be dumped]]");
                end
            end
        end;
        ["thread"] = function (file, item)
            file:write("nil --[[thread]]\n");
        end;
        ["userdata"] = function (file, item)
            file:write("nil --[[userdata]]\n");
        end;
    }

    return persistence;
end
)();





-- binary write
local w
local function uint64(v) return string.pack("<I8", v) end
local function sint64(v) return string.pack("<i8", v) end
local function uint32(v) return string.pack("<I4", v) end
local function sint32(v) return string.pack("<i4", v) end
local function uint16(v) return string.pack("<H",  v) end
local function uint8(v)  return string.pack("B",   v) end
local function float(v)  return string.pack("f",   v) end

local function get_hex(raw_value)
    return trim((raw_value:gsub(".", function(char) return string.upper(string.format("%02x ", char:byte())) end)))
end






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


function dump(o)
    if type(o) == "table" then
        local s = "{\n"
        for k, v in pairs(o) do
            if type(k) ~= "number" then k = "\""..k.."\"" end
            s = s .. "["..k.."] = " .. dump(v) .. ",\n"
        end
        return s .. "} "
    else
        return tostring(o)
    end
end


function tdump(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            tdump(v, indent+1)
        elseif type(v) == "boolean" then
            print(formatting .. tostring(v))      
        else
            print(formatting .. v)
        end
    end
end


function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end


--- Pads str to length len with char from right
string.lpad = function(str, len, char)
    if char == nil then char = " " end
    return string.rep(char, len - #str) .. str
end

-- string.explode(delimiter)
function explode(separator, str)
   local result, ll
   result = {}
   ll = 0
   if ( #str == 1 ) then
      return {str}
   end
   while true do
      l = string.find(str, separator, ll, true) -- find the next separator in the string
      if l ~= nil then -- if "not not" found then..
         table.insert(result, string.sub(str, ll, l-1)) -- Save it in our array.
         ll = l + 1 -- save just after where we found it for searching next time.
      else
         table.insert(result, string.sub(str, ll)) -- Save what's left in our array.
         break -- Break at end, as it should be, according to the lua manual.
      end
   end
   return result
end


local function indent(level, str)
    return ((" "):rep(4 * level)) .. str
end


local out = io.stdout

local function errlog(err)
    io.stderr:write(err)
end

-- Convert from hex data to binary / string
function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end



-- Path
local script_path = get_script_path()



-- Dictionaries
local sub_string_types, sub_string_types_int, sub_string_types_str_to_int, prop_entry_types, prop_entry_types_int, prop_entry_types_str_to_int, var_types_per_group = dofile(script_path .. "dict_layout.lua")



--[[ main ]]--------------------------------------------------------------------
print(string.format("Converting \"%s\" to \"%s\"...", in_file, out_file))


w = assert(io.open(out_file, "w+b"))

-- Load our table stored in the lua file
local LAYOUT = assert(persistence.load(in_file))



-- print("\n\n------ TABLE DUMP ------")
-- tdump(LAYOUT)



-- Write a property entry
local function write_property(property_key, var_type, value, level)
    local content_length  = 0

    -- print(indent(level, string.format("Property Key: %s", property_key)))
    -- print(indent(level, string.format("Value:        %s", value)))
    -- print(indent(level, string.format("var_type:     %s", var_type)))
    -- print(indent(level, string.format("Type(value):  %s", type(value))))

    -- print(indent(level+1, string.format("Entry content length before inserting property:    %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))
    -- print(indent(level+1, string.format("Property length before inserting:       %s", property_length)))


    if ( type(value) == "string" ) then
        -- print(indent(level+1, string.format("The entry value is a string, checking for sub length")))

        -- Strings in properties should always have a sub length
        local string_type_int
        if ( sub_string_types_str_to_int[property_key] ~= nil ) then
            string_type_int = sub_string_types_str_to_int[property_key]
        else
            string_type_int = tonumber(string.sub(property_key, 2))
        end

        -- Add the actual string length
        w:write(uint16(string.len(value)))
        content_length  = content_length  + 2

        -- Add the string itself
        w:write(value)
        content_length  = content_length  + string.len(value)
    
    -- The entry is a float or an int, check which one
    elseif ( var_type == "INT" ) then
        w:write(uint32(value))
        content_length  = content_length  + 4
    
    elseif ( var_type == "FLOAT" ) then
        w:write(float(value))
        content_length  = content_length  + 4
    end

    -- print(indent(level+1, string.format("Property length after inserting:        %s", property_length)))
    -- print(indent(level+1, string.format("Entry content length after inserting property val: %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))


    return content_length
end



-- Process a property entry
local function process_property(property_num_key, property_table, level)
    local content_length        = 0
    local added_content_length  = 0

    -- print(indent(level, string.format("Processing Property %s", property_num_key)))

    -- The properties have a table as a content
    -- Which again may or may not be a table
    for property_key, property_entry in pairs(property_table) do
        -- print(indent(level, string.format("Processing Property %s - %s", property_num_key, property_key)))

        property_length = 0

        -- Insert the property length, we need to come back to it after having processed the whole property
        local property_length_pos = w:seek()

        -- 2 bytes for the length (which is not counted for the property length itself)
        w:write(uint16(0))
        content_length = content_length + 2

        -- The property key is the first 4 bytes of the property entry
        local property_key_int

        if ( prop_entry_types_str_to_int[property_key] ~= nil ) then
            property_key_int = prop_entry_types_str_to_int[property_key]
        elseif ( sub_string_types_str_to_int[property_key] ~= nil ) then
            property_key_int = sub_string_types_str_to_int[property_key]
        else
            property_key_int = tonumber(string.sub(property_key, 2))
        end

        -- print(indent(level+1, string.format("Entry content length after getting property length:    %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

        w:write(uint32(property_key_int))
        property_length = property_length + 4
        content_length  = content_length  + 4

        -- print(indent(level+1, string.format("Entry content length after inserting property id:      %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

        -- The content of the entry is then the following bytes in groups of 4
        -- Or a float, or a string
        local var_type

        if ( type(property_entry) == "table" ) then
            for property_sub_key, property_sub_entry in ipairs(property_entry) do
                if ( var_types_per_group[property_key] ~= nil and var_types_per_group[property_key][property_sub_key] ~= nil ) then
                    var_type = var_types_per_group[property_key][property_sub_key]
                elseif ( type(property_sub_entry) == "string" ) then
                    var_type = "STRING"
                end

                if ( var_type ~= "INT" and var_type ~= "FLOAT" and var_type ~= "STRING" ) then
                    print()
                    print(string.format("property_key:     %s", property_key))
                    print(string.format("property_sub_key: %s", property_sub_key))
                    print(string.format("var_type:         %s", var_type))
                    error("var_type not matched (table)")
                end

                added_content_length = write_property(property_key, var_type, property_sub_entry, level+1)
                property_length = property_length + added_content_length
                content_length  = content_length  + added_content_length
            end
        else
            if ( var_types_per_group[property_key] ~= nil and var_types_per_group[property_key][1] ~= nil ) then
                var_type = var_types_per_group[property_key][1]
            elseif ( type(property_entry) == "string" ) then
                var_type = "STRING"
            end

            if ( var_type ~= "INT" and var_type ~= "FLOAT" and var_type ~= "STRING" ) then
                print()
                print(string.format("property_key:     %s", property_key))
                print(string.format("var_type:         %s", var_type))
                error("var_type not matched (single)")
            end

            added_content_length = write_property(property_key, var_type, property_entry, level+1)
            property_length = property_length + added_content_length
            content_length  = content_length  + added_content_length
        end

        local current_pos = w:seek()
        w:seek("set", property_length_pos)
        w:write(uint16(property_length))
        w:seek("set", current_pos)
    end

    return content_length
end



-- Process an entry
local function process_entry(entry_key, entry, level)
    -- print()
    -- print(indent(level, "---------------------------------------------"))
    -- print(indent(level, string.format("Processing entry %s", entry_key)))
    -- print(indent(level, string.format("Name: %s", entry.name)))
    -- print(indent(level, string.format("Identifier: %s", entry.identifier_hex)))

    local position_of_content_length = w:seek() -- Store the position for our content length so we can come back to it later
    local content_length  = 0
    local binary_string   = ""
    local name_length     = 0
    local num_properties  = 0

    -- print(indent(level, string.format("Entry content length at start:                                 %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- The first 4 bytes are the content length, including this indicator
    -- We don't know the length yet though
    w:write(uint32(0))
    content_length = content_length + 4

    -- print(indent(level, string.format("Entry content length after content length indicator:           %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- The identifier (4+8 byte)
    w:write(uint32(entry.identifier_type))
    content_length = content_length + 4

    w:write(uint64(entry.identifier))
    content_length = content_length + 8

    -- print(indent(level, string.format("Entry content length after identifier:                         %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- The length of the name entry (2 byte)
    -- May be 0
    name_length = string.len(entry.name)

    w:write(uint16(name_length))
    content_length = content_length + 2

    -- The name entry (x byte)
    w:write(entry.name)
    content_length = content_length + name_length

    -- print(indent(level, string.format("Entry content length after the name:                           %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- The number of properties (1 byte)
    num_properties = entry.properties ~= nil and #entry.properties or 0
    
    w:write(uint8(num_properties))
    content_length = content_length + 1

    -- print(indent(level, string.format("Entry content length before properties:                        %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- The properties
    if ( entry.properties ~= nil ) then
        for property_num_key, property_table in ipairs(entry.properties) do
            content_length = content_length + process_property(property_num_key, property_table, level+1)
        end
    end

    -- print(indent(level, string.format("Entry content length after properties:                         %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))


    -- Additional property data
    -- print(indent(level, "Checking for additional property data"))
    
    if ( entry.properties_additional_data ~= nil ) then
        -- The data is in hex format
        local hex_data = entry.properties_additional_data:gsub(" ", "")
        local additional_data_length  = string.len(hex_data) / 2    -- 2 hex characters per binary character

        -- print(indent(level+1, string.format("Additional property data found, length of data:    %s (hex: ", additional_data_length, string.upper(string.format("%02x", additional_data_length)))))

        -- Write the length of the following additional property data
        w:write(uint32(additional_data_length))
        content_length = content_length + 4

        -- Write the data to the file
        for byte in hex_data:gmatch "%x%x" do
            w:write(string.char(tonumber(byte, 16)))
        end
    
        content_length = content_length + additional_data_length
    
    -- No additional data
    else
        -- print(indent(level+1, string.format("No additional property data found")))
        w:write(uint32(0))
        content_length = content_length + 4
    end

    -- print(indent(level, string.format("Entry content length after additional property data:           %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))


    -- Sub entries
    -- print(indent(level, "Checking for sub entries"))
    -- print(indent(level+1, string.format("Number of sub entries found: %s", entry.entries ~= nil and #entry.entries or 0)))

    if ( entry.entries ~= nil ) then
        -- Write the amount of sub entries
        w:write(uint16(#entry.entries))
        content_length = content_length + 2
        -- print(indent(level, string.format("Entry content length after sub entries indicator:              %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

        for sub_entry_key, sub_entry in ipairs(entry.entries) do
            content_length = content_length + process_entry(sub_entry_key, sub_entry, level+1)
        end

    -- No sub entries
    else
        w:write(uint16(0))
        content_length = content_length + 2        
        -- print(indent(level, string.format("Entry content length after sub entries indicator:              %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))
    end


    -- print(indent(level, string.format("Entry content length finale value:                             %s (hex: %s)", content_length, string.upper(string.format("%02x", content_length)))))

    -- At this point we should have the length for this entry, write it down
    -- print()
    local current_pos = w:seek()
    w:seek("set", position_of_content_length)
    w:write(uint32(content_length))
    w:seek("set", current_pos)

    return content_length
end




-- ---------- Start of the file ----------
local total_content_length = 0

-- The file type
w:write(uint16(9))
total_content_length = total_content_length + 2

-- The next 4 bytes are the content size
-- We don't know it yet
-- It needs to be only set if there's additional data after the content
local total_content_size_position = w:seek()
w:write(uint32(0))
total_content_length = total_content_length + 4

-- Separator 00
w:write(uint8(0))
total_content_length = total_content_length + 1

-- The next 2 bytes are the number of main entries
local number_main_entries = LAYOUT.entries ~= nil and #LAYOUT.entries or 0
w:write(uint16(number_main_entries))
total_content_length = total_content_length + 2

print(string.format("    Found %s main entries", number_main_entries))


-- Here begin the main entries
for entry_key, entry in ipairs(LAYOUT.entries) do
    local entry_length = process_entry(entry_key, entry, 0)
    total_content_length = total_content_length + entry_length
end


-- There may be additional data
if ( LAYOUT.additional_data ~= nil ) then
    print(string.format("    Found additional data", number_main_entries))

    -- The data is in hex format
    local hex_data = LAYOUT.additional_data:gsub(" ", "")

    -- Write the data to the file, we don't need to know its length
    for byte in hex_data:gmatch "%x%x" do
        w:write(string.char(tonumber(byte, 16)))
    end


    -- We can now write the total content length
    w:seek("set", total_content_size_position)
    w:write(uint32(total_content_length))
end

local total_file_size = w:seek("end")
print(string.format("    Total content size: %s byte", total_content_length))
print(string.format("    Total file size:    %s byte", total_file_size))


w:close()

print(string.format("File \"%s\" written successfully!\n", out_file))