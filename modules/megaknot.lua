local bit = require("bit")
local pi, cos, sin = math.pi, math.cos, math.sin
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local RenderMeshFactory = require("render_mesh")

return function(
    Memory, MainCamera,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
    Obj_RotSpeedYaw, Obj_RotSpeedPitch,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    local Megaknot = {}
    local my_obj_start

    local DrawMesh = RenderMeshFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    function Megaknot.Init()
        my_obj_start, _ = Memory.ClaimObjects(1)
        local id = my_obj_start
        local cx, cy, cz = 0, 0, 0
        local scale = 1500
        local tubeRadius = 400
        local p, q = 4, 9
        local segments, sides = 1200, 250
        local baseColor = 0xFFFF00FF
        local vCount, tCount = segments * sides, segments * sides * 2
        local vStart, tStart = Memory.ClaimGeometry(vCount, tCount)

        Obj_X[id], Obj_Y[id], Obj_Z[id] = cx, cy, cz
        Obj_Yaw[id], Obj_Pitch[id] = 0, 0
        Obj_RotSpeedYaw[id] = 0.8
        Obj_RotSpeedPitch[id] = -0.4
        Obj_Radius[id] = scale * 3
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0
        Obj_VertStart[id], Obj_VertCount[id] = vStart, vCount
        Obj_TriStart[id], Obj_TriCount[id] = tStart, tCount

        local function getKnotPos(u)
            local theta = u * pi * 2
            local r = scale * (2 + cos(p * theta))
            return r * cos(q * theta), r * sin(p * theta), r * sin(q * theta)
        end

        for i = 0, segments - 1 do
            local u = i / segments
            local p1 = {getKnotPos(u)}
            local p2 = {getKnotPos((i + 1) / segments)}
            local T = {p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]}
            local B = {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]}
            local N = {T[2]*B[3] - T[3]*B[2], T[3]*B[1] - T[1]*B[3], T[1]*B[2] - T[2]*B[1]}

            local lenN = sqrt(N[1]^2 + N[2]^2 + N[3]^2)
            if lenN == 0 then lenN = 1 end
            N = {N[1]/lenN, N[2]/lenN, N[3]/lenN}

            local bitan = {T[2]*N[3] - T[3]*N[2], T[3]*N[1] - T[1]*N[3], T[1]*N[2] - T[2]*N[1]}
            local lenB = sqrt(bitan[1]^2 + bitan[2]^2 + bitan[3]^2)
            if lenB == 0 then lenB = 1 end
            bitan = {bitan[1]/lenB, bitan[2]/lenB, bitan[3]/lenB}

            for j = 0, sides - 1 do
                local v_angle = (j / sides) * pi * 2
                local cosV, sinV = cos(v_angle) * tubeRadius, sin(v_angle) * tubeRadius
                local vIdx = vStart + i * sides + j
                Vert_LX[vIdx] = p1[1] + cosV * N[1] + sinV * bitan[1]
                Vert_LY[vIdx] = p1[2] + cosV * N[2] + sinV * bitan[2]
                Vert_LZ[vIdx] = p1[3] + cosV * N[3] + sinV * bitan[3]
            end
        end

        local tIdx = tStart
        for i = 0, segments - 1 do
            local next_i = (i + 1) % segments
            for j = 0, sides - 1 do
                local next_j = (j + 1) % sides
                local a, b_idx = vStart + i * sides + j, vStart + next_i * sides + j
                local c, d = vStart + next_i * sides + next_j, vStart + i * sides + next_j

                local col = ((i + j) % 2 == 0) and baseColor or 0xFF444444
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx
                Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c
                Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
            end
        end
    end

    function Megaknot.Tick(dt)
        local id = my_obj_start
        local y_val = Obj_Yaw[id] + Obj_RotSpeedYaw[id] * dt
        local p_val = Obj_Pitch[id] + Obj_RotSpeedPitch[id] * dt
        Obj_Yaw[id], Obj_Pitch[id] = y_val, p_val

        local cy, sy = cos(y_val), sin(y_val)
        local cp, sp = cos(p_val), sin(p_val)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = sy * cp, sp, cy * cp
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = cy, 0, -sy
        Obj_UPX[id] = Obj_FWY[id] * Obj_RTZ[id]
        Obj_UPY[id] = Obj_FWZ[id] * Obj_RTX[id] - Obj_FWX[id] * Obj_RTZ[id]
        Obj_UPZ[id] = -Obj_FWY[id] * Obj_RTX[id]
    end

    function Megaknot.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_start, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Megaknot
end
