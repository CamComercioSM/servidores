#!/usr/bin/env php
<?php

declare(strict_types=1);

const EXIT_OK = 0;
const EXIT_DIFF = 1;
const EXIT_ERROR = 2;

$options = [
    'project' => getcwd() ?: '.',
    'env' => '.env',
    'example' => '.env.example',
    'show_values' => false,
    'only_problems' => false,
    'strict' => false,
];

foreach (array_slice($argv, 1) as $arg) {
    if ($arg === '--show-values') { $options['show_values'] = true; continue; }
    if ($arg === '--only-problems') { $options['only_problems'] = true; continue; }
    if ($arg === '--strict') { $options['strict'] = true; continue; }
    if ($arg === '-h' || $arg === '--help') {
        echo "Verificador de .env para Laravel\n\n";
        echo "Uso: php verificar-env.php [RUTA_PROYECTO] [--env=.env] [--example=.env.example] [--only-problems] [--strict] [--show-values]\n";
        exit(EXIT_OK);
    }
    if (str_starts_with($arg, '--env=')) { $options['env'] = substr($arg, 6); continue; }
    if (str_starts_with($arg, '--example=')) { $options['example'] = substr($arg, 10); continue; }
    if (str_starts_with($arg, '--project=')) { $options['project'] = substr($arg, 10); continue; }
    if (!str_starts_with($arg, '-')) { $options['project'] = $arg; continue; }
    fwrite(STDERR, "Opcion no reconocida: {$arg}\n");
    exit(EXIT_ERROR);
}

try {
    $project = realpath((string)$options['project']);
    if ($project === false || !is_dir($project)) {
        throw new RuntimeException('No existe la ruta del proyecto.');
    }

    $envPath = resolvePath($project, (string)$options['env']);
    $examplePath = resolvePath($project, (string)$options['example']);

    if (!is_readable($envPath)) throw new RuntimeException("No se puede leer {$envPath}");
    if (!is_readable($examplePath)) throw new RuntimeException("No se puede leer {$examplePath}");

    $env = parseEnv($envPath);
    $example = parseEnv($examplePath);

    $missing = [];
    $extra = [];
    $same = [];
    $adjusted = [];
    $empty = [];

    foreach ($example['order'] as $key) {
        if (!isset($env['vars'][$key])) {
            $missing[$key] = $example['vars'][$key];
            continue;
        }
        $current = $env['vars'][$key];
        $default = $example['vars'][$key];
        if (isEmptyValue($current['normalized'])) $empty[$key] = $current;
        if ($current['normalized'] === $default['normalized']) {
            $same[$key] = ['default' => $default, 'current' => $current];
        } else {
            $adjusted[$key] = ['default' => $default, 'current' => $current];
        }
    }

    foreach ($env['order'] as $key) {
        if (!isset($example['vars'][$key])) $extra[$key] = $env['vars'][$key];
    }

    echo str_repeat('=', 72) . "\nVERIFICACION DE VARIABLES DE ENTORNO\n" . str_repeat('=', 72) . "\n";
    echo "Proyecto:      {$project}\n";
    echo "Archivo guia: " . basename($examplePath) . "\n";
    echo "Archivo .env: " . basename($envPath) . "\n\n";

    echo "RESUMEN\n";
    printf("  %-34s %d\n", 'Variables en .env.example:', count($example['vars']));
    printf("  %-34s %d\n", 'Variables en .env:', count($env['vars']));
    printf("  %-34s %d\n", 'Faltantes en .env:', count($missing));
    printf("  %-34s %d\n", 'Sobrantes en .env:', count($extra));
    printf("  %-34s %d\n", 'Con el valor por defecto:', count($same));
    printf("  %-34s %d\n", 'Con valor ajustado:', count($adjusted));
    printf("  %-34s %d\n", 'Vacias o nulas en .env:', count($empty));
    printf("  %-34s %d\n", 'Duplicadas en .env.example:', count($example['duplicates']));
    printf("  %-34s %d\n", 'Duplicadas en .env:', count($env['duplicates']));
    printf("  %-34s %d\n", 'Lineas no interpretadas:', count($example['invalid']) + count($env['invalid']));

    section('FALTAN EN .env', $missing, function ($key, $item) use ($options) {
        return "{$key} | guia: " . displayValue($key, $item['raw'], (bool)$options['show_values']);
    });
    section('SOBRAN EN .env', $extra, function ($key, $item) use ($options) {
        return "{$key} | actual: " . displayValue($key, $item['raw'], (bool)$options['show_values']);
    });
    section('SIGUEN CON EL VALOR POR DEFECTO', $same, function ($key, $item) use ($options) {
        return "{$key} = " . displayValue($key, $item['current']['raw'], (bool)$options['show_values']);
    });

    if (!$options['only_problems']) {
        section('VALORES AJUSTADOS', $adjusted, function ($key, $item) use ($options) {
            return "{$key}: " . displayValue($key, $item['default']['raw'], (bool)$options['show_values']) . ' -> ' . displayValue($key, $item['current']['raw'], (bool)$options['show_values']);
        });
    }

    section('VACIAS O NULAS EN .env', $empty, fn($key, $item) => $key);
    duplicateSection('DUPLICADAS EN .env.example', $example['duplicates']);
    duplicateSection('DUPLICADAS EN .env', $env['duplicates']);
    invalidSection('LINEAS NO INTERPRETADAS EN .env.example', $example['invalid'], (bool)$options['show_values']);
    invalidSection('LINEAS NO INTERPRETADAS EN .env', $env['invalid'], (bool)$options['show_values']);

    $structural = $missing || $extra || $example['duplicates'] || $env['duplicates'] || $example['invalid'] || $env['invalid'];
    $strictDiff = $structural || $same || $empty;
    $fail = $options['strict'] ? $strictDiff : $structural;

    echo "\n" . ($fail ? '[REQUIERE REVISION]' : '[OK]') . "\n";
    exit($fail ? EXIT_DIFF : EXIT_OK);
} catch (Throwable $e) {
    fwrite(STDERR, '[ERROR] ' . $e->getMessage() . "\n");
    exit(EXIT_ERROR);
}

function resolvePath(string $project, string $file): string {
    if (preg_match('/^(?:[A-Za-z]:[\\\\\/]|[\\\\\/])/', $file)) return $file;
    return $project . DIRECTORY_SEPARATOR . $file;
}

function parseEnv(string $path): array {
    $vars = []; $order = []; $occurrences = []; $invalid = [];
    $lines = preg_split('/\R/', (string)file_get_contents($path)) ?: [];
    foreach ($lines as $i => $line) {
        $number = $i + 1; $trim = trim($line);
        if ($trim === '' || str_starts_with($trim, '#')) continue;
        if (!preg_match('/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$/', ltrim($line), $m)) {
            $invalid[] = ['line' => $number, 'text' => $line]; continue;
        }
        $key = $m[1]; $raw = stripComment($m[2]);
        if (!isset($occurrences[$key])) { $occurrences[$key] = []; $order[] = $key; }
        $occurrences[$key][] = $number;
        $vars[$key] = ['raw' => $raw, 'normalized' => normalizeValue($raw), 'line' => $number];
    }
    $duplicates = array_filter($occurrences, fn($lines) => count($lines) > 1);
    return compact('vars', 'order', 'duplicates', 'invalid');
}

function stripComment(string $value): string {
    $value = trim($value); $quote = null; $escaped = false; $len = strlen($value);
    for ($i = 0; $i < $len; $i++) {
        $c = $value[$i];
        if ($escaped) { $escaped = false; continue; }
        if ($c === '\\' && $quote === '"') { $escaped = true; continue; }
        if (($c === '"' || $c === "'") && ($quote === null || $quote === $c)) { $quote = $quote === null ? $c : null; continue; }
        if ($c === '#' && $quote === null && ($i === 0 || ctype_space($value[$i - 1]))) return rtrim(substr($value, 0, $i));
    }
    return trim($value);
}

function normalizeValue(string $raw): string {
    $v = trim($raw);
    if (strlen($v) >= 2 && (($v[0] === '"' && $v[-1] === '"') || ($v[0] === "'" && $v[-1] === "'"))) $v = substr($v, 1, -1);
    return trim($v);
}

function isEmptyValue(string $v): bool {
    return $v === '' || in_array(strtolower($v), ['null', '(null)', 'empty', '(empty)'], true);
}

function sensitive(string $key, string $value): bool {
    if (preg_match('/PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE|CREDENTIAL|APP_KEY|API_KEY|ACCESS_KEY|SIGNING_KEY|ENCRYPTION_KEY|WEBHOOK_SECRET|DSN/i', $key)) return true;
    return preg_match('/(?:DATABASE|DB|REDIS|MAIL|MONGO|ELASTIC)_URL/i', $key) && str_contains($value, '@');
}

function displayValue(string $key, string $raw, bool $show): string {
    $v = trim($raw);
    if (isEmptyValue(normalizeValue($v))) return '<vacio>';
    if (!$show && sensitive($key, $v)) return '<oculto, ' . strlen($v) . ' caracteres>';
    $v = str_replace(["\r", "\n", "\t", "\0", "\x1B"], ['\\r', '\\n', '\\t', '\\0', '<ESC>'], $v);
    return strlen($v) > 100 ? substr($v, 0, 97) . '...' : $v;
}

function section(string $title, array $items, callable $formatter): void {
    if (!$items) return;
    echo "\n{$title}\n" . str_repeat('-', min(72, max(24, strlen($title)))) . "\n";
    foreach ($items as $key => $item) echo '  - ' . $formatter($key, $item) . "\n";
}

function duplicateSection(string $title, array $items): void {
    if (!$items) return;
    echo "\n{$title}\n" . str_repeat('-', min(72, max(24, strlen($title)))) . "\n";
    foreach ($items as $key => $lines) echo "  - {$key} | lineas: " . implode(', ', $lines) . " | se compara la ultima definicion\n";
}

function invalidSection(string $title, array $items, bool $show): void {
    if (!$items) return;
    echo "\n{$title}\n" . str_repeat('-', min(72, max(24, strlen($title)))) . "\n";
    foreach ($items as $item) echo '  - linea ' . $item['line'] . ($show ? ': ' . $item['text'] : ' | contenido oculto; use --show-values') . "\n";
}
