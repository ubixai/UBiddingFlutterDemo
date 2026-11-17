# Core 4.1.2.11 probes this optional Honor API with Class.forName and catches
# absence before using its built-in implementation (verified against the locked AAR).
# These rules belong to this host, not the Flutter plugin. Keep R8 enabled.
# A host choosing the external Honor API must provide its actual SDK dependency.
-dontwarn com.hihonor.ads.identifier.AdvertisingIdClient
-dontwarn com.hihonor.ads.identifier.AdvertisingIdClient$Info
