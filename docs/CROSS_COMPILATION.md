# Cross-Compilation Support in rules_rust

This document describes the cross-compilation improvements made to rules_rust, particularly for WebAssembly and WASI targets.

## C++ Toolchain Integration

### Overview

When cross-compiling Rust code that interacts with C/C++ libraries, rules_rust needs access to the target platform's C++ toolchain tools (like `ar`, `ld`, etc.). This is particularly important for:

- WASI targets using WASI SDK
- Embedded targets with custom toolchains
- Any cross-compilation scenario where Rust and C++ code are linked together

### The Problem

Prior to these fixes, when cross-compiling Rust code for targets like WASI, the build would fail with errors like:

```
"execvp(external/+wasi_sdk+wasi_sdk/bin/ar, ...): No such file or directory"
```

This occurred because:
1. Rust's standard library compilation uses `cc_common` functions for linking
2. These functions expect C++ toolchain tools to be available as action inputs
3. Cross-compilation toolchains (like WASI SDK) store tools in external repositories
4. Without explicit action inputs, Bazel's sandbox couldn't access these tools

### The Solution

#### 1. Rust Toolchain Integration

In `rust/toolchain.bzl`, the `_rust_toolchain_impl()` function now includes C++ toolchain files:

```starlark
# Include C++ toolchain files to ensure tools like 'ar' are available for cross-compilation
cc_toolchain, _ = find_cc_toolchain(ctx)
all_files_depsets = [sysroot.all_files]
if cc_toolchain and cc_toolchain.all_files:
    all_files_depsets.append(cc_toolchain.all_files)

toolchain = platform_common.ToolchainInfo(
    all_files = depset(transitive = all_files_depsets),
    # ... rest of toolchain info
)
```

This ensures that when the Rust toolchain is used, it has access to all necessary C++ tools.

#### 2. Action Input Declaration

In `_make_libstd_and_allocator_ccinfo()`, C++ toolchain files are explicitly passed as action inputs:

```starlark
# Include C++ toolchain files as additional inputs for cross-compilation scenarios
additional_inputs = []
if cc_toolchain and cc_toolchain.all_files:
    additional_inputs = cc_toolchain.all_files.to_list()

linking_context, _linking_outputs = cc_common.create_linking_context_from_compilation_outputs(
    name = label.name,
    actions = actions,
    feature_configuration = feature_configuration,
    cc_toolchain = cc_toolchain,
    compilation_outputs = compilation_outputs,
    additional_inputs = additional_inputs,  # ← This ensures tools are available
)
```

#### 3. Type Safety

The implementation correctly handles type conversion from `depset` to `list` as required by the `cc_common` API:

```starlark
# cc_common functions expect sequences, not depsets
additional_inputs = cc_toolchain.all_files.to_list()
```

### Affected Components

1. **Standard Library Compilation**: When Rust's standard library is compiled for cross-compilation targets
2. **Mixed Rust/C++ Projects**: Projects that use both Rust and C++ code
3. **Custom Allocators**: When using custom allocator libraries with Rust

### Platform Compatibility

These fixes are designed to work with any cross-compilation scenario, including:

- **WASI/WebAssembly**: Using WASI SDK or other WebAssembly toolchains
- **Embedded Systems**: Custom ARM, RISC-V, or other embedded toolchains  
- **Mobile Targets**: Android NDK or iOS cross-compilation
- **Windows Cross-Compilation**: Using MinGW or similar toolchains

### Performance Impact

The changes have minimal performance impact:
- Files are only included when cross-compiling (not for host builds)
- The `depset` structure ensures efficient file handling
- Additional inputs are only added when a C++ toolchain is present

### Backward Compatibility

These changes are fully backward compatible:
- Host builds (same architecture) work unchanged
- Projects not using cross-compilation are unaffected
- Existing cross-compilation setups continue to work
- No changes to public APIs

### Usage Examples

#### Building for WASI

```bash
# The C++ toolchain integration automatically handles WASI SDK tools
bazel build //my/rust:target --platforms=@rules_rust//rust/platform:wasm32-wasip2
```

#### Custom Cross-Compilation Toolchain

```starlark
# Your custom cc_toolchain automatically works with Rust
cc_toolchain(
    name = "my_cross_toolchain",
    all_files = ":my_toolchain_files",
    ar_files = ":my_ar_tool",
    compiler_files = ":my_compiler",
    # ...
)

# rules_rust will automatically include these files as action inputs
```

### Troubleshooting

#### Common Issues

1. **Missing Tools Error**: If you still get "No such file or directory" errors:
   - Ensure your cc_toolchain properly declares all tool files in `all_files`
   - Verify the toolchain is registered for your target platform
   - Check that tool paths are correct in your toolchain configuration

2. **Type Errors**: If you see "got value of type 'depset', want 'sequence'":
   - This should be fixed by the type conversion in the implementation
   - If you see this in custom code, use `.to_list()` to convert depsets

3. **Performance Issues**: If builds are slower after these changes:
   - This typically indicates an issue with your cc_toolchain's `all_files` 
   - Consider using more specific file groups instead of including everything

#### Debugging

To debug cross-compilation toolchain issues:

```bash
# Check what cc_toolchain is being used
bazel query --output=build @your_toolchain//:cc_toolchain

# Verify platform constraints
bazel query --output=build //your/platform:definition

# Check toolchain resolution
bazel build //your:target --toolchain_resolution_debug=cc
```

### Implementation Details

The implementation handles several edge cases:

1. **Conditional Inclusion**: C++ toolchain files are only included when available
2. **Type Safety**: Proper conversion between depsets and sequences
3. **Performance**: Efficient file handling using Bazel's depset structure
4. **Compatibility**: Works with both new and legacy toolchain definitions

### Future Enhancements

Potential improvements for the future:

1. **Selective Tool Inclusion**: Only include specific tools (ar, ld) instead of all toolchain files
2. **Tool Validation**: Verify that required tools are present before starting the build
3. **Performance Optimization**: Cache toolchain file lists to reduce overhead
4. **Better Error Messages**: Provide clearer error messages when tools are missing

This cross-compilation integration ensures that rules_rust works seamlessly with any properly configured C++ toolchain, making it easy to build Rust code for any target platform.