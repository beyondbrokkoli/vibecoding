#include <stdint.h>
#include <stdbool.h>
#include <math.h>

// We export this so LuaJIT can see it
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ========================================================================
// 1. PROJECTION (Pure Scalar, Hoisted)
// ========================================================================
EXPORT void simd_project_vertices(
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
) {
    for (int i = 0; i < count; i++) {
        // Calculate World Coords
        float temp_wx = ox + lx[i]*rx + ly[i]*ux + lz[i]*fx;
        float temp_wy = oy + lx[i]*ry + ly[i]*uy + lz[i]*fy;
        float temp_wz = oz + lx[i]*rz + ly[i]*uz + lz[i]*fz;

        // View Deltas
        float vdx = temp_wx - cpx;
        float vdy = temp_wy - cpy;
        float vdz = temp_wz - cpz;

        // Depth
        float cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z;

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

// ========================================================================
// 2. BUFFER CLEARING
// ========================================================================
EXPORT void simd_clear_buffers(
    uint32_t* screen,
    float* zbuffer,
    uint32_t clear_color,
    float clear_z,
    int pixel_count
) {
    // A standard for-loop. Modern GCC will often auto-vectorize this into 
    // memset-like instructions depending on the target architecture.
    for (int i = 0; i < pixel_count; i++) {
        screen[i] = clear_color;
        zbuffer[i] = clear_z;
    }
}

// ========================================================================
// 3. VERTEX GENERATION (Scalar, but structurally optimized!)
// ========================================================================
EXPORT void generate_smales_paradox_vertices(
    float* lx, float* ly, float* lz,
    int latitudes, int longitudes,
    float eversion, float bulge, float base_radius
) {
    int idx = 0;
    float phi_step = ((float)M_PI * 2.0f) / longitudes;
    float r_main = base_radius * eversion;

    for (int i = 0; i <= latitudes; i++) {
        // ULTIMA_PLATIN optimization: Calculate row-constants ONLY ONCE per latitude
        float theta = ((float)i / latitudes) * (float)M_PI;
        float ny = cosf(theta);
        float sin_theta = sinf(theta);
        float twist = sinf(theta * 2.0f);
        float ly_offset = cosf(theta * 3.0f) * base_radius * bulge * 0.5f;

        for (int j = 0; j <= longitudes; j++) {
            float phi = j * phi_step;
            float nx = sin_theta * cosf(phi);
            float nz = sin_theta * sinf(phi);

            float waves = cosf(phi * 4.0f);
            float r_corrugate = base_radius * bulge * waves * twist * 1.2f;

            lx[idx] = nx * r_main + nx * r_corrugate;
            ly[idx] = ny * r_main + ly_offset;
            lz[idx] = nz * r_main + nz * r_corrugate;
            idx++;
        }
    }
}

// ========================================================================
// 4. TRIANGLE LIGHTING / CULLING (Identical to ULTIMA)
// ========================================================================
EXPORT void process_triangles_twotone(
    int tCount, int* v1, int* v2, int* v3, bool* vert_valid,
    float* px, float* py, float* pz, float* lx, float* ly, float* lz,
    uint32_t* baked_color, uint32_t* shaded_color, bool* tri_valid,
    float rx, float ry, float rz, float ux, float uy, float uz, float fx, float fy, float fz,
    float sun_x, float sun_y, float sun_z
) {
    for (int i = 0; i < tCount; i++) {
        int i1 = v1[i], i2 = v2[i], i3 = v3[i];

        if (!vert_valid[i1] || !vert_valid[i2] || !vert_valid[i3]) {
            tri_valid[i] = false;
            continue;
        }

        float px1 = px[i1], py1 = py[i1];
        float px2 = px[i2], py2 = py[i2];
        float px3 = px[i3], py3 = py[i3];

        float cross = (px2 - px1) * (py3 - py1) - (py2 - py1) * (px3 - px1);
        bool is_inside = cross >= 0;

        uint32_t orig_col = baked_color[i];
        if (is_inside) orig_col = 0xFFFF00AA; 

        float ax = lx[i2] - lx[i1], ay = ly[i2] - ly[i1], az = lz[i2] - lz[i1];
        float bx = lx[i3] - lx[i1], by = ly[i3] - ly[i1], bz = lz[i3] - lz[i1];

        float lnx = ay * bz - az * by;
        float lny = az * bx - ax * bz;
        float lnz = ax * by - ay * bx;

        float wnx = lnx * rx + lny * ux + lnz * fx;
        float wny = lnx * ry + lny * uy + lnz * fy;
        float wnz = lnx * rz + lny * uz + lnz * fz;

        float inv_len = 1.0f / sqrtf(wnx*wnx + wny*wny + wnz*wnz + 0.000001f);
        wnx *= inv_len; wny *= inv_len; wnz *= inv_len;

        float dot = wnx * sun_x + wny * sun_y + wnz * sun_z;
        if (is_inside) dot = -dot; 

        float light = dot < 0.2f ? 0.2f : (dot > 1.0f ? 1.0f : dot);

        uint32_t b = (uint32_t)(((orig_col >> 16) & 0xFF) * light);
        uint32_t g = (uint32_t)(((orig_col >> 8) & 0xFF) * light);
        uint32_t r = (uint32_t)((orig_col & 0xFF) * light);

        shaded_color[i] = 0xFF000000 | (b << 16) | (g << 8) | r;
        tri_valid[i] = true;
    }
}

EXPORT void process_triangles_cull(
    // ... Same signature as twotone ...
    int tCount, int* v1, int* v2, int* v3, bool* vert_valid,
    float* px, float* py, float* pz, float* lx, float* ly, float* lz,
    uint32_t* baked_color, uint32_t* shaded_color, bool* tri_valid,
    float rx, float ry, float rz, float ux, float uy, float uz, float fx, float fy, float fz,
    float sun_x, float sun_y, float sun_z
) {
    for (int i = 0; i < tCount; i++) {
        int i1 = v1[i], i2 = v2[i], i3 = v3[i];

        if (!vert_valid[i1] || !vert_valid[i2] || !vert_valid[i3]) {
            tri_valid[i] = false;
            continue;
        }

        float px1 = px[i1], py1 = py[i1], px2 = px[i2], py2 = py[i2], px3 = px[i3], py3 = py[i3];

        float cross = (px2 - px1) * (py3 - py1) - (py2 - py1) * (px3 - px1);
        if (cross >= 0) {
            tri_valid[i] = false; 
            continue;             
        }

        uint32_t orig_col = baked_color[i];

        float ax = lx[i2] - lx[i1], ay = ly[i2] - ly[i1], az = lz[i2] - lz[i1];
        float bx = lx[i3] - lx[i1], by = ly[i3] - ly[i1], bz = lz[i3] - lz[i1];
        float lnx = ay * bz - az * by, lny = az * bx - ax * bz, lnz = ax * by - ay * bx;

        float wnx = lnx * rx + lny * ux + lnz * fx;
        float wny = lnx * ry + lny * uy + lnz * fy;
        float wnz = lnx * rz + lny * uz + lnz * fz;

        float inv_len = 1.0f / sqrtf(wnx*wnx + wny*wny + wnz*wnz + 0.000001f);
        wnx *= inv_len; wny *= inv_len; wnz *= inv_len;

        float dot = wnx * sun_x + wny * sun_y + wnz * sun_z;
        float light = dot < 0.2f ? 0.2f : (dot > 1.0f ? 1.0f : dot);

        uint32_t b = (uint32_t)(((orig_col >> 16) & 0xFF) * light);
        uint32_t g = (uint32_t)(((orig_col >> 8) & 0xFF) * light);
        uint32_t r = (uint32_t)((orig_col & 0xFF) * light);

        shaded_color[i] = 0xFF000000 | (b << 16) | (g << 8) | r;
        tri_valid[i] = true; 
    }
}

// ========================================================================
// 5. RASTERIZATION (Pure Scalar Inner Loop)
// ========================================================================
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
        uint32_t color = shaded_color[i];

        if (y1 > y2) { float t=x1; x1=x2; x2=t;  t=y1; y1=y2; y2=t;  t=z1; z1=z2; z2=t; }
        if (y1 > y3) { float t=x1; x1=x3; x3=t;  t=y1; y1=y3; y3=t;  t=z1; z1=z3; z3=t; }
        if (y2 > y3) { float t=x2; x2=x3; x3=t;  t=y2; y2=y3; y3=t;  t=z2; z2=z3; z3=t; }

        float total_height = y3 - y1;
        if (total_height <= 0.0f) continue;

        float inv_total = 1.0f / total_height;
        int y_start = (int)fmaxf(0.0f, ceilf(y1));
        int y_end   = (int)fminf((float)(canvas_h - 1), floorf(y3));

        // UPPER TRIANGLE
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
                    for (int x = start_x; x <= end_x; x++) {
                        if (current_z < z_buffer[off + x]) {
                            z_buffer[off + x] = current_z;
                            screen_buffer[off + x] = color;
                        }
                        current_z += z_step;
                    }
                }
            }
        }

        // LOWER TRIANGLE
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
                    for (int x = start_x; x <= end_x; x++) {
                        if (current_z < z_buffer[off + x]) {
                            z_buffer[off + x] = current_z;
                            screen_buffer[off + x] = color;
                        }
                        current_z += z_step;
                    }
                }
            }
        }
    }
}
