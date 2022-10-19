//
// This file is part of NBody and is licensed under the terms contained
// in the LICENSE file.
//
// Copyright (C) 2021 Barcelona Supercomputing Center (BSC)
//

#include "blocking/fpga/nbody.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char** argv)
{
	int ok;
	nbody_conf_t conf = nbody_get_conf(&ok, argc, argv);
	if (!ok) {
		return 1;
	}

	if (conf.num_particles%BLOCK_SIZE != 0) {
		fprintf(stderr, "Number of particles not multiple of block size and number of devices\n");
		return 1;
	}
	
	conf.num_particles = ROUNDUP(conf.num_particles, MIN_PARTICLES);
	assert(conf.num_particles >= BLOCK_SIZE);
	assert(conf.timesteps > 0);
	
	conf.num_blocks = conf.num_particles / BLOCK_SIZE;
	assert(conf.num_blocks > 0);
	
	nbody_t nbody = nbody_setup(&conf);
	
	particles_block_t *particles = nbody.particles;
	forces_block_t *forces = nbody.forces;

	double start = get_time();
	nbody_solve((float*)particles, (float*)forces, conf.num_blocks, conf.timesteps, conf.time_interval);
	#pragma oss taskwait
	double end = get_time();
	
	nbody_stats(&nbody, &conf, end - start);
	
	if (conf.save_result && !conf.force_generation) nbody_save_particles(&nbody);
	if (conf.check_result) nbody_check(&nbody);
	nbody_free(&nbody);
	return 0;
}
