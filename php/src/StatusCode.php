<?php

declare(strict_types=1);

namespace Kechankrisna\PaywayPartner;

/**
 * Status codes documented for the PayWay partner API, for comparing with
 * {@see Model\Status::$code}.
 */
final class StatusCode
{
    /** `00` Success! */
    public const string SUCCESS = '00';

    /** `PTL02` Wrong Hash */
    public const string WRONG_HASH = 'PTL02';

    /** `PTL04` Parameter Validation Required */
    public const string PARAMETER_VALIDATION_REQUIRED = 'PTL04';

    /** `PTL06` The Request is Expired */
    public const string REQUEST_EXPIRED = 'PTL06';

    /** `PTL46` Merchant not found */
    public const string MERCHANT_NOT_FOUND = 'PTL46';

    /** `PTL137` Partner id not found */
    public const string PARTNER_ID_NOT_FOUND = 'PTL137';

    /** `PTL141` The redirect url can not empty */
    public const string REDIRECT_URL_EMPTY = 'PTL141';

    /** `PTL142` The pushback url can not empty */
    public const string PUSHBACK_URL_EMPTY = 'PTL142';

    /** `PTL164` The register ref is already exist */
    public const string REGISTER_REF_ALREADY_EXISTS = 'PTL164';

    /** `PTL165` The register ref can not empty */
    public const string REGISTER_REF_EMPTY = 'PTL165';

    /** `PTL166` The register ref is invalid format */
    public const string REGISTER_REF_INVALID_FORMAT = 'PTL166';

    /** `PTL170` Your profile is deactivated */
    public const string PROFILE_DEACTIVATED = 'PTL170';

    /** `PTL171` Invalid request data: check the key and encryption method */
    public const string INVALID_REQUEST_DATA = 'PTL171';

    /** `PTL175` Requested Domain is not in whitelist */
    public const string DOMAIN_NOT_WHITELISTED = 'PTL175';

    private function __construct() {}
}
