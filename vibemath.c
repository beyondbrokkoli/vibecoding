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
    // 1. Broadcast EVERYTHING outside the loop (Saves massive register pressure)
    __m256 v_ox = _mm256_set1_ps(ox); __m256 v_oy = _mm256_set1_ps(oy); __m256 v_oz = _mm256_set1_ps(oz);
    __m256 v_rx = _mm256_set1_ps(rx); __m256 v_ry = _mm256_set1_ps(ry); __m256 v_rz = _mm256_set1_ps(rz);
    __m256 v_ux = _mm256_set1_ps(ux); __m256 v_uy = _mm256_set1_ps(uy); __m256 v_uz = _mm256_set1_ps(uz);
    __m256 v_fx = _mm256_set1_ps(fx); __m256 v_fy = _mm256_set1_ps(fy); __m256 v_fz = _mm256_set1_ps(fz);

    __m256 v_cpx = _mm256_set1_ps(cpx); __m256 v_cpy = _mm256_set1_ps(cpy); __m256 v_cpz = _mm256_set1_ps(cpz);
    __m256 v_cfwx = _mm256_set1_ps(cfw_x); __m256 v_cfwy = _mm256_set1_ps(cfw_y); __m256 v_cfwz = _mm256_set1_ps(cfw_z);
    __m256 v_crtx = _mm256_set1_ps(crt_x); __m256 v_crtz = _mm256_set1_ps(crt_z);
    __m256 v_cupx = _mm256_set1_ps(cup_x); __m256 v_cupy = _mm256_set1_ps(cup_y); __m256 v_cupz = _mm256_set1_ps(cup_z);
    __m256 v_cam_fov = _mm256_set1_ps(cam_fov);
    __m256 v_half_w = _mm256_set1_ps(half_w); __m256 v_half_h = _mm256_set1_ps(half_h);
    __m256 v_two = _mm256_set1_ps(2.0f); // Needed for Newton-Raphson

    int i = 0;

    for (; i <= count - 8; i += 8) {
        __m256 v_lx = _mm256_loadu_ps(&lx[i]);
        __m256 v_ly = _mm256_loadu_ps(&ly[i]);
        __m256 v_lz = _mm256_loadu_ps(&lz[i]);

        __m256 v_wx = _mm256_fmadd_ps(v_lz, v_fx, _mm256_fmadd_ps(v_ly, v_ux, _mm256_fmadd_ps(v_lx, v_rx, v_ox)));
        __m256 v_wy = _mm256_fmadd_ps(v_lz, v_fy, _mm256_fmadd_ps(v_ly, v_uy, _mm256_fmadd_ps(v_lx, v_ry, v_oy)));
        __m256 v_wz = _mm256_fmadd_ps(v_lz, v_fz, _mm256_fmadd_ps(v_ly, v_uz, _mm256_fmadd_ps(v_lx, v_rz, v_oz)));

        __m256 v_vdx = _mm256_sub_ps(v_wx, v_cpx);
        __m256 v_vdy = _mm256_sub_ps(v_wy, v_cpy);
        __m256 v_vdz = _mm256_sub_ps(v_wz, v_cpz);

        __m256 v_cz = _mm256_fmadd_ps(v_vdz, v_cfwz, _mm256_fmadd_ps(v_vdy, v_cfwy, _mm256_mul_ps(v_vdx, v_cfwx)));

        __m256 v_mask = _mm256_cmp_ps(v_cz, _mm256_set1_ps(0.1f), _CMP_GE_OQ);
        int bitmask = _mm256_movemask_ps(v_mask);

        // --- NEWTON-RAPHSON FAST DIVISION ---
        // 1. Get fast hardware approximation of 1.0 / cz (~11 bits precision)
        __m256 v_rcp = _mm256_rcp_ps(v_cz);
        // 2. Refine precision using Newton-Raphson: rcp = rcp * (2.0 - cz * rcp) (~22 bits precision)
        // _mm256_fnmadd_ps does -(cz * rcp) + 2.0
        __m256 v_rcp_refined = _mm256_mul_ps(v_rcp, _mm256_fnmadd_ps(v_cz, v_rcp, v_two));
        // 3. Multiply fov by the refined reciprocal
        __m256 v_f = _mm256_mul_ps(v_cam_fov, v_rcp_refined);

        __m256 v_px = _mm256_add_ps(v_half_w, _mm256_mul_ps(v_f, _mm256_add_ps(_mm256_mul_ps(v_vdx, v_crtx), _mm256_mul_ps(v_vdz, v_crtz))));
        __m256 v_py = _mm256_add_ps(v_half_h, _mm256_mul_ps(v_f, _mm256_fmadd_ps(v_vdz, v_cupz, _mm256_fmadd_ps(v_vdy, v_cupy, _mm256_mul_ps(v_vdx, v_cupx)))));

        _mm256_storeu_ps(&px[i], v_px);
        _mm256_storeu_ps(&py[i], v_py);
        _mm256_storeu_ps(&pz[i], _mm256_mul_ps(v_cz, _mm256_set1_ps(1.004f)));

        valid[i+0] = (bitmask & (1 << 0)) != 0;
        valid[i+1] = (bitmask & (1 << 1)) != 0;
        valid[i+2] = (bitmask & (1 << 2)) != 0;
        valid[i+3] = (bitmask & (1 << 3)) != 0;
        valid[i+4] = (bitmask & (1 << 4)) != 0;
        valid[i+5] = (bitmask & (1 << 5)) != 0;
        valid[i+6] = (bitmask & (1 << 6)) != 0;
        valid[i+7] = (bitmask & (1 << 7)) != 0;
    }

    // Tail loop remains unchanged
    for (; i < count; i++) {
        float temp_wx = ox + lx[i]*rx + ly[i]*ux + lz[i]*fx;
        float temp_wy = oy + lx[i]*ry + ly[i]*uy + lz[i]*fy;
        float temp_wz = oz + lx[i]*rz + ly[i]*uz + lz[i]*fz;
        float vdx = temp_wx - cpx;
        float vdy = temp_wy - cpy;
        float vdz = temp_wz - cpz;
        float cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z;

        if (cz < 0.1f) {
            valid[i] = false;
        } else {
            float f = cam_fov / cz; // Scalar division is fine here
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
EXPORT void process_triangles_cull(
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

        // 1. Frustum/Vertex Culling
        if (!vert_valid[i1] || !vert_valid[i2] || !vert_valid[i3]) {
            tri_valid[i] = false;
            continue;
        }

        // Fetch Screen Coords
        float px1 = px[i1], py1 = py[i1];
        float px2 = px[i2], py2 = py[i2];
        float px3 = px[i3], py3 = py[i3];

        // 2. BACKFACE CULLING (The Magic)
        // If cross product is >= 0, it's facing away from the camera.
        float cross = (px2 - px1) * (py3 - py1) - (py2 - py1) * (px3 - px1);
        if (cross >= 0) {
            tri_valid[i] = false; // Kill the triangle!
            continue;             // Skip all lighting math!
        }

        uint32_t orig_col = baked_color[i];

        // 3. Local Edges & Normal
        float ax = lx[i2] - lx[i1], ay = ly[i2] - ly[i1], az = lz[i2] - lz[i1];
        float bx = lx[i3] - lx[i1], by = ly[i3] - ly[i1], bz = lz[i3] - lz[i1];

        float lnx = ay * bz - az * by;
        float lny = az * bx - ax * bz;
        float lnz = ax * by - ay * bx;

        // 4. Transform to World Normal
        float wnx = lnx * rx + lny * ux + lnz * fx;
        float wny = lnx * ry + lny * uy + lnz * fy;
        float wnz = lnx * rz + lny * uz + lnz * fz;

        // Normalize
        float inv_len = 1.0f / sqrtf(wnx*wnx + wny*wny + wnz*wnz + 0.000001f);
        wnx *= inv_len; wny *= inv_len; wnz *= inv_len;

        // 5. Lambertian Lighting
        float dot = wnx * sun_x + wny * sun_y + wnz * sun_z;

        // Clamp Light (0.2 to 1.0)
        float light = dot < 0.2f ? 0.2f : (dot > 1.0f ? 1.0f : dot);

        // 6. Apply Light to Color
        uint32_t b = (uint32_t)(((orig_col >> 16) & 0xFF) * light);
        uint32_t g = (uint32_t)(((orig_col >> 8) & 0xFF) * light);
        uint32_t r = (uint32_t)((orig_col & 0xFF) * light);

        shaded_color[i] = 0xFF000000 | (b << 16) | (g << 8) | r;
        tri_valid[i] = true; // Triangle survives!
    }
}
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
// ========================================================================
// FAST AVX2 TRIGONOMETRY (Minimax Approximations)
// ========================================================================

// 1. Wraps any angle into the [-PI, PI] range so our polynomial works
static inline __m256 wrap_pi_avx(__m256 x) {
    __m256 inv_two_pi = _mm256_set1_ps(1.0f / (2.0f * M_PI));
    __m256 two_pi = _mm256_set1_ps(2.0f * M_PI);
    // q = round(x / 2PI)
    __m256 q = _mm256_round_ps(_mm256_mul_ps(x, inv_two_pi), _MM_FROUND_TO_NEAREST_INT | _MM_FROUND_NO_EXC);
    // return x - q * 2PI
    return _mm256_fnmadd_ps(q, two_pi, x);
}

// 2. High-speed Sine approximation for 8 floats simultaneously
static inline __m256 fast_sin_avx(__m256 x) {
    x = wrap_pi_avx(x); // Keep it within bounds

    // Bhaskara I / Minimax base polynomial: sin(x) ~ (4/pi)*x - (4/pi^2)*x*|x|
    __m256 B = _mm256_set1_ps(4.0f / M_PI);
    __m256 C = _mm256_set1_ps(-4.0f / (M_PI * M_PI));

    // bitwise absolute value (clears the sign bit)
    __m256 x_abs = _mm256_andnot_ps(_mm256_set1_ps(-0.0f), x);
    __m256 y = _mm256_fmadd_ps(_mm256_mul_ps(C, x_abs), x, _mm256_mul_ps(B, x));

    // Extra precision refinement step
    __m256 P = _mm256_set1_ps(0.225f);
    __m256 y_abs = _mm256_andnot_ps(_mm256_set1_ps(-0.0f), y);
    return _mm256_fmadd_ps(_mm256_fmadd_ps(y_abs, y, _mm256_sub_ps(_mm256_setzero_ps(), y)), P, y);
}

// 3. Cosine is just Sine shifted by PI/2
static inline __m256 fast_cos_avx(__m256 x) {
    __m256 half_pi = _mm256_set1_ps(M_PI / 2.0f);
    return fast_sin_avx(_mm256_add_ps(x, half_pi));
}

// ========================================================================
// 4D DEMOSCENE NOISE (Trigonometric fBM)
// ========================================================================
// Pure ALU noise generation. Zero memory lookups. Blasts 8 coordinates at once.
static inline __m256 fast_trig_noise_avx(__m256 nx, __m256 ny, __m256 nz, __m256 time) {
    // OCTAVE 1: Low Frequency, High Amplitude (The base tectonic shifts)
    __m256 v1 = fast_sin_avx(_mm256_add_ps(_mm256_mul_ps(nx, _mm256_set1_ps(3.1f)), time));
    __m256 v2 = fast_cos_avx(_mm256_add_ps(_mm256_mul_ps(ny, _mm256_set1_ps(2.8f)), time));
    __m256 v3 = fast_sin_avx(_mm256_add_ps(_mm256_mul_ps(nz, _mm256_set1_ps(3.4f)), time));
    __m256 out = _mm256_add_ps(v1, _mm256_add_ps(v2, v3)); // Range ~[-3.0, 3.0]

    // OCTAVE 2: High Frequency, Low Amplitude (The boiling surface details)
    __m256 time2 = _mm256_mul_ps(time, _mm256_set1_ps(1.8f)); // Moves faster
    __m256 v4 = fast_sin_avx(_mm256_add_ps(_mm256_mul_ps(nx, _mm256_set1_ps(7.2f)), time2));
    __m256 v5 = fast_cos_avx(_mm256_add_ps(_mm256_mul_ps(ny, _mm256_set1_ps(6.5f)), time2));
    __m256 v6 = fast_sin_avx(_mm256_add_ps(_mm256_mul_ps(nz, _mm256_set1_ps(8.1f)), time2));
    __m256 oct2 = _mm256_mul_ps(_mm256_add_ps(v4, _mm256_add_ps(v5, v6)), _mm256_set1_ps(0.35f));

    out = _mm256_add_ps(out, oct2);
    
    // Normalize back to roughly [-1.0, 1.0]
    return _mm256_mul_ps(out, _mm256_set1_ps(0.25f));
}

// ========================================================================
// THE LIVING METAL VERTEX GENERATOR
// ========================================================================
EXPORT void generate_living_metal_vertices(
    float* lx, float* ly, float* lz,
    int latitudes, int longitudes,
    float base_radius, float time_alive
) {
    int idx = 0;
    
    __m256 v_base_radius = _mm256_set1_ps(base_radius);
    __m256 v_time = _mm256_set1_ps(time_alive);
    __m256 v_displacement_amp = _mm256_set1_ps(base_radius * 0.4f); // Noise alters radius by up to 40%

    float phi_step = ((float)M_PI * 2.0f) / longitudes;
    __m256 v_phi_step = _mm256_set1_ps(phi_step * 8.0f);
    
    for (int i = 0; i <= latitudes; i++) {
        float theta = ((float)i / latitudes) * (float)M_PI;
        __m256 v_ny = _mm256_set1_ps(cosf(theta));
        __m256 v_sin_theta = _mm256_set1_ps(sinf(theta));
        
        __m256 v_phi = _mm256_set_ps(
            phi_step * 7.0f, phi_step * 6.0f, phi_step * 5.0f, phi_step * 4.0f,
            phi_step * 3.0f, phi_step * 2.0f, phi_step * 1.0f, 0.0f
        );
        
        int j = 0;
        for (; j <= longitudes - 7; j += 8) {
            // 1. Calculate Base Sphere Normals (nx, ny, nz)
            __m256 v_nx = _mm256_mul_ps(v_sin_theta, fast_cos_avx(v_phi));
            __m256 v_nz = _mm256_mul_ps(v_sin_theta, fast_sin_avx(v_phi));
            
            // 2. Sample 4D Trigonometric Noise using the Normals & Time
            __m256 v_noise = fast_trig_noise_avx(v_nx, v_ny, v_nz, v_time);
            
            // 3. Displace Radius: final_r = base_radius + (noise * amplitude)
            __m256 v_final_r = _mm256_fmadd_ps(v_noise, v_displacement_amp, v_base_radius);
            
            // 4. Calculate Final XYZ (Local Coords)
            __m256 v_lx = _mm256_mul_ps(v_nx, v_final_r);
            __m256 v_ly = _mm256_mul_ps(v_ny, v_final_r);
            __m256 v_lz = _mm256_mul_ps(v_nz, v_final_r);
            
            // Dump to memory
            _mm256_storeu_ps(&lx[idx], v_lx);
            _mm256_storeu_ps(&ly[idx], v_ly);
            _mm256_storeu_ps(&lz[idx], v_lz);
            
            v_phi = _mm256_add_ps(v_phi, v_phi_step);
            idx += 8;
        }
        
        // Scalar Tail Loop
        for (; j <= longitudes; j++) {
            float phi = ((float)j / longitudes) * (float)M_PI * 2.0f;
            float nx = sinf(theta) * cosf(phi);
            float ny = cosf(theta);
            float nz = sinf(theta) * sinf(phi);
            
            // Scalar fallback for the noise
            float n1 = sinf(nx * 3.1f + time_alive) + cosf(ny * 2.8f + time_alive) + sinf(nz * 3.4f + time_alive);
            float t2 = time_alive * 1.8f;
            float n2 = (sinf(nx * 7.2f + t2) + cosf(ny * 6.5f + t2) + sinf(nz * 8.1f + t2)) * 0.35f;
            float noise = (n1 + n2) * 0.25f;
            
            float final_r = base_radius + (noise * (base_radius * 0.4f));
            
            lx[idx] = nx * final_r;
            ly[idx] = ny * final_r;
            lz[idx] = nz * final_r;
            idx++;
        }
    }
}

// ========================================================================
// THE VECTORIZED VERTEX GENERATOR
// ========================================================================

EXPORT void generate_smales_paradox_vertices(
    float* lx, float* ly, float* lz,
    int latitudes, int longitudes,
    float eversion, float bulge, float base_radius
) {
    int idx = 0;

    // Pre-load constants into 8-wide registers
    __m256 v_r_main = _mm256_set1_ps(base_radius * eversion);
    __m256 v_base_radius = _mm256_set1_ps(base_radius);
    __m256 v_bulge = _mm256_set1_ps(bulge);
    __m256 v_1_2 = _mm256_set1_ps(1.2f);
    __m256 v_0_5 = _mm256_set1_ps(0.5f);
    __m256 v_4_0 = _mm256_set1_ps(4.0f);

    // How much Phi changes per vertex horizontally
    float phi_step = ((float)M_PI * 2.0f) / longitudes;
    __m256 v_phi_step = _mm256_set1_ps(phi_step * 8.0f);

    for (int i = 0; i <= latitudes; i++) {
        // Theta is constant across the entire row, so we just scalar calculate it once and broadcast it!
        float theta = ((float)i / latitudes) * (float)M_PI;
        __m256 v_ny = _mm256_set1_ps(cosf(theta));
        __m256 v_sin_theta = _mm256_set1_ps(sinf(theta));
        __m256 v_twist = _mm256_set1_ps(sinf(theta * 2.0f));
        __m256 v_cos_theta_3 = _mm256_set1_ps(cosf(theta * 3.0f));

        // Initialize an 8-wide vector with 8 sequential Phi values
        __m256 v_phi = _mm256_set_ps(
            phi_step * 7.0f, phi_step * 6.0f, phi_step * 5.0f, phi_step * 4.0f,
            phi_step * 3.0f, phi_step * 2.0f, phi_step * 1.0f, 0.0f
        );

        int j = 0;
        // BLAST 8 VERTICES AT ONCE
        for (; j <= longitudes - 7; j += 8) {
            __m256 v_cos_phi = fast_cos_avx(v_phi);
            __m256 v_sin_phi = fast_sin_avx(v_phi);

            __m256 v_nx = _mm256_mul_ps(v_sin_theta, v_cos_phi);
            __m256 v_nz = _mm256_mul_ps(v_sin_theta, v_sin_phi);

            // waves = cos(phi * 4.0)
            __m256 v_waves = fast_cos_avx(_mm256_mul_ps(v_phi, v_4_0));

            // r_corrugate = base_radius * bulge * waves * twist * 1.2f
            __m256 v_r_corr = _mm256_mul_ps(v_base_radius,
                              _mm256_mul_ps(v_bulge,
                              _mm256_mul_ps(v_waves,
                              _mm256_mul_ps(v_twist, v_1_2))));

            // Calculate final XYZ
            __m256 v_lx = _mm256_fmadd_ps(v_nx, v_r_corr, _mm256_mul_ps(v_nx, v_r_main));

            __m256 v_ly_offset = _mm256_mul_ps(v_cos_theta_3, _mm256_mul_ps(v_base_radius, _mm256_mul_ps(v_bulge, v_0_5)));
            __m256 v_ly = _mm256_fmadd_ps(v_ny, v_r_main, v_ly_offset);

            __m256 v_lz = _mm256_fmadd_ps(v_nz, v_r_corr, _mm256_mul_ps(v_nz, v_r_main));

            // Dump directly to memory
            _mm256_storeu_ps(&lx[idx], v_lx);
            _mm256_storeu_ps(&ly[idx], v_ly);
            _mm256_storeu_ps(&lz[idx], v_lz);

            // Advance phi for the next 8 vertices
            v_phi = _mm256_add_ps(v_phi, v_phi_step);
            idx += 8;
        }
        
        // Scalar Tail Loop (for remainders)
        for (; j <= longitudes; j++) {
            float phi = ((float)j / longitudes) * (float)M_PI * 2.0f;
            float nx = sinf(theta) * cosf(phi);
            float nz = sinf(theta) * sinf(phi);
            float r_main = base_radius * eversion;
            float waves = cosf(phi * 4.0f);
            float twist = sinf(theta * 2.0f);
            float r_corrugate = base_radius * bulge * waves * twist * 1.2f;

            lx[idx] = nx * r_main + nx * r_corrugate;
            ly[idx] = cosf(theta) * r_main + (cosf(theta * 3.0f) * base_radius * bulge * 0.5f);
            lz[idx] = nz * r_main + nz * r_corrugate;
            idx++;
        }
    }
}

EXPORT void rasterize_triangles_batch(
    int tCount,
    int* v1, int* v2, int* v3, bool* tri_valid,
    float* px, float* py, float* pz,
    uint32_t* shaded_color,
    uint32_t* screen_buffer, float* z_buffer,
    int canvas_w, int canvas_h
) {
    for (int i = 0; i < tCount; i++) {
        if (!tri_valid[i]) continue;

        int i1 = v1[i], i2 = v2[i], i3 = v3[i];
        float x1 = px[i1], y1 = py[i1], z1 = pz[i1];
        float x2 = px[i2], y2 = py[i2], z2 = pz[i2];
        float x3 = px[i3], y3 = py[i3], z3 = pz[i3];

        // Broadcast color to 8-wide integer register
        __m256i v_color = _mm256_set1_epi32((int)shaded_color[i]);

        if (y1 > y2) { float t=x1; x1=x2; x2=t;  t=y1; y1=y2; y2=t;  t=z1; z1=z2; z2=t; }
        if (y1 > y3) { float t=x1; x1=x3; x3=t;  t=y1; y1=y3; y3=t;  t=z1; z1=z3; z3=t; }
        if (y2 > y3) { float t=x2; x2=x3; x3=t;  t=y2; y2=y3; y3=t;  t=z2; z2=z3; z3=t; }

        float total_height = y3 - y1;
        if (total_height <= 0.0f) continue;

        float inv_total = 1.0f / total_height;
        int y_start = (int)fmaxf(0.0f, ceilf(y1));
        int y_end   = (int)fminf((float)(canvas_h - 1), floorf(y3));

        // ==========================================
        // UPPER TRIANGLE
        // ==========================================
        float dy_upper = y2 - y1;
        if (dy_upper > 0.0f) {
            float inv_upper = 1.0f / dy_upper;
            int limit_y = (int)fminf((float)y_end, floorf(y2));

            for (int y = y_start; y <= limit_y; y++) {
                float t_total = (y - y1) * inv_total;
                float t_half  = (y - y1) * inv_upper;
                float ax = x1 + (x3 - x1) * t_total, az = z1 + (z3 - z1) * t_total;
                float bx = x1 + (x2 - x1) * t_half,  bz = z1 + (z2 - z1) * t_half;

                if (ax > bx) { float t=ax; ax=bx; bx=t;  t=az; az=bz; bz=t; }

                float row_width = bx - ax;
                if (row_width > 0.0f) {
                    float z_step = (bz - az) / row_width;
                    int start_x = (int)fmaxf(0.0f, ceilf(ax));
                    int end_x   = (int)fminf((float)(canvas_w - 1), floorf(bx));
                    float current_z = az + z_step * (start_x - ax);

                    int off = y * canvas_w;
                    int x = start_x;

                    // --- THE AVX2 HORIZONTAL LOOP ---
                    __m256 v_z_step8 = _mm256_set1_ps(z_step * 8.0f);
                    __m256 v_current_z = _mm256_set_ps(
                        current_z + z_step*7.0f, current_z + z_step*6.0f,
                        current_z + z_step*5.0f, current_z + z_step*4.0f,
                        current_z + z_step*3.0f, current_z + z_step*2.0f,
                        current_z + z_step*1.0f, current_z
                    );

                    for (; x <= end_x - 7; x += 8) {
                        __m256 v_old_z = _mm256_loadu_ps(&z_buffer[off + x]);
                        __m256 v_cmp = _mm256_cmp_ps(v_current_z, v_old_z, _CMP_LT_OQ);
                        __m256i v_mask = _mm256_castps_si256(v_cmp);

                        _mm256_maskstore_ps(&z_buffer[off + x], v_mask, v_current_z);
                        _mm256_maskstore_epi32((int*)&screen_buffer[off + x], v_mask, v_color);

                        v_current_z = _mm256_add_ps(v_current_z, v_z_step8);
                    }

                    // --- SCALAR TAIL LOOP ---
                    current_z = az + z_step * (x - ax); // Recalculate scalar Z exactly
                    for (; x <= end_x; x++) {
                        if (current_z < z_buffer[off + x]) {
                            z_buffer[off + x] = current_z;
                            screen_buffer[off + x] = (uint32_t)shaded_color[i];
                        }
                        current_z += z_step;
                    }
                }
            }
        }

        // ==========================================
        // LOWER TRIANGLE
        // ==========================================
        float dy_lower = y3 - y2;
        if (dy_lower > 0.0f) {
            float inv_lower = 1.0f / dy_lower;
            int start_y = (int)fmaxf((float)y_start, ceilf(y2));

            for (int y = start_y; y <= y_end; y++) {
                float t_total = (y - y1) * inv_total;
                float t_half  = (y - y2) * inv_lower;
                float ax = x1 + (x3 - x1) * t_total, az = z1 + (z3 - z1) * t_total;
                float bx = x2 + (x3 - x2) * t_half,  bz = z2 + (z3 - z2) * t_half;

                if (ax > bx) { float t=ax; ax=bx; bx=t;  t=az; az=bz; bz=t; }

                float row_width = bx - ax;
                if (row_width > 0.0f) {
                    float z_step = (bz - az) / row_width;
                    int start_x = (int)fmaxf(0.0f, ceilf(ax));
                    int end_x   = (int)fminf((float)(canvas_w - 1), floorf(bx));
                    float current_z = az + z_step * (start_x - ax);

                    int off = y * canvas_w;
                    int x = start_x;

                    // --- THE AVX2 HORIZONTAL LOOP ---
                    __m256 v_z_step8 = _mm256_set1_ps(z_step * 8.0f);
                    __m256 v_current_z = _mm256_set_ps(
                        current_z + z_step*7.0f, current_z + z_step*6.0f,
                        current_z + z_step*5.0f, current_z + z_step*4.0f,
                        current_z + z_step*3.0f, current_z + z_step*2.0f,
                        current_z + z_step*1.0f, current_z
                    );

                    for (; x <= end_x - 7; x += 8) {
                        __m256 v_old_z = _mm256_loadu_ps(&z_buffer[off + x]);
                        __m256 v_cmp = _mm256_cmp_ps(v_current_z, v_old_z, _CMP_LT_OQ);
                        __m256i v_mask = _mm256_castps_si256(v_cmp);

                        _mm256_maskstore_ps(&z_buffer[off + x], v_mask, v_current_z);
                        _mm256_maskstore_epi32((int*)&screen_buffer[off + x], v_mask, v_color);

                        v_current_z = _mm256_add_ps(v_current_z, v_z_step8);
                    }

                    // --- SCALAR TAIL LOOP ---
                    current_z = az + z_step * (x - ax);
                    for (; x <= end_x; x++) {
                        if (current_z < z_buffer[off + x]) {
                            z_buffer[off + x] = current_z;
                            screen_buffer[off + x] = (uint32_t)shaded_color[i];
                        }
                        current_z += z_step;
                    }
                }
            }
        }
    }
}
// ========================================================================
// THE MEGA-SWARM PHYSICS & INSTANCING KERNELS
// ========================================================================

EXPORT void simd_update_physics_swarm(
    int count,
    float* px, float* py, float* pz,
    float* vx, float* vy, float* vz,
    float minX, float maxX,
    float minY, float maxY,
    float minZ, float maxZ,
    float dt, float gravity
) {
    for (int i = 0; i < count; i++) {
        // Apply Gravity & Slight Drag (Terminal Velocity protection)
        vy[i] -= gravity * dt;
        vx[i] *= 0.995f; 
        vy[i] *= 0.995f; 
        vz[i] *= 0.995f;

        // Integrate Position
        px[i] += vx[i] * dt;
        py[i] += vy[i] * dt;
        pz[i] += vz[i] * dt;

        // Universe Cage Bounce Logic (80% Restitution)
        if (px[i] < minX) { px[i] = minX; vx[i] = fabsf(vx[i]) * 0.8f; }
        if (px[i] > maxX) { px[i] = maxX; vx[i] = -fabsf(vx[i]) * 0.8f; }
        
        if (py[i] < minY) { py[i] = minY; vy[i] = fabsf(vy[i]) * 0.8f; }
        if (py[i] > maxY) { py[i] = maxY; vy[i] = -fabsf(vy[i]) * 0.8f; }
        
        if (pz[i] < minZ) { pz[i] = minZ; vz[i] = fabsf(vz[i]) * 0.8f; }
        if (pz[i] > maxZ) { pz[i] = maxZ; vz[i] = -fabsf(vz[i]) * 0.8f; }
    }
}

// User Interactivity: Click to shoot an explosion blast
EXPORT void simd_apply_explosion(
    int count,
    float* px, float* py, float* pz,
    float* vx, float* vy, float* vz,
    float ex, float ey, float ez,
    float force, float radius
) {
    float r2 = radius * radius;
    for (int i = 0; i < count; i++) {
        float dx = px[i] - ex;
        float dy = py[i] - ey;
        float dz = pz[i] - ez;
        float dist2 = dx*dx + dy*dy + dz*dz;
        
        if (dist2 < r2 && dist2 > 1.0f) {
            float dist = sqrtf(dist2);
            float f = force * (1.0f - (dist / radius)); // Linear falloff
            vx[i] += (dx / dist) * f;
            vy[i] += (dy / dist) * f;
            vz[i] += (dz / dist) * f;
        }
    }
}

// Procedurally blasts 40,000 vertices directly into the local geometry buffer
EXPORT void generate_swarm_geometry(
    int count,
    float* px, float* py, float* pz,
    float* lx, float* ly, float* lz,
    float size
) {
    int v_idx = 0;
    for(int i = 0; i < count; i++) {
        float cx = px[i], cy = py[i], cz = pz[i];
        
        // V0: Top Point
        lx[v_idx] = cx; ly[v_idx] = cy + size; lz[v_idx] = cz; v_idx++;
        // V1: Bottom Left Front
        lx[v_idx] = cx - size; ly[v_idx] = cy - size; lz[v_idx] = cz + size; v_idx++;
        // V2: Bottom Right Front
        lx[v_idx] = cx + size; ly[v_idx] = cy - size; lz[v_idx] = cz + size; v_idx++;
        // V3: Bottom Back
        lx[v_idx] = cx; ly[v_idx] = cy - size; lz[v_idx] = cz - size; v_idx++;
    }
}
EXPORT void simd_update_swarm_attractors(
    int count,
    float* px, float* py, float* pz,
    float* vx, float* vy, float* vz,
    float* seed, // A precalculated 0.0 to 1.0 float for each particle
    float cx, float cy, float cz, // Center of the room
    float time, float dt,
    int shape_mode 
) {
    for (int i = 0; i < count; i++) {
        float s = seed[i];
        float tx = cx, ty = cy, tz = cz;
        
        if (shape_mode == 1) { 
            // 1. THE BUNDLE (Fibonacci Sphere - Perfect mathematical distribution)
            float phi = (float)i * 2.39996323f; // Golden Angle
            float theta = acosf(1.0f - 2.0f * s);
            float r = 2000.0f + 400.0f * sinf(time * 6.0f); // Breathing core
            tx = cx + r * sinf(theta) * cosf(phi);
            ty = cy + r * cosf(theta);
            tz = cz + r * sinf(theta) * sinf(phi);
            
        } else if (shape_mode == 2) { 
            // 2. THE GALAXY (A massive spinning wavy disc)
            float angle = s * 3.14159f * 30.0f + time * 1.5f; 
            float r = 1000.0f + s * 14000.0f; // Spiral outwards
            tx = cx + r * cosf(angle);
            ty = cy + 800.0f * sinf(s * 40.0f - time * 3.0f); // Wavy Z-axis flutter
            tz = cz + r * sinf(angle);
            
        } else if (shape_mode == 3) { 
            // 3. THE TORNADO (Double Helix ascending)
            float height = s * 24000.0f - 12000.0f; // Bottom to top
            float angle = s * 3.14159f * 30.0f - time * 4.0f;
            float r = 2000.0f + (s * 4000.0f); // Gets wider at the top
            tx = cx + r * cosf(angle);
            ty = cy + height;
            tz = cz + r * sinf(angle);
            
        } else if (shape_mode == 4) { 
            // 4. THE GYROSCOPE (3 Interlocking Rotating Rings)
            int ring = i % 3; // Divide particles into 3 groups
            float angle = s * 3.14159f * 2.0f + time * 2.5f;
            float r = 7000.0f;
            if (ring == 0) { tx = cx + r*cosf(angle); ty = cy + r*sinf(angle); tz = cz; }
            else if (ring == 1) { tx = cx + r*cosf(angle); ty = cy; tz = cz + r*sinf(angle); }
            else { tx = cx; ty = cy + r*cosf(angle); tz = cz + r*sinf(angle); }
        }

        // SPRING PHYSICS (Steering towards target)
        float dx = tx - px[i];
        float dy = ty - py[i];
        float dz = tz - pz[i];
        
        float k = 4.0f; // Spring stiffness (Higher = snaps faster)
        vx[i] += dx * k * dt;
        vy[i] += dy * k * dt;
        vz[i] += dz * k * dt;
        
        // DAMPING (Friction so they settle into the shape instead of orbiting forever)
        vx[i] *= 0.92f;
        vy[i] *= 0.92f;
        vz[i] *= 0.92f;

        // INTEGRATE
        px[i] += vx[i] * dt;
        py[i] += vy[i] * dt;
        pz[i] += vz[i] * dt;
    }
}
