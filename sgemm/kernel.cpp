#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
    auto A = reinterpret_cast<TYPE*>(arg->A_addr);
    auto B = reinterpret_cast<TYPE*>(arg->B_addr);
    auto C = reinterpret_cast<TYPE*>(arg->C_addr);
    auto N = arg->size;

    // Thread position within the block
    int tx = threadIdx.x;
    int ty = threadIdx.y;

    // Global position
    int col = blockIdx.x * TILE_SIZE + tx;
    int row = blockIdx.y * TILE_SIZE + ty;

    // Shared memory tiles
    __local_mem TYPE tileA[TILE_SIZE][TILE_SIZE];
    __local_mem TYPE tileB[TILE_SIZE][TILE_SIZE];

    TYPE sum = 0;

    // Loop over tiles
    for (int t = 0; t < N; t += TILE_SIZE) {
        // Load tile from A and B into shared memory
        tileA[ty][tx] = A[row * N + (t + tx)];
        tileB[ty][tx] = B[(t + ty) * N + col];

        __syncthreads();

        // Compute partial dot product from this tile
        for (int e = 0; e < TILE_SIZE; ++e) {
            sum += tileA[ty][e] * tileB[e][tx];
        }

        __syncthreads();
    }

    C[row * N + col] = sum;
}

int main() {
    kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
    return vx_spawn_threads(2, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}