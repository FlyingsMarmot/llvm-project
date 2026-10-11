#!/usr/bin/env python3
"""Test the staged/extracted uC++ clangd package with an isolated compile database."""
import argparse
import pathlib
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=pathlib.Path)
    args = parser.parse_args()
    package = args.package.resolve()
    binary = package / "bin" / "clangd"
    required = [binary, package / "bin" / "ucpp-include" / "uC++.h",
                package / "bin" / "uCPP" / "source" / "src" / "kernel" / "uCalendar.h"]
    for path in required:
        if not path.is_file():
            raise SystemExit("Missing package file: " + str(path))

    cases = [
        ("standard-cpp17", "c++17", "cpp", "#include <iterator>\n#include <vector>\nint main() { std::vector<int> v{1, 2}; return *v.begin(); }\n", None),
        ("standard-cpp20", "c++20", "cpp", "#include <iterator>\n#include <vector>\nint main() { std::vector<int> v{1, 2}; return *v.begin(); }\n", None),
        ("ucpp-runtime", "c++20", "cpp", "#include <uC++.h>\n#include <uPRNG.h>\n#include <type_traits>\nstatic_assert(!std::is_copy_constructible_v<uCondition>);\nstatic_assert(!std::is_copy_constructible_v<uBaseCoroutine>);\nstatic_assert(!std::is_copy_constructible_v<uProcessor>);\n_Coroutine Probe {};\n_Task TaskProbe {};\nvoid select(bool a, bool b) { _Select(a) {} or _Select(b) {} }\nint main() { uCondition c; PRNG random(1); return c.empty() ? random(10) : 0; }\n", None),
        ("ordinary-c", "c11", "c", "#include <stddef.h>\nint main(void) { size_t value = 1; return value; }\n", None),
        ("visible-user-error", "c++20", "cpp", "#include <uC++.h>\nint main() { return unknown_symbol; }\n", "use of undeclared identifier 'unknown_symbol'"),
    ]
    with tempfile.TemporaryDirectory(prefix="ucpp-package-smoke-") as temporary:
        root = pathlib.Path(temporary)
        for name, standard, suffix, source, expected_error in cases:
            directory = root / name
            directory.mkdir()
            flags = "-std=" + standard + "\n"
            if suffix == "cpp":
                flags += "-fcxx-exceptions\n"
            (directory / "compile_flags.txt").write_text(flags)
            filename = directory / ("sample." + suffix)
            filename.write_text(source)
            result = subprocess.run(
                [str(binary), "--check=" + str(filename),
                 "--compile-commands-dir=" + str(directory), "--enable-config=false"],
                cwd=directory, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, timeout=90)
            if expected_error is None:
                success = result.returncode == 0 and "All checks completed, 0 errors" in result.stderr
            else:
                success = result.returncode == 3 and expected_error in result.stderr
            if not success:
                raise SystemExit(name + " failed (exit " + str(result.returncode) + "):\n" + result.stderr)
            print("PASS: " + name)


if __name__ == "__main__":
    main()
