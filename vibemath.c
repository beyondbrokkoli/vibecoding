#include <immintrin.h> // The magic header for SIMD intrinsics
#include <stdint.h>
#include <stdbool.h>

// We export this so LuaJIT can see it
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT
#endif

EXPORT void simd_transform_vertices(
    int count,
    float* lx, float* ly, float* lz, // Input arrays
    float* wx, float* wy, float* wz, // Output arrays (you'll need to add these to memory.lua)
    float ox, float oy, float oz,    // Object Position
    float rx, float ry, float rz,    // Right Vector
    float ux, float uy, float uz,    // Up Vector
    float fx, float fy, float fz     // Forward Vector
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

        // Store the 8 results back into memory
        _mm256_storeu_ps(&wx[i], v_wx);
        _mm256_storeu_ps(&wy[i], v_wy);
        _mm256_storeu_ps(&wz[i], v_wz);
    }

    // 3. The Tail Loop (For leftover vertices if count is not a multiple of 8)
    for (; i < count; i++) {
        wx[i] = ox + lx[i]*rx + ly[i]*ux + lz[i]*fx;
        wy[i] = oy + lx[i]*ry + ly[i]*uy + lz[i]*fy;
        wz[i] = oz + lx[i]*rz + ly[i]*uz + lz[i]*fz;
    }
}
