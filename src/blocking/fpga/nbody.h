//
// This file is part of NBody and is licensed under the terms contained
// in the LICENSE file.
//
// Copyright (C) 2021 Barcelona Supercomputing Center (BSC)
//

#ifndef NBODY_SMP_H
#define NBODY_SMP_H

#include "blocking/common/nbody.h"

// Application structures
struct nbody_file_t {
	size_t size;
	char name[1000];
};

struct nbody_t {
	particles_block_t *particles;
	forces_block_t *forces;
	int num_blocks;
	int timesteps;
	nbody_file_t file;
};

#endif // NBODY_SMP_H

