<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Tests;

use Kechankrisna\PaywayPartner\Http\HttpClient;
use Kechankrisna\PaywayPartner\Http\HttpResponse;

/** Records requests and answers with a closure. */
final class FakeHttpClient implements HttpClient
{
    /** @var list<array{url: string, headers: array<string, string>, body: array<string, string>}> */
    public array $requests = [];

    /** @param \Closure(string, array<string, string>, string): HttpResponse $reply */
    public function __construct(private readonly \Closure $reply) {}

    public function post(string $url, array $headers, string $body): HttpResponse
    {
        /** @var array<string, string> $decoded */
        $decoded = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
        $this->requests[] = ['url' => $url, 'headers' => $headers, 'body' => $decoded];

        return ($this->reply)($url, $headers, $body);
    }
}
