#include "RebiliumNativeBridge.h"
#include <stdio.h>
#include <string.h>

// This program represents an application intentionally linked to our own
// dylib at process startup. No other process is opened or altered.
int main(void) {
    const char *source = "print('Hello from Rebilium!')";
    RebiliumBridgeResult result = {0};

    const int status = rebilium_submit_source(
        source, strlen(source), &result
    );
    if (status != 0 ||
        result.abi_version != REBILIUM_BRIDGE_ABI_VERSION ||
        !result.accepted ||
        result.source_length != strlen(source) ||
        result.source_fingerprint == 0) {
        fprintf(stderr, "Native bridge rejected the script (%d)\n", status);
        return 1;
    }

    printf("Native bridge: source transferred (%zu bytes; fingerprint=%016llx)\n",
           result.source_length,
           (unsigned long long)result.source_fingerprint);
    puts("No source was executed. No Roblox process was contacted.");
    return 0;
}
