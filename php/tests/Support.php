<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Tests;

use Kechankrisna\PaywayPartner\Http\HttpResponse;
use Kechankrisna\PaywayPartner\PaywayPartner;

/** Access to spec/ and fakes shared by the tests. */
final class Support
{
    /** @return array<string, mixed> a file of spec/test-vectors */
    public static function vectors(string $name): array
    {
        $json = json_decode(
            (string) file_get_contents(__DIR__ . "/../../spec/test-vectors/{$name}"),
            true,
            512,
            JSON_THROW_ON_ERROR,
        );
        \assert(\is_array($json));

        /** @var array<string, mixed> $json */
        return $json;
    }

    /** a key of spec/fixtures */
    public static function fixture(string $name): string
    {
        return (string) file_get_contents(__DIR__ . "/../../spec/fixtures/{$name}");
    }

    /** the partner every vector uses */
    public static function partner(): PaywayPartner
    {
        $p = self::vectors('partner.json');

        return new PaywayPartner(
            'Test Partner',
            self::str($p['partner_id']),
            self::str($p['partner_key']),
            self::fixture(self::str($p['private_key'])),
            self::fixture(self::str($p['public_key'])),
            self::str($p['referer']),
            self::str($p['base_url']),
        );
    }

    public static function str(mixed $value): string
    {
        \assert(\is_string($value));

        return $value;
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function cases(mixed $value): array
    {
        \assert(\is_array($value) && array_is_list($value));

        /** @var list<array<string, mixed>> $value */
        return $value;
    }

    /**
     * An HttpClient that records requests and answers with `$reply`.
     *
     * @param \Closure(string, array<string, string>, string): HttpResponse $reply
     */
    public static function fakeHttp(\Closure $reply): FakeHttpClient
    {
        return new FakeHttpClient($reply);
    }
}
