<?php

$CONFIG = [
    'onlyoffice' => [
        // Browser-facing address.
        'DocumentServerUrl' => 'https://office.home.arpa/',

        // Nextcloud -> ONLYOFFICE over Docker's web network.
        'DocumentServerInternalUrl' => 'http://onlyoffice/',

        // ONLYOFFICE -> Nextcloud over Docker's web network.
        'StorageUrl' => 'http://nextcloud/',

        // Must match onlyoffice's JWT_SECRET.
        'jwt_secret' => getenv('ONLYOFFICE_JWT_SECRET'),
        'jwt_header' => 'Authorization',
    ],
];
