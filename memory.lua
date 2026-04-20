-- memory.lua
local ffi = require("ffi")

-- 1. The Raw Universe Limits
MAX_OBJS = 10000
MAX_VERTS = 500000
MAX_TRIS = 1000000

-- 2. The Global Allocator State
local next_obj_id = 0
local next_vert_id = 0
local next_tri_id = 0

-- 3. The Meta-Allocator Function
local function AllocateSoA(type_str, size, names)
    for i = 1, #names do
        _G[names[i]] = ffi.new(type_str, size)
    end
end

-- 4. Allocate the Raw Arrays (No specific prefixes anymore!)
AllocateSoA("float[?]", MAX_OBJS, {"Obj_X", "Obj_Y", "Obj_Z", "Obj_Radius"})
AllocateSoA("int[?]", MAX_OBJS, {"Obj_VertStart", "Obj_VertCount", "Obj_TriStart", "Obj_TriCount"})
-- Add your FWX/RTX/UPX matrices here as needed...

AllocateSoA("float[?]", MAX_VERTS, {"Vert_LX", "Vert_LY", "Vert_LZ", "Vert_PX", "Vert_PY", "Vert_PZ"})
AllocateSoA("bool[?]", MAX_VERTS, {"Vert_Valid"})

AllocateSoA("int[?]", MAX_TRIS, {"Tri_V1", "Tri_V2", "Tri_V3"})
AllocateSoA("uint32_t[?]", MAX_TRIS, {"Tri_Color", "Tri_BakedColor"})

-- ========================================================================
-- THE SLICE CHECKOUT SYSTEM (The secret weapon)
-- Modules call this to claim their exclusive memory block.
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

return Memory
