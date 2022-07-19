-- These hex strings seem to define a following string
local sub_string_types = {
     ["C5 2D 62 00"] = "MDL",                   -- 6434245
     ["00 0A B6 67"] = "DAT_OR_MDL",            -- 1739983360
     ["7D F4 A1 E4"] = "DDS_1",                 -- 3835819133
     ["4B 83 C8 C6"] = "DDS_2",                 -- 3335029579
     ["98 AC C6 DA"] = "DDS_3",                 -- 3670453400
     ["FC A1 1C 67"] = "DDS_4",                 -- 1729929724
     ["E7 D6 76 AD"] = "DDS_5",                 -- 2910246631
     ["E7 DC AF BE"] = "RGBA_COLOR_VALUE_1",    -- 3199196391
     ["BC 9D 05 DE"] = "RGBA_COLOR_VALUE_2",    -- 3724910012
     ["24 EB 87 C2"] = "RIGHT_LEFT_FREE",       -- 3263687460
     ["45 6E 6B 00"] = "STRING_1",              -- 7040581
     ["A4 B5 67 00"] = "STRING_2",              -- 6796708
     ["CC 4E 3A DE"] = "STRING_3",              -- 3728363212
     ["CB B7 06 AB"] = "STRING_4",              -- 2869344203
     ["55 8F 65 E1"] = "STRING_5",              -- 3781529429
     ["50 9C 0D 5C"] = "STRING_6",              -- 1544395856
}

local sub_string_types_int = {
     [6434245]    = "MDL",                      -- "C5 2D 62 00"
     [1739983360] = "DAT_OR_MDL",               -- "00 0A B6 67"
     [3835819133] = "DDS_1",                    -- "7D F4 A1 E4"
     [3335029579] = "DDS_2",                    -- "4B 83 C8 C6"
     [3670453400] = "DDS_3",                    -- "98 AC C6 DA"
     [1729929724] = "DDS_4",                    -- "FC A1 1C 67"
     [2910246631] = "DDS_5",                    -- "E7 D6 76 AD"
     [3199196391] = "RGBA_COLOR_VALUE_1",       -- "E7 DC AF BE"
     [3724910012] = "RGBA_COLOR_VALUE_2",       -- "BC 9D 05 DE"
     [3263687460] = "RIGHT_LEFT_FREE",          -- "24 EB 87 C2"
     [7040581]    = "STRING_1",                 -- "45 6E 6B 00"
     [6796708]    = "STRING_2",                 -- "A4 B5 67 00"
     [3728363212] = "STRING_3",                 -- "CC 4E 3A DE"
     [2869344203] = "STRING_4",                 -- "CB B7 06 AB"
     [3781529429] = "STRING_5",                 -- "55 8F 65 E1"
     [1544395856] = "STRING_6",                 -- "50 9C 0D 5C"
}

local sub_string_types_str_to_int = {
     ["MDL"]                = 6434245,
     ["DAT_OR_MDL"]         = 1739983360,
     ["DDS_1"]              = 3835819133,
     ["DDS_2"]              = 3335029579,
     ["DDS_3"]              = 3670453400,
     ["DDS_4"]              = 1729929724,
     ["DDS_5"]              = 2910246631,
     ["RGBA_COLOR_VALUE_1"] = 3199196391,
     ["RGBA_COLOR_VALUE_2"] = 3724910012,
     ["RIGHT_LEFT_FREE"]    = 3263687460,
     ["STRING_1"]           = 7040581,
     ["STRING_2"]           = 6796708,
     ["STRING_3"]           = 3728363212,
     ["STRING_4"]           = 2869344203,
     ["STRING_5"]           = 3781529429,
     ["STRING_6"]           = 1544395856,
}


-- These hex types define the type of a sub entry
-- They appear as the first 4-byte group of a sub entry
local prop_entry_types = {
    ["3D 27 BB 62"] = "COORDINATES",            -- 1656432445
    ["95 26 8D 28"] = "ROTATIONS",              -- 680339093
    ["ED AA 94 3A"] = "HARDPOINT_NUMBER_1",     -- 982821613
    ["EE AA 94 3A"] = "HARDPOINT_NUMBER_2",     -- 982821614
    ["E2 90 34 FA"] = "MDL_TYPE",               -- 4197748962
}

local prop_entry_types_int = {
    [1656432445] = "COORDINATES",               -- "3D 27 BB 62"
    [680339093]  = "ROTATIONS",                 -- "95 26 8D 28"
    [982821613]  = "HARDPOINT_NUMBER_1",        -- "ED AA 94 3A"
    [982821614]  = "HARDPOINT_NUMBER_2",        -- "EE AA 94 3A"
    [4197748962] = "MDL_TYPE",                  -- "E2 90 34 FA"
}

local prop_entry_types_str_to_int = {
    ["COORDINATES"]        = 1656432445,
    ["ROTATIONS"]          = 680339093,
    ["HARDPOINT_NUMBER_1"] = 982821613,
    ["HARDPOINT_NUMBER_2"] = 982821614,
    ["MDL_TYPE"]           = 4197748962,
}


-- Here we try to determine what type of values are present for a specific property
local var_types_per_group = {
    ["COORDINATES"]        = { "FLOAT", "FLOAT", "FLOAT" },
    ["ROTATIONS"]          = { "FLOAT", "FLOAT", "FLOAT", "FLOAT" },
    ["HARDPOINT_NUMBER_1"] = { "INT" },
    ["HARDPOINT_NUMBER_2"] = { "INT" },
    ["MDL_TYPE"]           = { "INT" },

    -- Best guesses
    ["$120"]        = { "FLOAT" },
    ["$121"]        = { "FLOAT" },
    ["$122"]        = { "FLOAT" },
    ["$37302"]      = { "FLOAT" },
    ["$6302835"]    = { "FLOAT" },
    ["$6479204"]    = { "FLOAT", "INT" },
    ["$41966680"]   = { "INT" },
    ["$58406023"]   = { "FLOAT" },
    ["$61726035"]   = { "FLOAT" },
    ["$82767127"]   = { "FLOAT" },
    ["$107475854"]  = { "FLOAT" },
    ["$117487961"]  = { "FLOAT" },
    ["$234988772"]  = { "INT" },
    ["$236264560"]  = { "INT" },
    ["$236379540"]  = { "INT" },
    ["$238082482"]  = { "INT" },
    ["$238425541"]  = { "FLOAT" },
    ["$247901733"]  = { "FLOAT" },
    ["$249687282"]  = { "INT" },
    ["$250000979"]  = { "INT" },    -- BOOL? (always 01 00 00 00)
    ["$269232705"]  = { "FLOAT" },
    ["$306176300"]  = { "FLOAT" },
    ["$370878346"]  = { "FLOAT" },
    ["$383263821"]  = { "INT" },
    ["$387285480"]  = { "INT" },
    ["$407954651"]  = { "INT" },
    ["$427262195"]  = { "INT" },
    ["$464039725"]  = { "FLOAT", "FLOAT", "FLOAT" },
    ["$472825584"]  = { "INT" },
    ["$477501129"]  = { "FLOAT" },
    ["$519877365"]  = { "INT" },
    ["$540164520"]  = { "FLOAT" },
    ["$540225266"]  = { "FLOAT" },
    ["$685202916"]  = { "FLOAT" },
    ["$752445854"]  = { "INT" },
    ["$794079638"]  = { "FLOAT" },
    ["$808064609"]  = { "FLOAT" },
    ["$829502863"]  = { "FLOAT" },
    ["$871132703"]  = { "FLOAT" },
    ["$901130821"]  = { "INT" },
    ["$985009891"]  = { "INT" },
    ["$1048752776"] = { "FLOAT" },
    ["$1050384889"] = { "FLOAT" },
    ["$1078228909"] = { "INT" },
    ["$1121526416"] = { "INT" },    -- Unknown, seems to be always 00 00 00 00
    ["$1127238469"] = { "FLOAT" },
    ["$1157231614"] = { "INT" },
    ["$1267027621"] = { "FLOAT" },
    ["$1280950533"] = { "FLOAT" },
    ["$1281592863"] = { "INT" },
    ["$1290116903"] = { "INT" },
    ["$1358650184"] = { "INT" },
    ["$1409256877"] = { "FLOAT" },
    ["$1435429390"] = { "INT" },
    ["$1484221856"] = { "FLOAT" },
    ["$1508903546"] = { "INT" },
    ["$1675131359"] = { "FLOAT" },
    ["$1680912114"] = { "FLOAT" },
    ["$1693781404"] = { "FLOAT" },
    ["$1732583820"] = { "FLOAT" },
    ["$1761224930"] = { "FLOAT" },
    ["$1919643935"] = { "FLOAT" },
    ["$2049372873"] = { "FLOAT" },
    ["$2123279557"] = { "INT" },
    ["$2198895280"] = { "FLOAT" },
    ["$2218775406"] = { "INT" },
    ["$2239913900"] = { "FLOAT" },
    ["$2314136772"] = { "FLOAT" },
    ["$2327760332"] = { "FLOAT" },
    ["$2342541651"] = { "INT" },
    ["$2378094963"] = { "INT" },
    ["$2390723320"] = { "FLOAT" },
    ["$2395588028"] = { "FLOAT" },
    ["$2400872973"] = { "FLOAT" },
    ["$2608642991"] = { "FLOAT" },
    ["$2675902111"] = { "FLOAT" },
    ["$2687542601"] = { "INT" },
    ["$2687648237"] = { "FLOAT" },
    ["$2727432073"] = { "INT" },
    ["$2733487078"] = { "INT" },
    ["$2749276123"] = { "INT" },
    ["$2755049203"] = { "FLOAT" },
    ["$2795048891"] = { "FLOAT" },
    ["$2801365900"] = { "FLOAT" },
    ["$2943272991"] = { "FLOAT" },
    ["$2988272576"] = { "INT" },
    ["$3063339172"] = { "FLOAT" },
    ["$3104706929"] = { "FLOAT" },
    ["$3117664389"] = { "INT" },
    ["$3160810134"] = { "FLOAT" },
    ["$3188686253"] = { "INT" },
    ["$3213889982"] = { "FLOAT" },
    ["$3297955038"] = { "INT" },
    ["$3328911237"] = { "FLOAT" },
    ["$3328922719"] = { "FLOAT" },  -- Can be negative
    ["$3428540423"] = { "FLOAT" },
    ["$3435577387"] = { "FLOAT" },
    ["$3442360291"] = { "INT" },
    ["$3458353829"] = { "INT" },
    ["$3463636981"] = { "INT" },
    ["$3584271527"] = { "FLOAT" },
    ["$3603078118"] = { "INT" },
    ["$3625375726"] = { "INT" },
    ["$3640551892"] = { "FLOAT" },
    ["$3661776090"] = { "FLOAT" },
    ["$3669148396"] = { "FLOAT" },
    ["$3722119729"] = { "INT" },
    ["$3723540474"] = { "FLOAT" },
    ["$3738157445"] = { "FLOAT" },
    ["$3761973147"] = { "FLOAT" },
    ["$3763355284"] = { "INT" },    -- Unknown, seems to be always 00 00 00 00
    ["$3788587557"] = { "INT" },
    ["$3801509512"] = { "INT" },
    ["$3816156344"] = { "INT" },
    ["$3852786932"] = { "FLOAT" },
    ["$3855417105"] = { "FLOAT" },
    ["$3858461396"] = { "INT" },
    ["$3893202746"] = { "FLOAT" },
    ["$3921402908"] = { "FLOAT" },
    ["$3977393103"] = { "FLOAT" },
    ["$4052476107"] = { "INT" },
    ["$4097206341"] = { "FLOAT" },
    ["$4227299649"] = { "FLOAT" },
    ["$4286701744"] = { "INT" },
    ["$4288751180"] = { "FLOAT" },
}


return sub_string_types, sub_string_types_int, sub_string_types_str_to_int, prop_entry_types, prop_entry_types_int, prop_entry_types_str_to_int, var_types_per_group