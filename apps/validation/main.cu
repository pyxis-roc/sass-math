#include <cuda_runtime.h>
#include <cstdio>
#include <cinttypes>
#include <cstring>
#include <limits>

using float_limits = std::numeric_limits<float>;

// sanity checks
static_assert(float_limits::is_iec559, "float not IEEE 754");
static_assert(!float_limits::traps, "floating-point exceptions enabled");

#include "model/model.h"
#include "util/cuda.hpp"
#include "util/devices.hpp"
#include "util/progress.hpp"
#include "util/pun.hpp"
#include "ptx/ptx.hpp"

static constexpr uint32_t BATCH_SIZE = UINT32_C(1) << 20;
static constexpr uint32_t BATCH_COUNT = (UINT64_C(1) << 32) / BATCH_SIZE;

static constexpr int BLOCK_DIM = 1 << 8;
static constexpr int GRID_DIM = BATCH_SIZE / BLOCK_DIM;

template<ptx_instruction I>
__global__
static void map(int n, float *x)
{
    GRID_STRIDE_LOOP(i, n)
    {
        ptx_asm<I>::exec(x + i);
    }
}

static void initialize_batch(uint32_t batch, float *x)
{
    const uint32_t base_val = batch * BATCH_SIZE;

    for (uint32_t i = 0; i < BATCH_SIZE; i++)
    {
        x[i] = pun<float>(base_val + i);
    }
}

static uint32_t compare_batch(uint32_t batch, const float *x, float (*f)(float))
{
    const uint32_t base_val = batch * BATCH_SIZE;
    uint32_t num_exact = 0;

    for (uint32_t i = 0; i < BATCH_SIZE; i++)
    {
        const float val = pun<float>(base_val + i);
        const float cmp = f(val);

        if (memcmp(x + i, &cmp, sizeof(float)) == 0)
            num_exact++;
    }

    return num_exact;
}

int main()
{
    puts("Detecting devices...");
    print_devices();

    int device;
    CUDA_CHECK(cudaGetDevice(&device));

    printf("Using device %d.\nRunning simulation...\n", device);

    float *x;
    CUDA_CHECK(cudaMallocManaged(&x, BATCH_SIZE * sizeof(float)));

    uint64_t num_exact = 0;

    for (uint32_t batch = 0; batch < BATCH_COUNT; batch++)
    {
        print_progress_bar((float)batch / BATCH_COUNT);
        initialize_batch(batch, x);

        map<ptx_instruction::RCP_APPROX_F32><<<GRID_DIM, BLOCK_DIM>>>(BATCH_SIZE, x);
        CUDA_CHECK(cudaPeekAtLastError());

        CUDA_CHECK(cudaDeviceSynchronize());

        num_exact += compare_batch(batch, x, model_rcp);
    }

    print_progress_bar(1.0f);
    putchar('\n');

    printf("Bit-exact: %" PRIu64 "\n", num_exact);

    CUDA_CHECK(cudaFree(x));

    return 0;
}