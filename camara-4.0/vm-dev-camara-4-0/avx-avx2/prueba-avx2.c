#include <immintrin.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define ELEMENTOS 8000000U

static uint64_t checksum_escalar(const uint32_t *a, const uint32_t *b, size_t n) {
    uint64_t total = 0;

    for (size_t i = 0; i < n; ++i) {
        total += (uint64_t)a[i] + (uint64_t)b[i];
    }

    return total;
}

static uint64_t checksum_avx2(const uint32_t *a, const uint32_t *b, size_t n) {
    uint64_t total = 0;

    for (size_t i = 0; i < n; i += 8U) {
        const __m256i va = _mm256_loadu_si256((const __m256i *)(const void *)&a[i]);
        const __m256i vb = _mm256_loadu_si256((const __m256i *)(const void *)&b[i]);
        const __m256i suma = _mm256_add_epi32(va, vb);

        uint32_t resultados[8];
        _mm256_storeu_si256((__m256i *)(void *)resultados, suma);

        for (size_t j = 0; j < 8U; ++j) {
            total += resultados[j];
        }
    }

    return total;
}

int main(void) {
#if !defined(__AVX2__)
    fprintf(stderr, "ERROR: el programa no fue compilado con soporte AVX2.\n");
    return 2;
#endif

    if (!__builtin_cpu_supports("avx2")) {
        fprintf(stderr, "ERROR: la CPU visible para el proceso no informa soporte AVX2.\n");
        return 3;
    }

    if ((ELEMENTOS % 8U) != 0U) {
        fprintf(stderr, "ERROR: ELEMENTOS debe ser multiplo de 8.\n");
        return 4;
    }

    uint32_t *a = aligned_alloc(32U, (size_t)ELEMENTOS * sizeof(*a));
    uint32_t *b = aligned_alloc(32U, (size_t)ELEMENTOS * sizeof(*b));

    if (a == NULL || b == NULL) {
        fprintf(stderr, "ERROR: no fue posible reservar memoria.\n");
        free(a);
        free(b);
        return 5;
    }

    for (size_t i = 0; i < ELEMENTOS; ++i) {
        a[i] = (uint32_t)(i % 1000U);
        b[i] = (uint32_t)((i * 3U) % 1000U);
    }

    const uint64_t escalar = checksum_escalar(a, b, ELEMENTOS);
    const uint64_t avx2 = checksum_avx2(a, b, ELEMENTOS);

    printf("Elementos procesados: %u\n", ELEMENTOS);
    printf("Checksum escalar:  %" PRIu64 "\n", escalar);
    printf("Checksum AVX2:     %" PRIu64 "\n", avx2);

    free(a);
    free(b);

    if (escalar != avx2) {
        fprintf(stderr, "ERROR: el resultado AVX2 no coincide con el resultado escalar.\n");
        return 6;
    }

    puts("PRUEBA AVX2 EXITOSA: se ejecutaron instrucciones vectoriales AVX2 y el resultado fue correcto.");
    return 0;
}
