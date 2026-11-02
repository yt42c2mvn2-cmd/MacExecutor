#include "RebiliumNativeBridge.h"

int rebilium_submit_source(
    const char *source,
    size_t length,
    RebiliumBridgeResult *result
) {
    if (!result) return -1;

    *result = (RebiliumBridgeResult){0};
    result->abi_version = REBILIUM_BRIDGE_ABI_VERSION;

    if (length > REBILIUM_MAX_SCRIPT_BYTES) return -2;
    if (!source && length > 0) return -3;

    // FNV-1a identifies an intact message across the ABI boundary.
    // This is a fast diagnostic fingerprint, not a cryptographic hash.
    uint64_t digest = UINT64_C(14695981039346656037);
    for (size_t i = 0; i < length; i++) {
        digest ^= (unsigned char)source[i];
        digest *= UINT64_C(1099511628211);
    }

    result->accepted = 1;
    result->source_length = length;
    result->source_fingerprint = digest;
    return 0;
}
