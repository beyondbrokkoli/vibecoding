local ffi = require("ffi")
local function load_simd_library()
local lib_name = "vibemath"
if jit.os == "Windows" then
lib_name = lib_name .. ".dll"
elseif jit.os == "OSX" then
lib_name = lib_name .. ".dylib"
else
lib_name = "lib" .. lib_name .. ".so"
end
local base_dir = love.filesystem.getSourceBaseDirectory()
local dev_path = base_dir .. "/" .. lib_name
local success, lib = pcall(ffi.load, dev_path)
if success then
print("[SIMD] Booted native library from Dev Path: " .. dev_path)
return lib
end
print("[SIMD] Dev path failed. Extracting library from .love archive...")
local save_dir = love.filesystem.getSaveDirectory()
local save_path = save_dir .. "/" .. lib_name
local file_data, size = love.filesystem.read(lib_name)
if file_data then
love.filesystem.write(lib_name, file_data)
success, lib = pcall(ffi.load, save_path)
if success then
print("[SIMD] Extracted and loaded library from Save Path: " .. save_path)
return lib
end
end
error("FATAL: Could not load SIMD library on " .. jit.os .. "\nAttempted: " .. dev_path .. "\nAttempted: " .. save_path)
end
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
]]
return load_simd_library()
