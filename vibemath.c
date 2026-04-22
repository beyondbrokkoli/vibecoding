#include <immintrin.h> // The magic header for SIMD intrinsics
#include <stdint.h>
#include <stdbool.h>
#include <math.h> // Add this at the top of vibemath.c!

// We export this so LuaJIT can see it
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

EXPORT void simd_project_vertices(
    int count,
    // Inputs (Local Coords)
    float* lx, float* ly, float* lz,
    // Outputs (Screen Coords & Validity)
    float* px, float* py, float* pz, bool* valid,
    
    // Object Matrix
    float ox, float oy, float oz,
    float rx, float ry, float rz, float ux, float uy, float uz, float fx, float fy, float fz,
    
    // Camera Matrix & Screen Info
    float cpx, float cpy, float cpz,
    float cfw_x, float cfw_y, float cfw_z,
    float crt_x, float crt_z,
    float cup_x, float cup_y, float cup_z,
    float cam_fov, float half_w, float half_h
) {
    // 1. Broadcast our scalar values across 8-wide AVX registers
    __m256 v_ox = _mm256_set1_ps(ox); __m256 v_oy = _mm256_set1_ps(oy); __m256 v_oz = _mm256_set1_ps(oz);
    __m256 v_rx = _mm256_set1_ps(rx); __m256 v_ry = _mm256_set1_ps(ry); __m256 v_rz = _mm256_set1_ps(rz);
    __m256 v_ux = _mm256_set1_ps(ux); __m256 v_uy = _mm256_set1_ps(uy); __m256 v_uz = _mm256_set1_ps(uz);
    __m256 v_fx = _mm256_set1_ps(fx); __m256 v_fy = _mm256_set1_ps(fy); __m256 v_fz = _mm256_set1_ps(fz);

    int i = 0;
    
    // 2. The SIMD Loop (Processes 8 vertices per iteration)
    for (; i <= count - 8; i += 8) {
        // Load 8 X, Y, and Z local coordinates (unaligned load is safer for FFI arrays)
        __m256 v_lx = _mm256_loadu_ps(&lx[i]);
        __m256 v_ly = _mm256_loadu_ps(&ly[i]);
        __m256 v_lz = _mm256_loadu_ps(&lz[i]);

        // Math: wx = ox + lvx*rx + lvy*ux + lvz*fx
        __m256 v_wx = _mm256_fmadd_ps(v_lz, v_fx, _mm256_fmadd_ps(v_ly, v_ux, _mm256_fmadd_ps(v_lx, v_rx, v_ox)));
        __m256 v_wy = _mm256_fmadd_ps(v_lz, v_fy, _mm256_fmadd_ps(v_ly, v_uy, _mm256_fmadd_ps(v_lx, v_ry, v_oy)));
        __m256 v_wz = _mm256_fmadd_ps(v_lz, v_fz, _mm256_fmadd_ps(v_ly, v_uz, _mm256_fmadd_ps(v_lx, v_rz, v_oz)));

        // 1. Calculate View Deltas (vdx = wx - cpx)
        __m256 v_vdx = _mm256_sub_ps(v_wx, _mm256_set1_ps(cpx));
        __m256 v_vdy = _mm256_sub_ps(v_wy, _mm256_set1_ps(cpy));
        __m256 v_vdz = _mm256_sub_ps(v_wz, _mm256_set1_ps(cpz));

        // 2. Calculate Depth (cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z)
        __m256 v_cz = _mm256_fmadd_ps(v_vdz, _mm256_set1_ps(cfw_z), 
                      _mm256_fmadd_ps(v_vdy, _mm256_set1_ps(cfw_y), 
                      _mm256_mul_ps(v_vdx, _mm256_set1_ps(cfw_x))));

        // 3. THE RICH MAN'S IF STATEMENT (The Mask)
        // Compare: is cz >= 0.1? 
        __m256 v_mask = _mm256_cmp_ps(v_cz, _mm256_set1_ps(0.1f), _CMP_GE_OQ);
        int bitmask = _mm256_movemask_ps(v_mask); // Crushes 256 bits down to an 8-bit integer!

        // 4. The Perspective Divide (Do it for all 8, even the invalid ones!)
        __m256 v_f = _mm256_div_ps(_mm256_set1_ps(cam_fov), v_cz);

        // 5. Calculate Screen X and Y
        __m256 v_px = _mm256_add_ps(_mm256_set1_ps(half_w), 
                      _mm256_mul_ps(v_f, _mm256_add_ps(_mm256_mul_ps(v_vdx, _mm256_set1_ps(crt_x)), 
                                                       _mm256_mul_ps(v_vdz, _mm256_set1_ps(crt_z)))));
                                                       
        __m256 v_py = _mm256_add_ps(_mm256_set1_ps(half_h), 
                      _mm256_mul_ps(v_f, _mm256_fmadd_ps(v_vdz, _mm256_set1_ps(cup_z),
                                         _mm256_fmadd_ps(v_vdy, _mm256_set1_ps(cup_y), 
                                         _mm256_mul_ps(v_vdx, _mm256_set1_ps(cup_x))))));

        // 6. Ground the ball: Store to memory
        _mm256_storeu_ps(&px[i], v_px);
        _mm256_storeu_ps(&py[i], v_py);
        _mm256_storeu_ps(&pz[i], _mm256_mul_ps(v_cz, _mm256_set1_ps(1.004f)));

        // Extract the 8 bits into the boolean array
        valid[i+0] = (bitmask & (1 << 0)) != 0;
        valid[i+1] = (bitmask & (1 << 1)) != 0;
        valid[i+2] = (bitmask & (1 << 2)) != 0;
        valid[i+3] = (bitmask & (1 << 3)) != 0;
        valid[i+4] = (bitmask & (1 << 4)) != 0;
        valid[i+5] = (bitmask & (1 << 5)) != 0;
        valid[i+6] = (bitmask & (1 << 6)) != 0;
        valid[i+7] = (bitmask & (1 << 7)) != 0;

    }

    // 3. The Tail Loop (For leftover vertices if count is not a multiple of 8)
    for (; i < count; i++) {
        // Calculate World Coords in temporary variables
        float temp_wx = ox + lx[i]*rx + ly[i]*ux + lz[i]*fx;
        float temp_wy = oy + lx[i]*ry + ly[i]*uy + lz[i]*fy;
        float temp_wz = oz + lx[i]*rz + ly[i]*uz + lz[i]*fz;

        // View Deltas
        float vdx = temp_wx - cpx;
        float vdy = temp_wy - cpy;
        float vdz = temp_wz - cpz;

        // Depth
        float cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z;

        // Scalar Branching (Perfectly fine for the last few leftover vertices)
        if (cz < 0.1f) {
            valid[i] = false;
        } else {
            float f = cam_fov / cz;
            px[i] = half_w + (vdx*crt_x + vdz*crt_z) * f;
            py[i] = half_h + (vdx*cup_x + vdy*cup_y + vdz*cup_z) * f;
            pz[i] = cz * 1.004f;
            valid[i] = true;
        }
    }
}

EXPORT void process_triangles_twotone(
    int tCount,
    // Indices & Validity
    int* v1, int* v2, int* v3, bool* vert_valid,
    // Coordinates
    float* px, float* py, float* pz,
    float* lx, float* ly, float* lz,
    // Colors & Outputs
    uint32_t* baked_color, uint32_t* shaded_color, bool* tri_valid,
    // Object Rotation Matrix
    float rx, float ry, float rz,
    float ux, float uy, float uz,
    float fx, float fy, float fz,
    // Sun Vector
    float sun_x, float sun_y, float sun_z
) {
    for (int i = 0; i < tCount; i++) {
        int i1 = v1[i];
        int i2 = v2[i];
        int i3 = v3[i];

        // 1. Assembly Culling
        if (!vert_valid[i1] || !vert_valid[i2] || !vert_valid[i3]) {
            tri_valid[i] = false;
            continue;
        }

        // Fetch Screen Coords
        float px1 = px[i1], py1 = py[i1];
        float px2 = px[i2], py2 = py[i2];
        float px3 = px[i3], py3 = py[i3];

        // 2. Screen-Space Winding Order
        float cross = (px2 - px1) * (py3 - py1) - (py2 - py1) * (px3 - px1);
        bool is_inside = cross >= 0;

        // 3. Base Color Swap
        uint32_t orig_col = baked_color[i];
        if (is_inside) {
            // Purple encoded as 0xFF << 24 | B << 16 | G << 8 | R
            orig_col = 0xFFFF00AA; 
        }

        // 4. Local Edges & Normal (Cross Product)
        float ax = lx[i2] - lx[i1], ay = ly[i2] - ly[i1], az = lz[i2] - lz[i1];
        float bx = lx[i3] - lx[i1], by = ly[i3] - ly[i1], bz = lz[i3] - lz[i1];

        float lnx = ay * bz - az * by;
        float lny = az * bx - ax * bz;
        float lnz = ax * by - ay * bx;

        // 5. Transform to World Normal
        float wnx = lnx * rx + lny * ux + lnz * fx;
        float wny = lnx * ry + lny * uy + lnz * fy;
        float wnz = lnx * rz + lny * uz + lnz * fz;

        // Normalize
        float inv_len = 1.0f / sqrtf(wnx*wnx + wny*wny + wnz*wnz + 0.000001f);
        wnx *= inv_len; wny *= inv_len; wnz *= inv_len;

        // 6. Lambertian Lighting
        float dot = wnx * sun_x + wny * sun_y + wnz * sun_z;
        if (is_inside) dot = -dot; // Flip normal for inside faces

        // Clamp Light (0.2 to 1.0)
        float light = dot < 0.2f ? 0.2f : (dot > 1.0f ? 1.0f : dot);

        // 7. Apply Light to Color (Fast bitwise math)
        uint32_t b = (uint32_t)(((orig_col >> 16) & 0xFF) * light);
        uint32_t g = (uint32_t)(((orig_col >> 8) & 0xFF) * light);
        uint32_t r = (uint32_t)((orig_col & 0xFF) * light);

        shaded_color[i] = 0xFF000000 | (b << 16) | (g << 8) | r;
        tri_valid[i] = true;
    }
}
// Blasts 8 pixels and 8 Z-values to memory per clock cycle
EXPORT void simd_clear_buffers(
    uint32_t* screen, 
    float* zbuffer, 
    uint32_t clear_color, 
    float clear_z, 
    int pixel_count
) {
    // 1. Pack 8 identical colors and 8 identical Z-values into AVX registers
    __m256i v_color = _mm256_set1_epi32(clear_color);
    __m256 v_z = _mm256_set1_ps(clear_z);

    int i = 0;
    // 2. The AVX Loop (Blindly overwrite 8 pixels at a time)
    for (; i <= pixel_count - 8; i += 8) {
        // Cast the screen pointer to a 256-bit integer pointer and fire!
        _mm256_storeu_si256((__m256i*)&screen[i], v_color);
        // Fire the Z-buffer floats!
        _mm256_storeu_ps(&zbuffer[i], v_z);
    }

    // 3. The Tail Loop (For any leftover pixels if screen isn't perfectly divisible by 8)
    for (; i < pixel_count; i++) {
        screen[i] = clear_color;
        zbuffer[i] = clear_z;
    }
}
