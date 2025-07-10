# WASI Platform Support in rules_rust

This document describes the WebAssembly System Interface (WASI) platform support in rules_rust.

## Overview

rules_rust supports building Rust code for various WASI preview versions:
- **wasm32-wasip1** - WASI Preview 1 (stable)
- **wasm32-wasip2** - WASI Preview 2 (stable) 
- **wasm32-wasip3** - WASI Preview 3 (experimental - prepared for future Rust support)

Additionally, the following WebAssembly targets are supported:
- **wasm32-unknown-unknown** - Bare WebAssembly without WASI
- **wasm32-unknown-emscripten** - Emscripten WebAssembly target
- **wasm32-wasip1-threads** - WASI Preview 1 with threads support
- **wasm32v1-none** - WebAssembly MVP specification target
- **wasm64-unknown-unknown** - 64-bit WebAssembly (experimental)

## Platform Configuration

### Constraint Settings

WASI versions are differentiated using Bazel's constraint system:

```starlark
# Platform definitions
platform(
    name = "wasm32-wasip2",
    constraint_values = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
        "@rules_rust//rust/platform:wasi_preview_2",
    ],
)
```

### Using WASI Platforms

To build for a specific WASI version:

```bash
# Build for WASI Preview 1
bazel build //your/target --platforms=@rules_rust//rust/platform:wasm32-wasip1

# Build for WASI Preview 2  
bazel build //your/target --platforms=@rules_rust//rust/platform:wasm32-wasip2

# Build for WASI Preview 3 (experimental)
bazel build //your/target --platforms=@rules_rust//rust/platform:wasm32-wasip3
```

### Backward Compatibility

For backward compatibility, `wasm32-wasi` is aliased to `wasm32-wasip1`:

```bash
# These are equivalent
bazel build //your/target --platforms=@rules_rust//rust/platform:wasm32-wasi
bazel build //your/target --platforms=@rules_rust//rust/platform:wasm32-wasip1
```

## Toolchain Setup

### Basic Configuration

In your `MODULE.bazel`:

```starlark
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
rust.toolchain(
    edition = "2021",
    extra_target_triples = [
        "wasm32-unknown-unknown",
        "wasm32-wasip1", 
        "wasm32-wasip2",
        # "wasm32-wasip3",  # Uncomment when Rust adds support
    ],
    versions = ["1.88.0"],
)
use_repo(rust, "rust_toolchains")
register_toolchains("@rust_toolchains//:all")
```

### WASI SDK Integration

For building C/C++ code alongside Rust for WASI targets, you'll need the WASI SDK:

```starlark
# Example WASI SDK setup (adjust to your needs)
http_archive(
    name = "wasi_sdk",
    # ... WASI SDK configuration ...
)
```

## Cross-Compilation Considerations

### Allocator Library

When building mixed Rust/C++ binaries for WASI, the allocator library handles symbol resolution correctly without requiring system headers, avoiding sandboxing issues.

### C++ Toolchain Integration

rules_rust automatically includes C++ toolchain files as action inputs when cross-compiling for WASI targets. This ensures tools like `ar` from the WASI SDK are available during the build process.

## Platform Selection with Transitions

While explicit platform selection via `--platforms` flag works, you can also use platform transitions in your BUILD files:

```starlark
# Future enhancement - configuration transitions
def _wasi_transition_impl(settings, attr):
    if attr.target_triple.startswith("wasm32-wasip2"):
        return {"//command_line_option:platforms": "@rules_rust//rust/platform:wasm32-wasip2"}
    return {}

wasi_transition = transition(
    implementation = _wasi_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)
```

## Known Limitations

1. **wasm32-wasip3**: This target is experimental and prepared for future use. Rust does not yet have an official wasm32-wasip3 target.

2. **wasm64-unknown-unknown**: 64-bit WebAssembly support is limited as the standard library is not available for this target.

3. **Dynamic Linking**: WASI targets do not support dynamic linking. All libraries must be statically linked.

## Example Usage

### Basic Rust Library for WASI

```starlark
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "my_wasi_lib",
    srcs = ["lib.rs"],
    edition = "2021",
    target_compatible_with = [
        "@platforms//cpu:wasm32",
        "@platforms//os:wasi",
    ],
)
```

### Building a WASI Binary

```starlark
load("@rules_rust//rust:defs.bzl", "rust_binary")

rust_binary(
    name = "my_wasi_app",
    srcs = ["main.rs"],
    edition = "2021",
    deps = [":my_wasi_lib"],
)
```

Build command:
```bash
bazel build //path/to:my_wasi_app --platforms=@rules_rust//rust/platform:wasm32-wasip2
```

## Testing

WASI platform support is tested through:
- Platform triple parsing tests in `test/unit/platform_triple/`
- Constraint mapping tests ensuring correct platform selection
- Integration tests with actual WASI toolchains (when available)

## Future Enhancements

1. **Automatic WASI Version Selection**: Configuration transitions could automatically select the appropriate WASI version based on target requirements.

2. **Toolchain Composition**: A unified Rust+WASI SDK toolchain could simplify cross-compilation setup.

3. **WASI Preview 3**: When Rust adds official support for wasm32-wasip3, the experimental platform definition will be ready for use.