local ffi = require("ffi")
MAX_OBJS = 10000
MAX_VERTS = 500000
MAX_TRIS = 1000000
local next_obj_id = 0
local next_vert_id = 0
local next_tri_id = 0
local function AllocateSoA(type_str, size, names)
for i = 1, #names do
_G[names[i]] = ffi.new(type_str, size)
end
end
AllocateSoA("float[?]", MAX_OBJS, {"Obj_X", "Obj_Y", "Obj_Z", "Obj_Radius"})
AllocateSoA("int[?]", MAX_OBJS, {"Obj_VertStart", "Obj_VertCount", "Obj_TriStart", "Obj_TriCount"})
AllocateSoA("float[?]", MAX_VERTS, {"Vert_LX", "Vert_LY", "Vert_LZ", "Vert_PX", "Vert_PY", "Vert_PZ"})
AllocateSoA("bool[?]", MAX_VERTS, {"Vert_Valid"})
AllocateSoA("int[?]", MAX_TRIS, {"Tri_V1", "Tri_V2", "Tri_V3"})
AllocateSoA("uint32_t[?]", MAX_TRIS, {"Tri_Color", "Tri_BakedColor"})
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
