local function compile_simd_libraries()
    print("--- COMPILING SIMD KERNELS ---")

    -- 1. Compile for Linux (.so)
    -- ULTIMA PLATIN (AVX2/FMA enabled)
    local linux_cmd = "gcc -O3 -mavx -mavx2 -mfma -shared -fPIC vibemath.c -o libvibemath.so"
    -- LEGACY BASELINE (Strictly generic x86-64, no AVX)
    -- local linux_cmd_legacy = "gcc -O3 -march=x86-64 -shared -fPIC vibemath_legacy.c -o libvibemath_legacy.so"

    print("  |- Building Linux shared objects ...")
    os.execute(linux_cmd)
    -- os.execute(linux_cmd_legacy)

    -- 2. Compile for Windows (.dll) using MinGW Cross-Compiler
    -- ULTIMA PLATIN (AVX2/FMA enabled)
    local win_cmd = "x86_64-w64-mingw32-gcc -O3 -mavx -mavx2 -mfma -shared -fPIC vibemath.c -o vibemath.dll"
    -- LEGACY BASELINE (Strictly generic x86-64, no AVX)
    -- local win_cmd_b = "x86_64-w64-mingw32-gcc -O3 -march=x86-64 -shared -fPIC vibemath_legacy.c -o vibemath_legacy.dll"

    print("  |- Cross-compiling Windows DLLs ...")
    os.execute(win_cmd)
    -- os.execute(win_cmd_b)
end
local function minify_c(content)
    -- 1. Strip out multi-line comments (non-greedy)
    content = content:gsub("/%*.-%*/", "")

    local minified_string = ""
    local in_multiline_macro = false

    for line in content:gmatch("[^\r\n]+") do
        local clean_line = line
        
        -- 2. Strip single-line comments // (respecting strings)
        local s = clean_line:find("//", 1, true)
        if s then
            local prefix = clean_line:sub(1, s - 1)
            local _, quote_count = prefix:gsub('"', '"')
            if quote_count % 2 == 0 then
                clean_line = prefix
            end
        end

        -- 3. Squash whitespace and trim
        clean_line = clean_line:gsub("[ \t]+", " ")
        clean_line = clean_line:match("^%s*(.-)%s*$")

        if clean_line ~= "" then
            -- 4. Check for preprocessor directives or macro continuations
            if clean_line:sub(1, 1) == "#" or in_multiline_macro then
                
                -- Directives MUST have a newline
                minified_string = minified_string .. clean_line .. "\n"
                
                -- Check if this macro spans multiple lines using a trailing backslash
                if clean_line:sub(-1) == "\\" then
                    in_multiline_macro = true
                else
                    in_multiline_macro = false
                end
            else
                -- 5. Normal C code: Squash it! 
                -- Just append a space so tokens don't merge (e.g., "int""main" -> "int main")
                minified_string = minified_string .. clean_line .. " "
            end
        end
    end

    if minified_string == "" then return "/* [EMPTY] */" end
    return minified_string
end
local function strip_to_target_std_output_c(content)
    -- 1. Strip out multi-line comments (non-greedy match)
    content = content:gsub("/%*.-%*/", "")

    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        local clean_line = line
        
        -- 2. Find single-line comments
        local s = clean_line:find("//", 1, true)
        if s then
            local prefix = clean_line:sub(1, s - 1)
            -- Check if the '//' is inside a string by counting preceding quotes
            local _, quote_count = prefix:gsub('"', '"')
            if quote_count % 2 == 0 then
                clean_line = prefix
            end
        end

        -- 3. Squash tabs/multiple spaces into a single space
        clean_line = clean_line:gsub("[ \t]+", " ")
        -- 4. Trim leading and trailing whitespace
        clean_line = clean_line:match("^%s*(.-)%s*$")

        if clean_line ~= "" then
            table.insert(lines, clean_line)
        end
    end

    if #lines == 0 then return "/* [EMPTY OR ALL COMMENTS] */" end
    
    -- IMPORTANT: C needs newlines for #define and #include directives!
    -- Do not use "; " like in the Lua minifier.
    return table.concat(lines, "\n")
end
local function minify_lua(content)
    local lines = {}
    local d = "\45" .. "\45"
    for line in content:gmatch("[^\r\n]+") do
        local s = line:find(d, 1, true)
        local clean_line = line
        if s then
            local prefix = line:sub(1, s - 1)
            local _, quote_count = prefix:gsub('"', '"')
            if quote_count % 2 == 0 then
                clean_line = prefix
            end
        end
        clean_line = clean_line:gsub("[ \t]+", " ")
        clean_line = clean_line:match("^%s*(.-)%s*$")
        if clean_line ~= "" then
            table.insert(lines, clean_line)
        end
    end
    if #lines == 0 then return "-- [EMPTY OR ALL COMMENTS] --" end
    return table.concat(lines, "; ")
end
local function strip_to_target(input_path, output_path)
    local infile = io.open(input_path, "r")
    if not infile then return false end
    local lines = {}
    local d = "\45" .. "\45"
    for line in infile:lines() do
        local s = line:find(d, 1, true)
        local clean_line = line
        if s then
            local prefix = line:sub(1, s - 1)
            local _, quote_count = prefix:gsub('"', '"')
            if quote_count % 2 == 0 then
               clean_line = prefix
            end
        end
        clean_line = clean_line:match("^%s*(.-)%s*$")
        if clean_line ~= "" then
            table.insert(lines, clean_line)
        end
    end
    infile:close()
    local outfile = io.open(output_path, "w")
    if outfile then
        outfile:write(table.concat(lines, "\n") .. "\n")
        outfile:close()
        return true
    end
    return false
end
local function copy_file(src, dest)
    local f_in = io.open(src, "rb")
    if not f_in then return false end
    local content = f_in:read("*all")
    f_in:close()
    local f_out = io.open(dest, "wb")
    if not f_out then return false end
    f_out:write(content)
    f_out:close()
    return true
end

local process_manifest = {
    ["memory.lua"] = "BUILD/memory.lua",
--    ["sequence.lua"] = "BUILD/sequence.lua",
--    ["main.lua"] = "BUILD/main.lua",
--    ["render.lua"] = "BUILD/render.lua",
--    ["load.lua"] = "BUILD/load.lua",
    ["smales_paradox.lua"] = "BUILD/modules/smales_paradox.lua",
    ["swarm.lua"] = "BUILD/swarm.lua",
--    ["conf.lua"] = "BUILD/conf.lua",
--    ["physics.lua"] = "BUILD/physics.lua",
    ["metal.lua"] = "BUILD/metal.lua",
--    ["build_orchestrator.lua"] = "BUILD/built_orchestrator.lua",
--    ["bench.lua"] = "BUILD/bench.lua",
}

local raw_manifest = {} -- now empty because we broke free from json chains
local function setup_build_dir(dir)
    local ok = os.execute("test -d " .. dir)
    if ok == 0 or ok == true then
        print("!!! Found existing " .. dir .. " directory. Press ENTER to purge and rebuild.")
        io.read()
        os.execute("rm -rf " .. dir)
    end
    return os.execute("mkdir -p " .. dir)
end
local function get_sorted_files()
    local sorted = {}
    local visited = {}

    local function visit(file)
        if visited[file] then return end
        visited[file] = true

        local f = io.open(file, "r")
        if f then
            local content = f:read("*all")
            f:close()
            for dep_match in content:gmatch('require%s*%(?%s*["\'](.-)["\']%s*%)?') do

                -- NEW: Convert Lua's module dot notation to file path slashes!
                -- e.g., "MODULES.presentation" -> "MODULES/presentation"
                local dep_name = dep_match:gsub("%.", "/")

                if not dep_name:find("%.lua$") then
                    dep_name = dep_name .. ".lua"
                end
                if process_manifest[dep_name] then
                    visit(dep_name)
                end
            end
        end
        table.insert(sorted, file)
    end

    for file in pairs(process_manifest) do visit(file) end
    return sorted
end

-- if not setup_build_dir("BUILD") then os.exit(1) end

compile_simd_libraries()

--for src, dest in pairs(process_manifest) do
--    if strip_to_target(src, dest) then print("  |- (Stripped) " .. src) end
--end
--for src, dest in pairs(raw_manifest) do
--    if copy_file(src, dest) then print("  |- (Raw)      " .. src) end
--end
--print("\n--- AI SNAPSHOT ---")
--local order = get_sorted_files()
--for _, src in ipairs(order) do
    --local f = io.open(src, "r")
    --if f then
        --print("@@@ FILE: " .. src .. " @@@\n" .. minify_lua(f:read("*all")))
        --f:close()
    --end
--end
print("\n--- AI SNAPSHOT ---")
local order = get_sorted_files()

-- Let's explicitly add vibemath.c to the snapshot since it's not in the Lua require() tree
table.insert(order, "vibemath.c")

for _, src in ipairs(order) do
    local f = io.open(src, "r")
    if f then
        local content = f:read("*all")
        local minified_content = ""

        if src:match("%.c$") or src:match("%.h$") then
            minified_content = minify_c(content)
        else
            minified_content = minify_lua(content)
        end

        print("@@@ FILE: " .. src .. " @@@\n" .. minified_content)
        f:close()
    end
end
