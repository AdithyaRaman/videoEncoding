#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>

#define RAPL_PATH_0   "/sys/class/powercap/intel-rapl:0/energy_uj"
#define RAPL_PATH_1   "/sys/class/powercap/intel-rapl:1/energy_uj"
#define RAPL_PATH_0_0 "/sys/class/powercap/intel-rapl:0:0/energy_uj"
#define RAPL_PATH_1_0 "/sys/class/powercap/intel-rapl:1:0/energy_uj"
#define THERM_PATH_0  "/sys/class/thermal/thermal_zone0/temp"
#define THERM_PATH_1  "/sys/class/thermal/thermal_zone1/temp"
#define THERM_PATH_2  "/sys/class/thermal/thermal_zone2/temp"
#define OUTPUT_CSV    "energy_delta.csv"

/* Intel RAPL counters wrap at max_energy_range_uj. A safe upper bound
   for current CPUs is 2^32 µJ; read the real value if you need precision. */
#define WRAPAROUND_UJ 262143328850ULL  /* 2^32 µJ */

static volatile int running = 1;

void handle_sigint(int sig) {
    (void)sig;
    running = 0;
}

/* Read a single unsigned long long from a sysfs file.
   Returns 0 on success, -1 on failure. */
int read_ull(const char *path, unsigned long long *out) {
    FILE *f = fopen(path, "r");
    if (!f) {
        perror(path);
        return -1;
    }
    int rc = fscanf(f, "%llu", out);
    fclose(f);
    return (rc == 1) ? 0 : -1;
}

/* Read a thermal zone temp (millidegrees Celsius) as a signed long.
   Returns 0 on success, -1 on failure. */
int read_temp_mc(const char *path, long *out) {
    FILE *f = fopen(path, "r");
    if (!f) {
        perror(path);
        return -1;
    }
    int rc = fscanf(f, "%ld", out);
    fclose(f);
    return (rc == 1) ? 0 : -1;
}

/* Compute delta, handling wraparound. */
unsigned long long delta(unsigned long long prev, unsigned long long curr) {
    if (curr >= prev)
        return curr - prev;
    return (WRAPAROUND_UJ - prev) + curr;   /* counter wrapped */
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <output.csv>\n", argv[0]);
        return EXIT_FAILURE;
    }
    const char *output_path = argv[1];

    signal(SIGINT,  handle_sigint);
    signal(SIGTERM, handle_sigint);

    /* Open CSV and write header */
    FILE *csv = fopen(output_path, "w");
    if (!csv) {
        perror("fopen output csv");
        return EXIT_FAILURE;
    }
    fprintf(csv, "timestamp,rapl0_delta_uj,rapl1_delta_uj,rapl0_0_delta_uj,rapl1_0_delta_uj,"
                 "therm_zone0_mc,therm_zone1_mc,therm_zone2_mc\n");
    fflush(csv);

    unsigned long long prev0 = 0, prev1 = 0, prev0_0 = 0, prev1_0 = 0;
    unsigned long long curr0 = 0, curr1 = 0, curr0_0 = 0, curr1_0 = 0;
    long temp0 = 0, temp1 = 0, temp2 = 0;
    int first = 1;

    printf("Logging energy deltas to %s  (Ctrl-C to stop)\n", output_path);

    while (running) {
        /* Record the wall-clock time before the reads */
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);

        if (read_ull(RAPL_PATH_0,   &curr0)   != 0 ||
            read_ull(RAPL_PATH_1,   &curr1)   != 0 ||
            read_ull(RAPL_PATH_0_0, &curr0_0) != 0 ||
            read_ull(RAPL_PATH_1_0, &curr1_0) != 0 ||
            read_temp_mc(THERM_PATH_0, &temp0) != 0 ||
            read_temp_mc(THERM_PATH_1, &temp1) != 0 ||
            read_temp_mc(THERM_PATH_2, &temp2) != 0) {
            fprintf(stderr, "Failed to read sensor files – retrying in 1 s\n");
            sleep(1);
            continue;
        }

        if (!first) {
            unsigned long long d0   = delta(prev0,   curr0);
            unsigned long long d1   = delta(prev1,   curr1);
            unsigned long long d0_0 = delta(prev0_0, curr0_0);
            unsigned long long d1_0 = delta(prev1_0, curr1_0);

            /* ISO-8601 timestamp with millisecond resolution */
            char tsbuf[32];
            struct tm *tm_info = gmtime(&ts.tv_sec);
            strftime(tsbuf, sizeof(tsbuf), "%Y-%m-%dT%H:%M:%S", tm_info);
            snprintf(tsbuf + strlen(tsbuf), sizeof(tsbuf) - strlen(tsbuf),
                     ".%03ldZ", ts.tv_nsec / 1000000L);

            fprintf(csv, "%s,%llu,%llu,%llu,%llu,%ld,%ld,%ld\n",
                    tsbuf, d0, d1, d0_0, d1_0, temp0, temp1, temp2);
            fflush(csv);

            /* printf("[%s]  rapl:0 = %8llu µJ   rapl:1 = %8llu µJ" */
            /*        "   rapl:0:0 = %8llu µJ   rapl:1:0 = %8llu µJ" */
            /*        "   tz0 = %5.1f°C   tz1 = %5.1f°C   tz2 = %5.1f°C\n", */
            /*        tsbuf, d0, d1, d0_0, d1_0, */
            /*        temp0 / 1000.0, temp1 / 1000.0, temp2 / 1000.0); */
        }

        prev0   = curr0;
        prev1   = curr1;
        prev0_0 = curr0_0;
        prev1_0 = curr1_0;
        first  = 0;

        sleep(1);
    }

    fclose(csv);
    printf("\nStopped. Results saved to %s\n", output_path);
    return EXIT_SUCCESS;
}
