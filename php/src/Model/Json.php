<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Model;

/**
 * Lenient readers for PayWay JSON: values documented as strings are read as
 * strings, so a number (e.g. an account or mid) does not break parsing.
 *
 * @internal
 */
final class Json
{
    /** @param array<array-key, mixed> $json */
    public static function string(array $json, string $key): string
    {
        return self::optionalString($json, $key) ?? '';
    }

    /** @param array<array-key, mixed> $json */
    public static function optionalString(array $json, string $key): ?string
    {
        $value = $json[$key] ?? null;

        return match (true) {
            $value === null => null,
            \is_string($value) => $value,
            \is_int($value), \is_float($value) => (string) $value,
            \is_bool($value) => $value ? 'true' : 'false',
            default => null,
        };
    }

    /**
     * `code: label` maps; PHP encodes an empty associative array as `[]`.
     *
     * @param array<array-key, mixed> $json
     * @return array<string, string>
     */
    public static function methods(array $json, string $key): array
    {
        $value = $json[$key] ?? null;
        if (!\is_array($value) || array_is_list($value)) {
            return [];
        }
        $methods = [];
        foreach ($value as $code => $label) {
            $methods[(string) $code] = \is_scalar($label) ? (string) $label : '';
        }

        return $methods;
    }

    /**
     * @param array<array-key, mixed> $json
     * @return array<array-key, mixed>
     */
    public static function object(array $json, string $key): array
    {
        $value = $json[$key] ?? null;

        return \is_array($value) ? $value : [];
    }

    private function __construct()
    {
    }
}
