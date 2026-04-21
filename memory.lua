-- ========================================================================
-- memory.lua
-- Pure SoA Motherboard. Dynamic Metaprogramming Allocator.
-- ========================================================================
local ffi = require("ffi")

-- ==========================================
-- [1] THE UNIVERSE BOUNDARIES (Static Limits)
-- ==========================================
MAX_OBJS = 10000
MAX_VERTS = 500000
MAX_TRIS = 1000000

MAX_BOUND_SPHERES = 512
MAX_BOUND_BOXES = 512

BOUND_CONTAIN = 1; BOUND_REPEL = 2; BOUND_SOLID = 3;

-- Global Counters (Used by Allocator below)
local next_obj_id = 0
local next_vert_id = 0
local next_tri_id = 0
local next_sphere_id = 0
local next_box_id = 0

-- ==========================================
-- [2] THE METAPROGRAMMING ALLOCATOR
-- ==========================================
-- Injects FFI arrays directly into the Lua Global namespace (_G)
local function AllocateSoA(type_str, size, names)
    for i = 1, #names do
        _G[names[i]] = ffi.new(type_str, size)
    end
end

-- ========================================================================
-- [3] THE SCHEMA (The Pure Data Arrays)
-- ========================================================================

-- 1. Object Spatial Data (Transforms, Velocities, and Basis Matrices)
AllocateSoA("float[?]", MAX_OBJS, {
    "Obj_Radius", "Obj_X", "Obj_Y", "Obj_Z",
    "Obj_VelX", "Obj_VelY", "Obj_VelZ",
    "Obj_Yaw", "Obj_Pitch", "Obj_RotSpeedYaw", "Obj_RotSpeedPitch",
    "Obj_FWX", "Obj_FWY", "Obj_FWZ",
    "Obj_RTX", "Obj_RTY", "Obj_RTZ",
    "Obj_UPX", "Obj_UPY", "Obj_UPZ",
    "Obj_Freq", "Obj_Phase" -- <<< NEW ARRAYS FOR RESONANCE
})

-- 2. Object Geometry Linking
AllocateSoA("int[?]", MAX_OBJS, {
    "Obj_VertStart", "Obj_VertCount", "Obj_TriStart", "Obj_TriCount"
})

-- 3. The Visibility Buffer (Used by the Camera Cull phase to pass to Raster)
-- Note: Modules will clear and populate this buffer every frame.
AllocateSoA("double[1]", 1, {"Count_Visible"})
AllocateSoA("int[?]", MAX_OBJS, {"Visible_IDs"})

-- 4. Vertex Data (Local, Camera, and Projected Points)
AllocateSoA("float[?]", MAX_VERTS, {
    "Vert_LX", "Vert_LY", "Vert_LZ", 
    "Vert_CX", "Vert_CY", "Vert_CZ", 
    "Vert_PX", "Vert_PY", "Vert_PZ"
})
AllocateSoA("bool[?]", MAX_VERTS, {"Vert_Valid"})

-- 5. Triangle Data (Faces, Colors, and Shading Channels)
AllocateSoA("int[?]", MAX_TRIS, {"Tri_V1", "Tri_V2", "Tri_V3"})
AllocateSoA("float[?]", MAX_TRIS, {"Tri_A", "Tri_R", "Tri_G", "Tri_B"})
AllocateSoA("uint32_t[?]", MAX_TRIS, {"Tri_Color", "Tri_BakedColor"})

-- 6. Physics Collision (Bounding Volumes)
AllocateSoA("float[?]", MAX_BOUND_SPHERES, {"BoundSphere_X", "BoundSphere_Y", "BoundSphere_Z", "BoundSphere_RSq"})
AllocateSoA("uint8_t[?]", MAX_BOUND_SPHERES, {"BoundSphere_Mode"})

AllocateSoA("float[?]", MAX_BOUND_BOXES, {
    "BoundBox_X", "BoundBox_Y", "BoundBox_Z",
    "BoundBox_HW", "BoundBox_HH", "BoundBox_HT",
    "BoundBox_FWX", "BoundBox_FWY", "BoundBox_FWZ",
    "BoundBox_RTX", "BoundBox_RTY", "BoundBox_RTZ",
    "BoundBox_UPX", "BoundBox_UPY", "BoundBox_UPZ"
})
AllocateSoA("uint8_t[?]", MAX_BOUND_BOXES, {"BoundBox_Mode"})

-- ==========================================
-- [4] GLOBAL SINGLETONS & STRUCTS
-- ==========================================
ffi.cdef[[
    typedef struct {
        float minX, minY, minZ;
        float maxX, maxY, maxZ;
        bool isActive;
    } GlobalCage;

    typedef struct {
        float x, y, z;
        float yaw, pitch;
        float fov;
        float fwx, fwy, fwz;
        float rtx, rty, rtz;
        float upx, upy, upz;
    } CameraState;
]]

UniverseCage = ffi.new("GlobalCage", {-15000, -4000, -15000, 15000, 15000, 15000, true})
MainCamera = ffi.new("CameraState") -- Officially part of the Motherboard now!

-- ========================================================================
-- [5] THE SLICE CHECKOUT SYSTEM (The Engine's Core Protection)
-- ========================================================================
Memory = {}

function Memory.ClaimObjects(count)
    local start_id = next_obj_id
    next_obj_id = next_obj_id + count
    if next_obj_id > MAX_OBJS then error("FATAL: Out of Object Memory!") end
    return start_id, next_obj_id - 1
end

function Memory.ClaimGeometry(v_count, t_count)
    local v_start, t_start = next_vert_id, next_tri_id
    next_vert_id = next_vert_id + v_count
    next_tri_id = next_tri_id + t_count
    if next_vert_id > MAX_VERTS or next_tri_id > MAX_TRIS then error("FATAL: Out of Geometry Memory!") end
    return v_start, t_start
end

function Memory.ClaimBoundSpheres(count)
    local start_id = next_sphere_id
    next_sphere_id = next_sphere_id + count
    if next_sphere_id > MAX_BOUND_SPHERES then error("FATAL: Out of Bounding Sphere Memory!") end
    return start_id, next_sphere_id - 1
end

function Memory.ClaimBoundBoxes(count)
    local start_id = next_box_id
    next_box_id = next_box_id + count
    if next_box_id > MAX_BOUND_BOXES then error("FATAL: Out of Bounding Box Memory!") end
    return start_id, next_box_id - 1
end

return Memory
