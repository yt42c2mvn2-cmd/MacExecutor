#ifndef REBILIUM_NATIVE_BRIDGE_H
#define REBILIUM_NATIVE_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

// This API is restricted to a host we compile and own.
// It does not provide a Roblox connection, VM integration or code execution.
#define REBILIUM_BRIDGE_ABI_VERSION 1
#define REBILIUM_MAX_SCRIPT_BYTES (1024u * 1024u)

typedef struct {
    uint32_t abi_version;
    uint32_t accepted;
    size_t source_length;
    uint64_t source_fingerprint;
} RebiliumBridgeResult;

// Returns metadata only. Never evaluates, compiles, or executes source.
int rebilium_submit_source(
    const char *source,
    size_t length,
    RebiliumBridgeResult *result
);

#endif
