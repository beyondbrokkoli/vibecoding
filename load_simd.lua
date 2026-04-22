-- ========================================================================
-- load_simd.lua
-- Cross-Platform FFI Library Loader (Handles unzipped & .love archives)
-- ========================================================================
local ffi = require("ffi")

local function load_simd_library()
    -- 1. Determine OS extension
    local lib_name = "vibemath"
    if jit.os == "Windows" then
        lib_name = lib_name .. ".dll"
    elseif jit.os == "OSX" then
        lib_name = lib_name .. ".dylib"
    else
        lib_name = "lib" .. lib_name .. ".so"
    end

    -- 2. Try Development Path (Absolute path to your unzipped project folder)
    local base_dir = love.filesystem.getSource()
    local dev_path = base_dir .. "/" .. lib_name

    local success, lib = pcall(ffi.load, dev_path)
    if success then 
        print("[SIMD] Booted native library from Dev Path: " .. dev_path)
        return lib 
    end

    -- 3. Try Production Path (We are inside a .love zip archive)
    print("[SIMD] Dev path failed. Extracting library from .love archive...")
    
    -- LÖVE's Save Directory (e.g., ~/.local/share/love/UltimaPlatin/ on Linux)
    local save_dir = love.filesystem.getSaveDirectory()
    local save_path = save_dir .. "/" .. lib_name

    -- Read the binary from the virtual filesystem (inside the zip)
    local file_data, size = love.filesystem.read(lib_name)
    if file_data then
        -- Write it to the real OS disk so the linker can actually see it
        love.filesystem.write(lib_name, file_data)
        
        success, lib = pcall(ffi.load, save_path)
        if success then
            print("[SIMD] Extracted and loaded library from Save Path: " .. save_path)
            return lib
        end
    end

    error("FATAL: Could not load SIMD library on " .. jit.os .. "\nAttempted: " .. dev_path .. "\nAttempted: " .. save_path)
end

-- Define the C-interface for LuaJIT
ffi.cdef[[
    void simd_project_vertices(
        int count,
        float* lx, float* ly, float* lz,
        float* px, float* py, float* pz, bool* valid,
        float ox, float oy, float oz,
        float rx, float ry, float rz, float ux, float uy, float uz, float fx, float fy, float fz,
        float cpx, float cpy, float cpz,
        float cfw_x, float cfw_y, float cfw_z,
        float crt_x, float crt_z,
        float cup_x, float cup_y, float cup_z,
        float cam_fov, float half_w, float half_h
    );
    void process_triangles_twotone(
        int tCount,
        int* v1, int* v2, int* v3, bool* vert_valid,
        float* px, float* py, float* pz,
        float* lx, float* ly, float* lz,
        uint32_t* baked_color, uint32_t* shaded_color, bool* tri_valid,
        float rx, float ry, float rz,
        float ux, float uy, float uz,
        float fx, float fy, float fz,
        float sun_x, float sun_y, float sun_z
    );
    void simd_clear_buffers(
        uint32_t* screen,
        float* zbuffer,
        uint32_t clear_color,
        float clear_z,
        int pixel_count
    );
]]
-- Execute and return the loaded library
return load_simd_library()
