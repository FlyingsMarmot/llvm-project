# uC++ clangd development

The uC++ changes are implemented in Clang's parser and in clangd. This guide
describes how to build the backend, run its regression test, and test it
through the VS Code extension.

The easiest workflow uses the cross-platform development helper in the
`vscode-clangd` repository. Clone the repositories beside each other:

```text
development/
├── llvm-project/
└── vscode-clangd/
```

Then run:

```bash
cd ../vscode-clangd
npm ci
npm run dev:all
```

This builds and tests the backend, packages and installs the extension into an
isolated VS Code profile, configures it to use the local clangd, and opens a
disposable test project. No environment variables or manual VS Code settings
are required.

The stages can also be run independently:

```bash
npm run dev:backend
npm run dev:test-backend
npm run dev:vscode
```

If the repositories are not siblings, add
`-- --llvm-project /path/to/llvm-project` to any command.

## Build clangd locally

Install a C/C++ compiler, CMake, and Ninja. The manual commands in this section
run from the root of the `llvm-project` checkout:

```bash
cd /path/to/llvm-project

cmake -G Ninja -S llvm -B build/ucpp-clangd \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS='clang;clang-tools-extra' \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=ON \
  -DLLVM_PARALLEL_LINK_JOBS=1 \
  -DLLVM_TARGETS_TO_BUILD=Native

cmake --build build/ucpp-clangd \
  --target clang clangd ClangdTests \
  --parallel 2
```

The resulting language server is
`build/ucpp-clangd/bin/clangd`. Re-run the `cmake --build` command after
changing the parser or clangd.

## Test the backend

Run the uC++ parser regression test with:

```bash
build/ucpp-clangd/bin/clang -cc1 \
  -std=c++20 \
  -fcxx-exceptions \
  -Wno-everything \
  -fsyntax-only \
  -verify \
  clang/test/Parser/ucpp-complete.cpp
```

Run the semantic-highlighting regression for uC++ statements with:

```bash
build/ucpp-clangd/tools/clang/tools/extra/clangd/unittests/ClangdTests \
  --gtest_filter=SemanticHighlighting.UCPPStatements
```

To include clangd's other semantic-highlighting regressions:

```bash
build/ucpp-clangd/tools/clang/tools/extra/clangd/unittests/ClangdTests \
  --gtest_filter='SemanticHighlighting.*'
```

For a standalone clangd smoke test against a source file:

```bash
build/ucpp-clangd/bin/clangd \
  --check=/absolute/path/to/test.cpp \
  --enable-config=false \
  --log=verbose
```

Running `build/ucpp-clangd/bin/clangd --log=verbose` without `--check` starts
the language server normally. It then waits for an editor to send framed LSP
messages on standard input, so an apparently idle process is expected.

## Test through the VS Code extension

The recommended command packages the extension, creates an isolated profile,
writes its local clangd setting, installs the VSIX, and launches VS Code:

```bash
cd ../vscode-clangd
npm run dev:vscode
```

By default, the helper finds an `llvm-project` checkout beside
`vscode-clangd`. For another checkout location, run:

```bash
npm run dev:vscode -- --llvm-project /path/to/llvm-project
```

The helper detects the standard macOS VS Code installation and the `code`
launcher on Linux and Windows. Use `--code /path/to/code` for other
installations, `--sandbox /path/to/directory` for another isolated profile
location, or `--no-launch` to prepare the profile without opening it.

The extension launches clangd itself and communicates with it using LSP over
the process's standard input and output. It does not attach to a clangd process
started separately in a terminal.

To run the extension without the helper, set the backend executable in VS
Code's JSON settings:

```json
{
  "clangd.path": "/absolute/path/to/llvm-project/build/ucpp-clangd/bin/clangd",
  "clangd.arguments": ["--log=verbose"],
  "clangd.checkUpdates": false
}
```

Reload VS Code after changing the executable path.

Open a C++ or uC++ source file from the test project, then select
**View → Output → clangd**. The first lines should show the clangd executable
under `build/ucpp-clangd/bin`; this verifies that VS Code did not select a
system-installed clangd.

## Publish the backend

Run **Publish uC++ clangd** from GitHub Actions with a semantic
`release_version`. Use `build-only` to test the packages,
`publish-prerelease` to create the candidate, and `promote-stable` after
verification.

Each build produces Linux x86-64, macOS Intel, and macOS Apple Silicon
archives. Promotion is blocked unless all three tested assets are attached to
the prerelease.
