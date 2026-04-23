local ffi = require("ffi")
local VibeMath = require("load")

return function(
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    -- 1. Create and populate the memory struct ONCE at scene creation
    local render_mem = ffi.new("RenderMemory")
    render_mem.Obj_X, render_mem.Obj_Y, render_mem.Obj_Z, render_mem.Obj_Radius = Obj_X, Obj_Y, Obj_Z, Obj_Radius
    render_mem.Obj_FWX, render_mem.Obj_FWY, render_mem.Obj_FWZ = Obj_FWX, Obj_FWY, Obj_FWZ
    render_mem.Obj_RTX, render_mem.Obj_RTY, render_mem.Obj_RTZ = Obj_RTX, Obj_RTY, Obj_RTZ
    render_mem.Obj_UPX, render_mem.Obj_UPY, render_mem.Obj_UPZ = Obj_UPX, Obj_UPY, Obj_UPZ
    render_mem.Obj_VertStart, render_mem.Obj_VertCount = Obj_VertStart, Obj_VertCount
    render_mem.Obj_TriStart, render_mem.Obj_TriCount = Obj_TriStart, Obj_TriCount

    render_mem.Vert_LX, render_mem.Vert_LY, render_mem.Vert_LZ = Vert_LX, Vert_LY, Vert_LZ
    render_mem.Vert_PX, render_mem.Vert_PY, render_mem.Vert_PZ = Vert_PX, Vert_PY, Vert_PZ
    render_mem.Vert_Valid = Vert_Valid

    render_mem.Tri_V1, render_mem.Tri_V2, render_mem.Tri_V3 = Tri_V1, Tri_V2, Tri_V3
    render_mem.Tri_BakedColor = Tri_BakedColor
    render_mem.Tri_ShadedColor = _G.Tri_ShadedColor
    render_mem.Tri_Valid = _G.Tri_Valid

    return function(start_id, end_id, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        local sun_x, sun_y, sun_z = 0.577, -0.577, 0.577

        -- 2. FIRE THE BATCH (Now completely under the FFI argument limits!)
        VibeMath.simd_render_world_batch(
            start_id, end_id,
            MainCamera, -- Passes the full CameraState struct pointer effortlessly
            CANVAS_W * 0.5, CANVAS_H * 0.5,
            sun_x, sun_y, sun_z,
            render_mem, -- Passes all 30+ array pointers as a single C struct
            ScreenPtr, ZBuffer, CANVAS_W, CANVAS_H
        )
    end
end
