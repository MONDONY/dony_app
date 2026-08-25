/// Autorité de certification épinglée pour les appels à l'API de production.
///
/// C'est l'**intermédiaire émetteur**, pas le certificat du serveur. Épingler
/// la feuille condamnerait l'application : Let's Encrypt la renouvelle tous
/// les 90 jours environ, et tout binaire déjà installé cesserait de joindre
/// l'API au premier renouvellement, sur une erreur réseau sans explication.
/// L'intermédiaire vit plusieurs années, et la feuille qu'il signe peut
/// tourner librement sous lui.
///
/// subject=C=US, O=Let's Encrypt, CN=YE1
/// issuer=C=US, O=ISRG, CN=Root YE
/// notAfter=Sep  2 23:59:59 2028 GMT
///
/// Pour le mettre à jour le jour où l'intermédiaire lui-même changera :
///
/// ```sh
/// openssl s_client -connect api.yadony.com:443 -servername api.yadony.com \
///   -showcerts </dev/null 2>/dev/null \
///   | awk '/BEGIN CERT/{n++} n==2{print} /END CERT/{if(n==2) exit}'
/// ```
///
/// Ce certificat est public : il transite en clair à chaque poignée de main
/// TLS. Le versionner n'expose rien.
const tlsPinnedIssuerPem = '''
-----BEGIN CERTIFICATE-----
MIICizCCAhGgAwIBAgIQXd1w3TH4AchcGGp6BLgK/jAKBggqhkjOPQQDAzAuMQsw
CQYDVQQGEwJVUzENMAsGA1UEChMESVNSRzEQMA4GA1UEAxMHUm9vdCBZRTAeFw0y
NTA5MDMwMDAwMDBaFw0yODA5MDIyMzU5NTlaMDMxCzAJBgNVBAYTAlVTMRYwFAYD
VQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNZRTEwdjAQBgcqhkjOPQIBBgUr
gQQAIgNiAAQHZVB1/mimla2hfSurylScjPMZaOJXLz/NnAc2sylm8WDyhU9Ccp+z
ASQi5vSwGGJjSGklkD9fdPR8GpyDIOIjCEfrnbt/v+ZSEPLLEGbaM6EccDbN7p9x
teIm2Avf+ryjge4wgeswDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUF
BwMBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLsgykcL/tflnPmPCSqj
jDdFsbzYMB8GA1UdIwQYMBaAFKPIJlqOoUzQNWP8myPIOq5W809WMDIGCCsGAQUF
BwEBBCYwJDAiBggrBgEFBQcwAoYWaHR0cDovL3llLmkubGVuY3Iub3JnLzATBgNV
HSAEDDAKMAgGBmeBDAECATAnBgNVHR8EIDAeMBygGqAYhhZodHRwOi8veWUuYy5s
ZW5jci5vcmcvMAoGCCqGSM49BAMDA2gAMGUCMQDgjUEahFT/h3DRakqiPZpLvPgf
Zwkt6K2EOMmh1nvEzl83eMLYcod4GCl3b0J1Nn0CMBNYmEQJb4CEG5WoOe7aRn/L
VKu6saHmHEynI7ysIPd8zQsK1HdmhlHKlw9Z5GpGvA==
-----END CERTIFICATE-----
''';
