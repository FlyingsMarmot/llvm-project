# uC++ editor declarations

`uC++.h` contains a subset of public uC++ 7.0.0 runtime declarations for
code completion and diagnostics. It is installed under `bin/ucpp-include`
and is automatically included by the packaged language server. The full
runtime source remains under `bin/uCPP` for the library and collection headers.

These declarations intentionally omit platform internals, object layouts,
and implementation bodies. They are not a runtime, an ABI contract, or a
replacement for the native uC++ toolchain. APIs not declared here must be
added from the authoritative runtime signatures, with a packaged smoke test.

The raw kernel header cannot be implicitly included on arbitrary platforms:
it depends on Linux-specific unwind and threading interfaces. Parsing it in
an editor can leave invalid ASTs, particularly when platform includes are
missing. Do not restore that implicit inclusion to add editor declarations.

To test a staged or extracted package locally:

```sh
python3 clang-tools-extra/clangd/test/ucpp-packaged-smoke.py /path/to/package
```

The same test runs in release CI and checks C++17/C++20 standard headers,
uC++ syntax, common runtime declarations, an ordinary C file, and visibility
of user errors. Keep the whole package together, including Clang resources.
