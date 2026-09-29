<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

/** Version of this package, sent in the `User-Agent` header. */
final class Version
{
    /** Kept in sync with the git tag by php/tests/UnitTest.php and CI. */
    public const string SDK_VERSION = '1.0.0';

    private function __construct()
    {
    }
}
