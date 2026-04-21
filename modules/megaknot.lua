local function CreateTorusKnot(slice_start, slice_max, count_ptr, cx, cy, cz, scale, tubeRadius, p, q, segments, sides, baseColor)
    local vCount, tCount = segments * sides, segments * sides * 2
    local id = AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, scale * 3)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]

    local function getKnotPos(u)
        local theta = u * pi * 2
        local r = scale * (2 + cos(p * theta))
        return r * cos(q * theta), r * sin(p * theta), r * sin(q * theta)
    end

    -- 1. Calculate Frenet-Serret Frames and Vertices
    for i = 0, segments - 1 do
        local u = i / segments
        local p1 = {getKnotPos(u)}
        local p2 = {getKnotPos((i + 1) / segments)}
        local T = {p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]}
        local B = {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]}
        local N = {T[2]*B[3] - T[3]*B[2], T[3]*B[1] - T[1]*B[3], T[1]*B[2] - T[2]*B[1]}

        local lenN = math.sqrt(N[1]^2 + N[2]^2 + N[3]^2)
        if lenN == 0 then lenN = 1 end
        N = {N[1]/lenN, N[2]/lenN, N[3]/lenN}

        local bitan = {T[2]*N[3] - T[3]*N[2], T[3]*N[1] - T[1]*N[3], T[1]*N[2] - T[2]*N[1]}
        local lenB = math.sqrt(bitan[1]^2 + bitan[2]^2 + bitan[3]^2)
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

    -- 2. Stitch the Triangles
    local tIdx = tStart
    for i = 0, segments - 1 do
        local next_i = (i + 1) % segments
        for j = 0, sides - 1 do
            local next_j = (j + 1) % sides
            local a, b_idx = vStart + i * sides + j, vStart + next_i * sides + j
            local c, d = vStart + next_i * sides + next_j, vStart + i * sides + next_j

            -- Checkerboard styling
            local col = ((i + j) % 2 == 0) and baseColor or 0xFF444444
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx; Tri_Color[tIdx] = col; tIdx = tIdx + 1
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        end
    end
    return id
end

-- ========================================================================
-- THE MEGAKNOT WRAPPER
-- Completely decoupled from the old "api" injection.
-- ========================================================================
function CreateMegaknot(slice_start, slice_max, count_ptr, x, y, z)
    -- FFI Endianness: AABBGGRR. Hot Magenta!
    local magenta = 0xFFFF00FF

    -- Parameters: radius=1500, tube=400, p=4, q=9
    -- Resolution: 800 segments * 150 sides = 120,000 Vertices & 240,000 Triangles
    local id = Factory.CreateTorusKnot(
        slice_start, slice_max, count_ptr,
        x, y, z,
        1500, 400, 4, 9,
        800, 150, magenta
    )

    if id then
        -- Override default allocations
        Obj_HomeIdx[id] = -1
        Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = 0, 0, 0
        Obj_RotSpeedYaw[id] = 0.8
        Obj_RotSpeedPitch[id] = -0.4
    end

    return id
end

