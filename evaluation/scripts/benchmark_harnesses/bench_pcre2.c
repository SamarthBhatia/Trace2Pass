/* Trace2Pass benchmark harness: pcre2 (regex compile + match) */
#define PCRE2_CODE_UNIT_WIDTH 8
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <pcre2.h>

static const char *patterns[] = {
    "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b",  /* email */
    "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b",         /* IP addr */
    "^(https?|ftp)://[^\\s/$.?#].[^\\s]*$",                      /* URL */
    "(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\s+\\w+\\s+\\d+",            /* date */
    "\\b[A-Z][a-z]+\\s+[A-Z][a-z]+\\b",                          /* name */
};
#define NUM_PATTERNS 5

static const char *subjects[] = {
    "Contact user@example.com for more information about the project.",
    "Server at 192.168.1.100 responded with error code 500 at 10:30.",
    "Visit https://www.example.com/path?q=test for documentation.",
    "Meeting scheduled for Mon January 15 at the conference room.",
    "Report submitted by John Smith on behalf of the engineering team.",
    "Send email to admin@test.org or fallback to backup@server.net now.",
    "DNS resolved to 10.0.0.1 and 172.16.0.1 for the load balancer.",
    "See http://docs.example.org/api#auth for the API reference guide.",
    "Available dates: Tue March 5, Wed March 6, Thu March 7 this week.",
    "Authors: Alice Johnson, Bob Williams, Carol Davis contributed here.",
};
#define NUM_SUBJECTS 10

int main(void) {
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    int total_matches = 0;

    for (int iter = 0; iter < 1000; iter++) {
        for (int p = 0; p < NUM_PATTERNS; p++) {
            int errcode;
            PCRE2_SIZE erroffset;
            pcre2_code *re = pcre2_compile(
                (PCRE2_SPTR)patterns[p], PCRE2_ZERO_TERMINATED,
                0, &errcode, &erroffset, NULL);
            if (!re) continue;

            pcre2_match_data *match_data = pcre2_match_data_create_from_pattern(re, NULL);

            for (int s = 0; s < NUM_SUBJECTS; s++) {
                int rc = pcre2_match(re, (PCRE2_SPTR)subjects[s],
                    strlen(subjects[s]), 0, 0, match_data, NULL);
                if (rc > 0) total_matches++;
            }

            pcre2_match_data_free(match_data);
            pcre2_code_free(re);
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &end);
    double ms = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;

    if (total_matches == 0) return 1;  /* sanity check */
    printf("%.1f\n", ms);
    return 0;
}
