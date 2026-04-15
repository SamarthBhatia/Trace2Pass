/* Trace2Pass benchmark harness: cJSON
 * Workload: 50K create+serialize+parse cycles.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "cJSON.h"

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    long total = 0;
    for (int i = 0; i < 10000; i++) {
        cJSON *obj = cJSON_CreateObject();
        cJSON_AddNumberToObject(obj, "id", i);
        cJSON_AddStringToObject(obj, "name", "benchmark");
        cJSON *arr = cJSON_AddArrayToObject(obj, "values");
        for (int j = 0; j < 8; j++) cJSON_AddItemToArray(arr, cJSON_CreateNumber(i + j));
        cJSON_AddBoolToObject(obj, "active", i & 1);

        char *s = cJSON_PrintUnformatted(obj);
        cJSON *reparsed = cJSON_Parse(s);
        if (reparsed) {
            total += cJSON_GetArraySize(reparsed);
            cJSON_Delete(reparsed);
        }
        free(s);
        cJSON_Delete(obj);
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1e6;
    printf("%.2f\n", ms);
    return (total > 0) ? 0 : 1;
}
