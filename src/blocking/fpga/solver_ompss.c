//
// This file is part of NBody and is licensed under the terms contained
// in the LICENSE file.
//
// Copyright (C) 2021 Barcelona Supercomputing Center (BSC)
//

#include "blocking/fpga/nbody.h"
#include "blocking/fpga/nbody.fpga.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <nanos6/debug.h>

//static void calculate_forces(float *forces, const float *particles, const int num_blocks);
//static void update_particles(float *particles, float *forces, const int num_blocks, const float time_interval);
//static void calculate_forces_block(float *x, float *y, float *z,
//	const float *pos_x1, const float *pos_y1, const float *pos_z1, const float *mass1,
//	const float *pos_x2, const float *pos_y2, const float *pos_z2, const float *weight2);
//static void update_particles_block(float *particles, float *forces, const float time_interval);

static const unsigned int NCALCFORCES = NBODY_NCALCFORCES;
static const unsigned int FPGA_PWIDTH = FPGA_MEMORY_PORT_WIDTH;

static const unsigned int PARTICLES_FPGABLOCK_POS_X_OFFSET  = 0*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_POS_Y_OFFSET  = 1*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_POS_Z_OFFSET  = 2*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_VEL_X_OFFSET  = 3*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_VEL_Y_OFFSET  = 4*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_VEL_Z_OFFSET  = 5*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_MASS_OFFSET   = 6*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_WEIGHT_OFFSET = 7*BLOCK_SIZE;
static const unsigned int PARTICLES_FPGABLOCK_SIZE          = 8*BLOCK_SIZE;

static const unsigned int FORCE_FPGABLOCK_X_OFFSET = 0*BLOCK_SIZE;
static const unsigned int FORCE_FPGABLOCK_Y_OFFSET = 1*BLOCK_SIZE;
static const unsigned int FORCE_FPGABLOCK_Z_OFFSET = 2*BLOCK_SIZE;
static const unsigned int FORCE_FPGABLOCK_SIZE     = 3*BLOCK_SIZE;

#pragma oss task label("calculate_forces_block") \
	device(fpga) num_instances(FBLOCK_NUM_ACCS) \
	inout([BLOCK_SIZE_C]x, [BLOCK_SIZE_C]y, [BLOCK_SIZE_C]z) \
	in([BLOCK_SIZE_C]pos_x1, [BLOCK_SIZE_C]pos_y1, [BLOCK_SIZE_C]pos_z1, [BLOCK_SIZE_C]mass1) \
	in([BLOCK_SIZE_C]pos_x2, [BLOCK_SIZE_C]pos_y2, [BLOCK_SIZE_C]pos_z2, [BLOCK_SIZE_C]weight2)
void calculate_forces_block(float *x, float *y, float *z,
	const float *pos_x1, const float *pos_y1, const float *pos_z1, const float *mass1,
	const float *pos_x2, const float *pos_y2, const float *pos_z2, const float *weight2)
{
	#pragma HLS inline
	//NOTE: Partition in a way that we can read/write enough data each cycle
	#pragma HLS array_partition variable=x cyclic factor=NCALCFORCES
	#pragma HLS array_partition variable=y cyclic factor=NCALCFORCES
	#pragma HLS array_partition variable=z cyclic factor=NCALCFORCES
	#pragma HLS array_partition variable=pos_x1 cyclic factor=NCALCFORCES/2
	#pragma HLS array_partition variable=pos_y1 cyclic factor=NCALCFORCES/2
	#pragma HLS array_partition variable=pos_z1 cyclic factor=NCALCFORCES/2
	#pragma HLS array_partition variable=mass1  cyclic factor=NCALCFORCES/2
	#pragma HLS array_partition variable=pos_x2 cyclic factor=FPGA_PWIDTH/64
	#pragma HLS array_partition variable=pos_y2 cyclic factor=FPGA_PWIDTH/64
	#pragma HLS array_partition variable=pos_z2 cyclic factor=FPGA_PWIDTH/64
	#pragma HLS array_partition variable=weight2  cyclic factor=FPGA_PWIDTH/64

	for (int i = 0; i < BLOCK_SIZE; i++) {
		for (int j = 0; j < BLOCK_SIZE; j++) {
		#pragma HLS pipeline II=1
		#pragma HLS unroll factor=NCALCFORCES

			const float diff_x = pos_x2[i] - pos_x1[j];
			const float diff_y = pos_y2[i] - pos_y1[j];
			const float diff_z = pos_z2[i] - pos_z1[j];

			const float distance_squared = diff_x * diff_x + diff_y * diff_y + diff_z * diff_z;
			const float distance = sqrtf(distance_squared);

			const float force_ = (mass1[j] / (distance_squared * distance)) * weight2[i];
			const float force = distance_squared == 0.f ? 0.f : force_;

			x[j] += force * diff_x;
			y[j] += force * diff_y;
			z[j] += force * diff_z;
		}
	}
}

void calculate_forces_N2(float *forces, const float *particles, const int num_blocks)
{
#pragma HLS inline
	for (int i = 0; i < num_blocks; i++) {
		for (int j = 0; j < num_blocks; j++) {
			float * forcesTarget = forces + j*FORCE_FPGABLOCK_SIZE;
			const float * block1 = particles + j*PARTICLES_FPGABLOCK_SIZE;
			const float * block2 = particles + i*PARTICLES_FPGABLOCK_SIZE;

			calculate_forces_block(
				forcesTarget + FORCE_FPGABLOCK_X_OFFSET, forcesTarget + FORCE_FPGABLOCK_Y_OFFSET,
				forcesTarget + FORCE_FPGABLOCK_Z_OFFSET, block1 + PARTICLES_FPGABLOCK_POS_X_OFFSET,
				block1 + PARTICLES_FPGABLOCK_POS_Y_OFFSET, block1 + PARTICLES_FPGABLOCK_POS_Z_OFFSET,
				block1 + PARTICLES_FPGABLOCK_MASS_OFFSET, block2 + PARTICLES_FPGABLOCK_POS_X_OFFSET,
				block2 + PARTICLES_FPGABLOCK_POS_Y_OFFSET, block2 + PARTICLES_FPGABLOCK_POS_Z_OFFSET,
				block2 + PARTICLES_FPGABLOCK_WEIGHT_OFFSET);
		}
	}
}


#pragma oss task device(fpga) copy_deps inout([PARTICLES_FPGABLOCK_SIZE]particles, [FORCE_FPGABLOCK_SIZE]forces) label("update_particles_block")
void update_particles_block(float *particles, float *forces, const float time_interval)
{
#pragma HLS inline
	for (int e = 0; e < BLOCK_SIZE; e++){
		//There are 7 loads to the particles array which can't be done in the same cycle
		#pragma HLS pipeline II=7
		#pragma HLS dependence variable=particles inter false
		#pragma HLS dependence variable=forces inter false

		const float mass       = particles[PARTICLES_FPGABLOCK_MASS_OFFSET + e];
		const float velocity_x = particles[PARTICLES_FPGABLOCK_VEL_X_OFFSET + e];
		const float velocity_y = particles[PARTICLES_FPGABLOCK_VEL_Y_OFFSET + e];
		const float velocity_z = particles[PARTICLES_FPGABLOCK_VEL_Z_OFFSET + e];

		const float position_x = particles[PARTICLES_FPGABLOCK_POS_X_OFFSET + e];
		const float position_y = particles[PARTICLES_FPGABLOCK_POS_Y_OFFSET + e];
		const float position_z = particles[PARTICLES_FPGABLOCK_POS_Z_OFFSET + e];

		const float time_by_mass       = time_interval / mass;
		const float half_time_interval = 0.5f * time_interval;

		const float velocity_change_x = forces[FORCE_FPGABLOCK_X_OFFSET + e] * time_by_mass;
		const float velocity_change_y = forces[FORCE_FPGABLOCK_Y_OFFSET + e] * time_by_mass;
		const float velocity_change_z = forces[FORCE_FPGABLOCK_Z_OFFSET + e] * time_by_mass;

		const float position_change_x = velocity_x + velocity_change_x * half_time_interval;
		const float position_change_y = velocity_y + velocity_change_y * half_time_interval;
		const float position_change_z = velocity_z + velocity_change_z * half_time_interval;

		particles[PARTICLES_FPGABLOCK_VEL_X_OFFSET + e] = velocity_x + velocity_change_x;
		particles[PARTICLES_FPGABLOCK_VEL_Y_OFFSET + e] = velocity_y + velocity_change_y;
		particles[PARTICLES_FPGABLOCK_VEL_Z_OFFSET + e] = velocity_z + velocity_change_z;

		particles[PARTICLES_FPGABLOCK_POS_X_OFFSET + e] = position_x + position_change_x;
		particles[PARTICLES_FPGABLOCK_POS_Y_OFFSET + e] = position_y + position_change_y;
		particles[PARTICLES_FPGABLOCK_POS_Z_OFFSET + e] = position_z + position_change_z;

		forces[FORCE_FPGABLOCK_X_OFFSET + e] = 0.0f;
		forces[FORCE_FPGABLOCK_Y_OFFSET + e] = 0.0f;
		forces[FORCE_FPGABLOCK_Z_OFFSET + e] = 0.0f;
	}
}

void update_particles(float *particles, float *forces, const int num_blocks, const float time_interval)
{
#pragma HLS inline
	for (int i = 0; i < num_blocks; i++) {
		update_particles_block(particles+i*PARTICLES_FPGABLOCK_SIZE, forces+i*FORCE_FPGABLOCK_SIZE, time_interval);
	}
}

void nbody_stats(const nbody_t *nbody, const nbody_conf_t *conf, double time)
{
	int particles = nbody->num_blocks * BLOCK_SIZE;
	if (conf->parse) {
		printf("%e\n", time);
	}
	else {
		printf("time %f\n", time);
		printf("bigo, %s, threads, %d, timesteps, %d, total_particles, %d, block_size, %d, blocks, %d, performance, %f\n",
				TOSTRING(BIGO), nanos6_get_num_cpus(), nbody->timesteps, particles, BLOCK_SIZE,
				nbody->num_blocks, nbody_compute_throughput(particles, nbody->timesteps, time)
		);
	}
	if (conf->stats_file) {
		//Create the JSON result file
        (void)fclose;
		FILE *res_file = fopen("test_result.json", "w+");
		if (res_file == NULL) {
			printf( "Cannot open 'test_result.json' file\n" );
			exit(1);
		}
		fprintf(res_file,
			"{" \
			"\"benchmark\": \"%s\"," \
			"\"toolchain\": \"%s\"," \
			"\"hwruntime\": \"%s\"," \
			"\"board\": \"%s\"," \
			"\"version\": \"%uaccs %uBS %umhz memport_%u\"," \
			"\"exectype\": \"%s\"," \
			"\"argv\": \"%d %d %d\"," \
			"\"exectime\": \"%f\"," \
			"\"performance\": \"%f\"," \
			"\"note\": \"datatype %s\"" \
			"}",
			"nbody",
			"ompss-2",
			FPGA_HWRUNTIME,
			BOARD,
			NBODY_NUM_FBLOCK_ACCS, BLOCK_SIZE, FPGA_CLOCK, FPGA_MEMORY_PORT_WIDTH,
			getenv("RUNTIME_MODE"),
			particles, BLOCK_SIZE, nbody->timesteps,
			time,
			nbody_compute_throughput(particles, nbody->timesteps, time),
			"float"
		);
		fclose(res_file);
	}
}

void nbody_solve(float *particles, float *forces, const int num_blocks, const int timesteps, const float time_interval)
{
	for (int t = 0; t < timesteps; t++) {
		calculate_forces(forces, particles, num_blocks);
		update_particles(particles, forces, num_blocks, time_interval);
	}

	#pragma oss taskwait
}

void nbody_solve_fpga(float *particles, float *forces, const int num_blocks, const int timesteps, const float time_interval) {
	nbody_solve(particles, forces, num_blocks, timesteps, time_interval);
}

