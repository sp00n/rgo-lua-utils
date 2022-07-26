if ( tonumber(_VERSION:match("%d+%.?%d?")) < 5.3 ) then
    error("You need to use at least LUA version 5.3!")
end

local in_file = assert(arg[1], "\n\n[ERROR] no input file provided\n")
local out_file = arg[2] or in_file .. ".lua"



-- binary read
local r
local function uint64(v) return string.unpack("<I8", v or r:read(8)) end
local function sint64(v) return string.unpack("<i8", v or r:read(8)) end
local function uint32(v) return string.unpack("<I4", v or r:read(4)) end
local function sint32(v) return string.unpack("<i4", v or r:read(4)) end
local function uint16(v) return string.unpack("<H",  v or r:read(2)) end
local function uint8(v)  return string.unpack("B",   v or r:read(1)) end
local function float(v)  return string.unpack("f",   v or r:read(4)) end

local function get_hex(raw_value)
    return trim((raw_value:gsub(".", function(char) return string.upper(string.format("%02x ", char:byte())) end)))
end

local function hex64()  local raw_val = r:read(8); r:seek("cur", -8); return get_hex(raw_val); end
local function hex32()  local raw_val = r:read(4); r:seek("cur", -4); return get_hex(raw_val); end
local function hex16()  local raw_val = r:read(2); r:seek("cur", -2); return get_hex(raw_val); end
local function hex8()   local raw_val = r:read(1); r:seek("cur", -1); return get_hex(raw_val); end




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


-- Output
-- local out = io.stdout
local out = {}
function out.write(v)
end


local function errlog(err)
    io.stderr:write(err)
end



-- Path
local script_path = get_script_path()


-- Dictionaries
local sub_string_types, sub_string_types_int, sub_string_types_str_to_int, prop_entry_types, prop_entry_types_int, prop_entry_types_str_to_int, var_types_per_group = dofile(script_path .. "dict_layout.lua")



--[[ main ]]--------------------------------------------------------------------

r = assert(io.open(in_file, "rb"))

local file_type = uint16()

if 9 ~= file_type then
    error("\n\n[ERROR] Not a LAYOUT file!\n")
end





-- The output table
local OUTPUT = {
    ["entries"] = {},
}


local current
local hex_value
current = r:seek()
out:write(string.format("current file position: %i\n", current))

-- Get the value for the string content
-- If the value is 0, all of the file is content
-- If the value is > 0, there may be some other data beyond this, which is still to be identified (filler? meta?)

current = r:seek()
out:write(string.format("--- Getting the content length ---\n"))
out:write(string.format("...current file position: %i\n", current))


local total_content_length_raw = r:read(4)
local total_content_length_hex = get_hex(total_content_length_raw)
local total_content_length_int = uint32(total_content_length_raw)
out:write(string.format("The total content length is: %i bytes (hex: %s)\n", total_content_length_int, total_content_length_hex))

if ( total_content_length_int == 0 ) then
    out:write(string.format("    The length is zero, which means that the whole file is content\n"))
else
    out:write(string.format("    The length is not zero, which means that there is some other data beyond the content (metadata? trash?)\n"))
end


-- Get the number of main entries
r:seek("cur", 1) -- proceed by 1 byte
current = r:seek()
out:write(string.format("--- Getting the number of main entries ---\n"))
out:write(string.format("...current file position: %i\n", current))


local number_of_entries_main_raw = r:read(2)
local number_of_entries_main_hex = get_hex(number_of_entries_main_raw)
local number_of_entries_main_int = uint16(number_of_entries_main_raw)

out:write(string.format("The number of main entries: %i (hex: %s)\n", number_of_entries_main_int, number_of_entries_main_hex))



-- Get a property entry
local function get_property_entry(j, level)
    level = level or 1
    local indent = string.rep(" ", level*4)

    out:write("\n")
    out:write(indent .. string.format("------- PROPERTY ENTRY %d -------\n", j))
    
    local start_position = r:seek()
    local prop_entry     = {}
    local length_raw     = r:read(2)
    local length_hex     = get_hex(length_raw)
    local length         = uint16(length_raw)
    local val_raw        = r:read(length)
    local val_hex        = get_hex(val_raw)
    local end_position   = r:seek()


    out:write(indent .. "The content length for this property entry is: " .. string.lpad(string.format("%s bytes (hex: %s)", length, length_hex), 21) .. "\n")
    -- out:write(indent .. string.format("The hex value is: %s\n", val_hex))
    -- out:write(indent .. string.format("raw value is: %s\n", val_raw))
    
    -- Modify the remaining content byte length from the parent function
    remaining_entry_byte_length = remaining_entry_byte_length - 2   -- uint16
    remaining_entry_byte_length = remaining_entry_byte_length - length


    -- The property entry may consist of a string value, which has a 4 byte long identifier, another length value, and then the string
    -- C5 2D 62 00       6434245    .mdl
    -- 45 6E 6B 00       7040581    STRING
    -- 00 0A B6 67    1739983360    .dat, .mdl (only in the "Glows" section, but even there not always)
    -- 7D F4 A1 E4    3835819133    .dds
    -- 4B 83 C8 C6    3335029579    .dds
    -- E7 DC AF BE    3199196391    rgba color value
    -- 24 EB 87 C2    3263687460    RIGHT, LEFT, FREE

    -- The identifier
    r:seek("set", start_position + 2)
    local check_for_sub_string_raw    = r:read(4)
    local check_for_sub_string_hex    = get_hex(check_for_sub_string_raw)
    local _, check_for_sub_string_int = pcall(uint32, check_for_sub_string_raw)
    
    -- out:write(indent .. string.format("check_for_sub_string_raw: %s\n", check_for_sub_string_raw))
    -- out:write(indent .. string.format("check_for_sub_string_hex: %s\n", check_for_sub_string_hex))
    -- out:write(indent .. string.format("check_for_sub_string_int: %s\n", check_for_sub_string_int))


    local possible_second_length_position = r:seek()


    -- The possible int value for the next entry (read 4 bytes)
    local check_second_value_raw    = r:read(4)
    local check_second_value_hex    = get_hex(check_second_value_raw)
    local _, check_second_value_int = pcall(uint32, check_second_value_raw)


    -- The possible length value for a string entry (read 2 bytes)
    r:seek("set", possible_second_length_position)
    local check_second_length_raw    = r:read(2)
    local check_second_length_hex    = get_hex(check_second_length_raw)
    local _, check_second_length_int = pcall(uint16, check_second_length_raw)


    -- out:write(indent .. string.format("check_second_length_hex: %s\n", check_second_length_hex))
    -- out:write(indent .. string.format("check_second_length_int: %s\n", check_second_length_int))


    -- If the second length is exactly 6 less than the original length, then we have a string sub entry
    -- There may be exceptions though for some entries, which randomly match the +6
    -- For example 08 00  XX XX XX XX  02 00 00 00  would be match, although it's just an integer value of 2
    -- Also, the string can have a length of zero, then the total length is 06 00, followed by 4 bytes, and then a 00 00
    -- It seems that only strings have values that are not dividable by 4, but they also can have a length that can be divided by 4
    local check_second_length_one = ( ( check_second_length_int > 0 and check_second_length_int + 6 == length ) or ( length == 6 and check_second_length_int == 0 ) )



    -- We need to filter out the entries where the second "length" is actually just an int value that by chance matches the original content length
    -- So far this only seems to be the case for entries with a length of 08 00 and a value of 02 00 XX XX
    -- We assume that the 4 byte value is the same as the 2 byte value as a filter (02 00 == 02 00 00 00)
    -- length == 8 and check_second_length_int == 2
    local check_second_length_two = ( check_second_length_one and check_second_length_int ~= check_second_value_int )


    -- Old, unreliable check
    -- local check_second_length_two = ( check_second_length_one and ( check_for_sub_string_hex ~= "ED AA 94 3A" and check_for_sub_string_hex ~= "EE AA 94 3A" and check_for_sub_string_hex ~= "AD 7D 0F BE" ) )  -- These entries can be 08 00 XX XX XX XX 02 00 00 00
    

    if ( check_second_length_one and check_second_length_two ) then
        out:write(indent .. "There's a second length with:             " .. string.lpad(string.format("%s bytes (hex: %s)", check_second_length_int, check_second_length_hex), 21) .. "\n")

        -- Try to match the string type
        local sub_string_type = sub_string_types[check_for_sub_string_hex] or "$" .. check_for_sub_string_int
        local string_raw      = r:read(check_second_length_int)
        local string_readable = string.gsub(string_raw, "%c", ".")
        local string_hex      = get_hex(string_raw)

        -- out:write(indent .. string.format("val_raw:           %s\n", val_raw))
        -- out:write(indent .. string.format("string_length_hex: %s\n", check_second_length_hex))
        -- out:write(indent .. string.format("string_length:     %s\n", check_second_length_int))
        -- prop_entry[sub_string_type] = string_raw

        prop_entry["id"]     = sub_string_type
        prop_entry["values"] = string_raw

        out:write(indent .. string.format("Found a sub string\n"))
        out:write(indent .. string.format("    type: %s\n", sub_string_type))
        out:write(indent .. string.format("    hex:  %s\n", check_for_sub_string_hex))
        out:write(indent .. string.format("    int:  %i\n", check_for_sub_string_int))
        out:write(indent .. string.format("    raw:  %s\n", string_readable))
        out:write(indent .. string.format("    hex:  %s\n", string_hex))

    -- The entry contains no string
    else
        local readable_raw = string.gsub(val_raw, "%c", ".")
        
        out:write(indent .. string.format("Trying to split into groups of int/float/etc\n"))
        -- out:write(indent .. string.format("Raw Value:  %s\n", val_raw))
        out:write(indent .. string.format("Raw Value: %s\n", readable_raw))
        out:write(indent .. string.format("Hex Value: %s\n", val_hex))


        local hex_table  = {}

        for x=1, #val_raw do
            local cur_char = string.sub(val_raw, x, x)
            local cur_byte = string.byte(val_raw, x, x)
            local cur_hex  = string.upper(string.format("%02x", cur_byte))
            hex_table[x]  = cur_hex
        end

        -- 11 22 33 44 55 66 77
        -- 12345678901234567890
        local first_four_raw = string.sub(val_raw, 1, 5)
        local first_four_hex = string.sub(val_hex, 0, 11)
        local first_four_int = string.unpack("<I4", first_four_raw)
        local prop_entry_type = prop_entry_types[first_four_hex] or "UNKNOWN"
        local prop_entry_type_from_int = prop_entry_types_int[first_four_int] or "$" .. first_four_int

        if ( prop_entry_type ~= nil and prop_entry_type ~= "UNKNOWN" ) then
            out:write("\n")
            -- out:write(indent .. string.format("    Found the entry type in the first 4 bytes\n"))
            out:write(indent .. string.format("    4-byte hex group 1:       %s\n", first_four_hex))
            out:write(indent .. string.format("    Sub Entry Type:           %s\n", prop_entry_type))

            -- COORDINATES, ROTATIONS, HARDPOINT_NUMBER_1, HARDPOINT_NUMBER_2
        end



        -- We assume that the first 4 bytes are the identifier for this entry
        -- We may or may not know what it is
        -- prop_entry[prop_entry_type_from_int] = {}
        prop_entry["id"] = prop_entry_type_from_int

        -- Try to divide into groups of 4
        if ( length % 4 == 0 ) then
            local num_groups = #hex_table / 4

            -- If the we have more than one entry, use a table
            -- Otherwise directly set the value
            if ( num_groups > 2 ) then
                prop_entry["values"] = {}
            end


            for x = 0, num_groups-1 do
                -- If we found a sub entry type, we can skip the first group
                if ( x == 0 and prop_entry_type ~= nil and prop_entry_type ~= "UNKNOWN" ) then
                    goto continue   -- LUA's way of a continue statement, see the ::continue:: label at the end of the loop
                end

                local hex_string_display = hex_table[(x * 4) + 1] .. " " .. hex_table[(x * 4) + 2] .. " " ..  hex_table[(x * 4) + 3] .. " " .. hex_table[(x * 4) + 4]
                local string_raw_group   = string.sub(val_raw, (x * 4) + 1, (x * 4) + 4)

                out:write("\n")
                out:write(indent .. string.format("    4-byte hex group %i:       %s\n", x+1, hex_string_display))
                -- out:write(indent .. string.format("    4-byte raw string:                 %s\n", string_raw_group))

                local int32_unsigned_from_raw = string.unpack("<I4", string_raw_group)
                local float_from_raw          = string.unpack("f", string_raw_group)

                out:write(indent .. string.format("    32bit integer (unsigned): %i\n", int32_unsigned_from_raw))
                out:write(indent .. string.format("    float:                    %f (string: %s)\n", float_from_raw, float_from_raw))

                -- if ( x > 0 and var_types_per_group[prop_entry_type_from_int] ~= nil ) then
                if ( x > 0 ) then
                    local var_type = var_types_per_group[prop_entry_type_from_int] and var_types_per_group[prop_entry_type_from_int][x] or nil
                    local use_var 
                    
                    if ( var_type == "FLOAT" ) then
                        use_var = float_from_raw
                    elseif ( var_type == "INT" ) then
                        use_var = int32_unsigned_from_raw
                    else
                        use_var = {
                            ["UNKNOWN_TYPE"] = {
                                ["INT"]   = int32_unsigned_from_raw,
                                ["FLOAT"] = float_from_raw,
                                ["HEX"]   = hex_string_display,
                            }
                        }
                    end

                    if ( num_groups > 2 ) then
                        table.insert(prop_entry["values"], use_var)
                    else
                        prop_entry["values"] = use_var
                    end
                end

                -- Fake a continue statement
                ::continue::
            end
        end
    end


    -- Set the file pointer to the end position of the entry
    r:seek("set", end_position)

    -- prop_entry.length = length

    out:write("\n")

    return prop_entry
end



-- Get a main entry
local function get_main_entry(i, level)
    level = level or 0
    local indent = string.rep(" ", level*4)
    local current
    local current_entry = {}
    local is_super_category = false

    current = r:seek()
    out:write("\n\n")
    out:write(indent .. string.format("-------------- ENTRY %i -- [Level %i] --------------\n\n", i, level))
    out:write(indent .. string.format("--- Getting the content length of this entry ---\n"))
    out:write(indent .. string.format("...current file position: %i\n", current))
    
   
    -- The length of this entry
    local entry_byte_length_raw = r:read(4)
    local entry_byte_length_hex = get_hex(entry_byte_length_raw)
    local entry_byte_length_int = uint32(entry_byte_length_raw)

    out:write(indent .. string.format("The content length is: %d bytes (hex: %s)\n", entry_byte_length_int, entry_byte_length_hex))
    
    remaining_entry_byte_length = entry_byte_length_int

    local identifier_raw = r:read(12)
    local identifier_hex = get_hex(identifier_raw)

    remaining_entry_byte_length = remaining_entry_byte_length - 4   -- entry_byte_length_raw
    remaining_entry_byte_length = remaining_entry_byte_length - 12  -- identifier_raw
    

    -- The entry may have a name or not
    local entry_name_length_raw = r:read(2)
    local entry_name_length_hex = get_hex(entry_name_length_raw)
    local entry_name_length_int = uint16(entry_name_length_raw)
    local entry_name            = r:read(entry_name_length_int)

    -- Check if the name length is 0
    local is_name_zero = ( entry_name_length_int == 0 )


    remaining_entry_byte_length = remaining_entry_byte_length - 2 -- entry_name_length_raw
    remaining_entry_byte_length = remaining_entry_byte_length - entry_name_length_int


    -- The following entries seem to be group entries
    -- Starting with EB FF 8C FE
    -- Int 4270653419
    --                                                        Length   Name                             Sub                                                Separator      Sub entries
    -- Chunks     - EB FF 8C FE    9E 1A D5 E9 7A EA 01 B5    06 00    43 68 75 6E 6B 73                00                                                 00 00 00 00    14 00
    -- Glows      - EB FF 8C FE    12 CE A2 15 95 6B 8F 23    05 00    47 6C 6F 77 73                   00                                                 00 00 00 00    14 00
    -- Lights     - EB FF 8C FE    F4 52 CD 9D 22 DA 49 8E    06 00    4C 69 67 68 74 73                00                                                 00 00 00 00    14 00
    -- Shadow     - EB FF 8C FE    3C A1 F5 DF 95 33 72 87    06 00    53 68 61 64 6F 77                00                                                 00 00 00 00    01 00
    -- (empty)    - EB FF 8C FE    68 61 B6 50 76 2D E5 02    00 00                                     00                                                 00 00 00 00    00 00
    -- Chunks     - EB FF 8C FE    9E 1A D5 E9 7A EA 01 B5    06 00    43 68 75 6E 6B 73                01    08 00 E8 81 15 17 00 00 00 00                00 00 00 00    14 00
    -- Jets       - EB FF 8C FE    74 DB 05 70 DA 22 D3 BD    04 00    4A 65 74 73                      00                                                 00 00 00 00    0B 00
    -- Boosters   - EB FF 8C FE    C1 FD 5B 47 96 7A 67 E9    08 00    42 6F 6F 73 74 65 72 73          00                                                 00 00 00 00    00 00
    -- Hardpoints - EB FF 8C FE    F1 7C B1 F8 4E 34 C3 FE    0A 00    48 61 72 64 70 6F 69 6E 74 73    00                                                 00 00 00 00    05 00
    -- Weight     - EB FF 8C FE    E7 2D 23 77 2B 08 F4 36    00 00                                     01    0C 00 24 AC A6 02 06 00 57 65 69 67 68 74    00 00 00 00    01 00    (the next entry is a sub entry)
    -- (empty)    - EB FF 8C FE    CD CD 20 B1 C9 74 95 16    00 00                                     01    08 00 CB E0 8B F1 64 00 00 00                00 00 00 00    01 00    (the next entry is a sub entry)
    --            - FF 1C 60 4A    A1 D1 73 43 97 1B 65 1A    09 00    41 4E 49 4D 41 54 49 4F 4E       07    08 00 E8 81 15 17 01 00 00 00 ...            00 00 00 00    00 00    (7 entries in total, then ended)
    --            - FF 1C 60 4A    35 25 D7 0F 0B F8 58 30    10 00    50 49 52 .. .. 45 52 5F 30 31    04    10 00 3D 27 BB 62 D8 01 8E C1 63 EE ...      00 00 00 00    00 00    (4 entries in total, then ended)
    --            - A9 C9 60 00    C1 A6 C1 0E 4A 6A 4C 55    0A 00    64 65 62 72 69 73 68 75 6C 6C    08    10 00 3D 27 BB 62 AE 47 E1 3F 3D 0A ...      00 00 00 00    00 00    (8 entries in total, then ended)


    -- Get the type of the entry
    local identifier_type_raw = string.sub(identifier_raw, 1, 4)
    local identifier_type_hex = get_hex(identifier_type_raw)
    local identifier_type_int = uint32(identifier_type_raw)

    out:write(indent .. string.format("Entry Name: %s\n", entry_name))
    out:write(indent .. string.format("Identifier Hex:  %s\n", identifier_hex))
    out:write(indent .. string.format("Identifier Type: %s\n", identifier_type_hex))


    -- And the integer value for the identifier
    local identifier_bigint_raw = string.sub(identifier_raw, 5, 12)
    local identifier_bigint_hex = get_hex(identifier_bigint_raw)
    local identifier_bigint_int = uint64(identifier_bigint_raw)

    -- Store the name and the identifier
    current_entry.name             = entry_name
    current_entry.identifier_hex   = identifier_hex
    current_entry.identifier_type  = identifier_type_int
    current_entry.identifier_int   = identifier_bigint_int


    -- The next byte defines if there are properties for this entry
    local num_properties_raw = r:read(1)
    local num_properties_hex = get_hex(num_properties_raw)
    local num_properties_int = uint8(num_properties_raw)

    remaining_entry_byte_length = remaining_entry_byte_length - 1   -- num_properties_raw


    out:write(indent .. string.format("The number of properties: %d (hex: %s)\n", num_properties_int, num_properties_hex))


    -- Get the properties
    if ( num_properties_int > 0 ) then
        current_entry.properties = {}

        for j = 1, num_properties_int do
            local prop_entry = get_property_entry(j, level+1)
            current_entry.properties[j] = { [ prop_entry["id"] ] = prop_entry["values"] }
        end
    end


    -- After the properties should be a separator with 00 00 00 00
    -- And after that two bytes with the number of sub entries
    -- The "separator" isn't actually a separator, it seems to be a length indicator for additional data that isn't a property or a sub entry
    -- This seems to be "timeline" data
    current = r:seek()
    local timeline_data_length_raw = r:read(4)
    local timeline_data_length_hex = get_hex(timeline_data_length_raw)
    local timeline_data_length_int = uint32(timeline_data_length_raw)

    out:write(indent .. string.format("The property entries should have ended\n"))
    out:write(indent .. string.format("The remaining content length for this entry: %d bytes\n", remaining_entry_byte_length))
    out:write(indent .. string.format("Timeline data length: %s (hex: %s)\n", timeline_data_length_int, timeline_data_length_hex))

    if ( timeline_data_length_int > 0 ) then
        out:write(indent .. string.format("    There is additional timeline data, for which the syntax is currently unknown:\n"))

        local timeline_data_raw = r:read(timeline_data_length_int)
        local timeline_data_hex = get_hex(timeline_data_raw)

        out:write(indent .. string.format("    %s\n", timeline_data_hex))

        current_entry.timeline_data = timeline_data_hex

        remaining_entry_byte_length = remaining_entry_byte_length - timeline_data_length_int
    end

    -- After the timeline data should be the number of sub entries
    local num_sub_entries_raw = r:read(2)
    local num_sub_entries_hex = get_hex(num_sub_entries_raw)
    local num_sub_entries_int = uint16(num_sub_entries_raw)

    out:write("\n")
    out:write(indent .. string.format("The number of sub entries: %d (hex: %s)\n", num_sub_entries_int, num_sub_entries_hex))

    remaining_entry_byte_length = remaining_entry_byte_length - 4   -- separator_raw
    remaining_entry_byte_length = remaining_entry_byte_length - 2   -- num_sub_entries_raw

    if ( num_sub_entries_int > 0 ) then
        current_entry.entries = {}

        for j = 1, num_sub_entries_int do
            current_entry.entries[j] = get_main_entry(j, level+1)
        end
    end


    out:write(indent .. string.format("The remaining content length for this entry: %d bytes\n", remaining_entry_byte_length))

    if ( remaining_entry_byte_length > 0 ) then
        local remaining_raw = r:read(remaining_entry_byte_length)
        local remaining_hex = get_hex(remaining_raw);
        out:write(indent .. string.format("Hex: %s\n", remaining_hex))
    end

    return current_entry
end


-- Get all entries
local remaining_entry_byte_length

for i = 1, number_of_entries_main_int do
    OUTPUT["entries"][i] = get_main_entry(i, 0)
end

local file_position_after_content = r:seek()
local total_file_size = r:seek("end")

out:write("\n\n")
out:write(string.format("File position after reading the content: %d\n", file_position_after_content))
out:write(string.format("File size:                               %d\n", total_file_size))
out:write(string.format("Provided content length:                 %d\n", total_content_length_int))

local have_read_all_content = false
local missed_some_content   = false
local overshot_content      = false
local missing_bytes
local surplus_bytes


-- Error checks if we have parsed all the content
if ( total_content_length_int == 0 ) then
    if ( file_position_after_content == total_file_size ) then
        have_read_all_content = true
    elseif ( file_position_after_content < total_file_size ) then
        missed_some_content = true
        missing_bytes       = total_file_size - file_position_after_content
    elseif ( file_position_after_content > total_file_size ) then -- ok, this shouldn't be possible here
        overshot_content = true
        surplus_bytes    = file_position_after_content - total_file_size
    end
end



if ( total_content_length_int > 0 ) then
    if ( file_position_after_content == total_content_length_int ) then
        have_read_all_content = true
    elseif ( file_position_after_content < total_content_length_int ) then
        missed_some_content = true
        missing_bytes       = total_content_length_int - file_position_after_content
    elseif ( file_position_after_content > total_content_length_int ) then
        overshot_content = true
        surplus_bytes    = file_position_after_content - total_content_length_int
    end
end


if ( have_read_all_content ) then
    out:write(string.format("SUCCESS: Parsed all of the content!\n"))
elseif ( missed_some_content ) then
    out:write(string.format("WARNING: Did not parse all of the content!\n"))
    out:write(string.format("         Still missing %d bytes!\n", missing_bytes))

    local missing_content_raw      = r:read(missing_bytes)
    local missing_content_hex      = get_hex(missing_content_raw)
    local missing_content_readable = string.gsub(missing_content_raw, "%c", ".")

    out:write(string.format("Content in Hex:\n"))
    out:write(missing_content_hex)
    out:write("\n\n")

    out:write(string.format("Content in Raw:\n"))
    out:write(missing_content_readable)
    out:write("\n\n")

elseif ( overshot_content ) then
    out:write(string.format("WARNING: Parsed more than the provided content!\n"))
    out:write(string.format("         Additionally read bytes: %d bytes!\n", surplus_bytes))

    local additional_content_raw      = r:read(surplus_bytes)
    local additional_content_hex      = get_hex(additional_content_raw)
    local additional_content_readable = string.gsub(additional_content_raw, "%c", ".")

    out:write(string.format("Content in Hex:\n"))
    out:write(additional_content_hex)
    out:write("\n\n")

    out:write(string.format("Content in Raw:\n"))
    out:write(additional_content_readable)
    out:write("\n\n")
end


-- Check for the additional data that may be present after the provided content
if ( total_content_length_int > 0 and file_position_after_content < total_file_size ) then
    out:write("\n\n\n\n")
    out:write(string.format("There is also additional data after the provided content length\n"))
    out:write(string.format("It may or may not be useful data\n"))

    r:seek("set", file_position_after_content)
    
    local remaining_bytes = total_file_size - file_position_after_content
    local remaining_content_raw = r:read(remaining_bytes)
    local remaining_content_hex = get_hex(remaining_content_raw)
    local remaining_content_readable = string.gsub(remaining_content_raw, "%c", ".")

    out:write(string.format("Length of remaining data: %d bytes\n", remaining_bytes))
    out:write("\n")
    out:write(string.format("Content in Hex:\n"))
    out:write(remaining_content_hex)
    out:write("\n\n")

    out:write(string.format("Content in Raw:\n"))
    out:write(remaining_content_readable)
    out:write("\n\n")

    OUTPUT["additional_data"] = remaining_content_hex
end






-- print("\n\n------ TABLE DUMP ------")
-- tdump(OUTPUT)

if out_file then
    out = assert(io.open(out_file, "w+"))
end


-- persistence.store(out_file, OUTPUT)


-- Get the string for a property
local function get_property_string(level, property_key, property_entry)
    local STR

    if ( type(property_entry) == "table" ) then 
        if ( type(property_key) == "string" ) then
            STR = indent(level, '["' .. property_key ..'"] = {\n')
        else
            STR = indent(level, '[' .. property_key ..'] = {\n')
        end

        for property_key, property_value in pairs(property_entry) do
            STR = STR .. indent(level+1, '["' .. property_key .. '"] = ')

            -- Tables
            if ( type(property_value) == "table" ) then
                STR = STR .. '{'

                if ( property_key == "COORDINATES" ) then
                    STR = STR .. '  -- X, Y, Z'
                elseif ( property_key == "ROTATIONS" ) then
                    STR = STR .. '  -- X, Y, Z1, Z2'
                end

                STR = STR .. '\n'
                
                for value_key, value_entry in pairs(property_value) do
                    STR = STR .. get_property_string(level+2, value_key, value_entry)
                end
                
                STR = STR .. indent(level+1, '},\n')
                -- STR = STR .. indent(level, '},\n')
            
            -- Strings, Ints, Floats
            else 
                if ( type(property_value) == "string" ) then
                    STR = STR .. string.format("%q", property_value)
                else
                    STR = STR .. property_value
                end

                STR = STR .. ',\n'
            end
        end

        STR = STR .. indent(level, '},\n')
    

    -- The entry is not a table
    else
        if ( type(property_key) == "string" ) then
            STR = indent(level, '["' .. property_key ..'"] = ')
        else
            STR = indent(level, '[' .. property_key ..'] = ')
        end

        if ( type(property_entry) == "string" ) then
            STR = STR .. string.format("%q", property_entry)
        else
            STR = STR .. property_entry
        end

        STR = STR .. ',\n'
    end

    return STR
end


-- Get the string for an entry
-- May call itself
local function get_entry_string(level, key, entry, parent_key)
    local parent_key_str

    if ( parent_key ~= nil ) then
        parent_key_str = parent_key .. " [" .. key .. "]"
    else
        parent_key_str = "[" .. key .. "]"
    end

    local STR = '\n'

    STR = STR .. indent(level, string.format('-------------------- ENTRY %s --------------------\n', parent_key_str))
    STR = STR .. indent(level, '[' .. key .. '] = {\n')
    STR = STR .. indent(level+1, '["name"] = ' .. string.format('%q', entry.name) .. ',\n')
    STR = STR .. indent(level+1, '["identifier_type"] = "' .. entry.identifier_type .. '",  -- do not change\n')
    STR = STR .. indent(level+1, '["identifier"] = "' .. entry.identifier_int .. '",  -- do not change\n')
    STR = STR .. indent(level+1, '["identifier_hex"] = "' .. entry.identifier_hex .. '",\n')

    -- Get properties
    if ( entry.properties ~=nil ) then
        STR = STR .. indent(level+1, '["properties"] = {\n')

        for prop_key, value in ipairs(entry.properties) do
            STR = STR .. get_property_string(level+2, prop_key, value)
        end

        STR = STR .. indent(level+1, '},   -- end properties\n')
    end

    -- Timeline data
    if ( entry.timeline_data ~= nil ) then
        STR = STR .. '\n'
        STR = STR .. indent(level+1, '-- There\'s additional timeline data, for which the format is currently unknown\n')
        STR = STR .. indent(level+1, '["timeline_data"] = ')
        STR = STR .. '"' .. entry.timeline_data .. '",\n'
    end

    -- Get sub entries
    if ( entry.entries ~=nil ) then
        STR = STR .. indent(level+1, '["entries"] = {\n')

        for sub_key, value in ipairs(entry.entries) do
            STR = STR .. get_entry_string(level+2, sub_key, value, parent_key_str)
        end

        STR = STR .. indent(level+1, '},   -- end entries for ' .. parent_key_str .. '\n')
    end


    STR = STR .. indent(level, '},  -- end entry ' .. parent_key_str ..'\n')

    return STR
end


local STR
STR =        indent(0, 'local LAYOUT = {\n')
STR = STR .. indent(1, '["entries"] = {\n')

for i = 1, number_of_entries_main_int do
    STR = STR .. get_entry_string(2, i, OUTPUT.entries[i])
end

STR = STR .. indent(1, '}, -- end main entries\n\n')

if ( OUTPUT.additional_data ~= nil ) then
    STR = STR .. '\n'
    STR = STR .. indent(1, '-- -----------------------------------------------------------\n')
    STR = STR .. indent(1, '-- Additonal data that is added to the end of the .layout file\n')
    STR = STR .. indent(1, '-- Currently it\'s unknown what it does, so don\'t change it\n')
    STR = STR .. indent(1, '["additional_data"] = "' .. OUTPUT.additional_data .. '"\n')
end

STR = STR .. indent(0, '}')

STR = STR .. '\n\n'
STR = STR .. 'return LAYOUT'

out:write(STR)
out:close()


print(string.format("Created %s", out_file))