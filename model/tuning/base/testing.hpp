#ifndef TESTING_HPP
#define TESTING_HPP

#include "counters.hpp"
#include "interval.hpp"
#include "fntypes.hpp"

void test(const interval &sub, float *gpu_buf, float *model_buf, uint32_t buf_size,
          const mapf_t &gpu, const mapf_t &model, const syncf_t &sync, counters &results);

#endif