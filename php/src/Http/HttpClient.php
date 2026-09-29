<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner\Http;

use Kechankrisna\PaywayPartner\Exception\PaywayPartnerException;

/**
 * Sends one POST request. Implement it to plug in any HTTP stack, or use
 * {@see CurlHttpClient} (default) or {@see Psr18HttpClient}.
 */
interface HttpClient
{
    /**
     * POST `$body` to `$url` and return the reply, whatever its status code.
     *
     * @param array<string, string> $headers
     *
     * @throws PaywayPartnerException when no reply was received
     */
    public function post(string $url, array $headers, string $body): HttpResponse;
}
