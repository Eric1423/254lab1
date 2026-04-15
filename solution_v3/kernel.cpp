#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
    auto A = reinterpret_cast<TYPE*>(arg->A_addr);
    auto B = reinterpret_cast<TYPE*>(arg->B_addr);
    auto C = reinterpret_cast<TYPE*>(arg->C_addr);
    auto N = arg->size;

    int bx = blockIdx.x;
    int by = blockIdx.y;

    int row_start = by * TILE_Y;
    int col_start = bx * TILE_X;

    // Register file: each thread computes TILE_Y x TILE_X outputs
    TYPE sum[TILE_Y][TILE_X];
    for (int i = 0; i < TILE_Y; ++i)
        for (int j = 0; j < TILE_X; ++j)
            sum[i][j] = TYPE(0);

    // Loop over K dimension
    for (int e = 0; e < N; ++e) {
        // Load A values once per row, reuse across TILE_X columns
        for (int i = 0; i < TILE_Y; ++i) {
            TYPE a_val = A[(row_start + i) * N + e];
            for (int j = 0; j < TILE_X; ++j) {
                sum[i][j] += a_val * B[e * N + (col_start + j)];
            }
        }
    }

    // Store results
    for (int i = 0; i < TILE_Y; ++i)
        for (int j = 0; j < TILE_X; ++j)
            C[(row_start + i) * N + (col_start + j)] = sum[i][j];
}

int main() {
    kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
    return vx_spawn_threads(2, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}
