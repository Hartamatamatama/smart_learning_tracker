// Minimal stub untuk Corbado Passkeys Web SDK.
// passkeys_web (transitive dep dari supabase_flutter) mengecek window.PasskeyAuthenticator
// saat startup. Kita tidak pakai fitur Passkeys, tapi stub ini mencegah app crash.
window.PasskeyAuthenticator = {};
