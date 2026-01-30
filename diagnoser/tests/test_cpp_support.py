#!/usr/bin/env python3
"""
Test C++ support in DockerCompiler

Tests:
1. C++ file detection
2. C++ standard detection
3. Compilation with clang++
4. C file compilation (regression test)
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from docker_compiler import DockerCompiler

def test_cpp_detection():
    """Test C++ file detection."""
    print("=" * 70)
    print("TEST 1: C++ File Detection")
    print("=" * 70)

    dc = DockerCompiler(verbose=True)

    test_cases = [
        ("test.cpp", True),
        ("test.cxx", True),
        ("test.cc", True),
        ("test.C", True),
        ("test.hpp", True),
        ("test.c", False),
        ("test.h", False),
    ]

    for filename, expected in test_cases:
        result = dc._is_cpp_file(filename)
        status = "✅" if result == expected else "❌"
        print(f"{status} {filename}: {'C++' if result else 'C'} (expected: {'C++' if expected else 'C'})")

    print()

def test_cpp_standard_detection():
    """Test C++ standard detection."""
    print("=" * 70)
    print("TEST 2: C++ Standard Detection")
    print("=" * 70)

    dc = DockerCompiler(verbose=True)

    # Test with llvm-175018.cpp
    test_file = Path(__file__).parent.parent / "evaluation" / "testcases" / "llvm-175018.cpp"
    if test_file.exists():
        std = dc._detect_cpp_standard(str(test_file))
        print(f"llvm-175018.cpp detected standard: {std}")
        print(f"✅ Expected C++20 (contains std::optional): {std == '-std=c++20'}")
    else:
        print(f"⚠️  Test file not found: {test_file}")

    print()

def test_cpp_compilation():
    """Test C++ compilation with different LLVM versions."""
    print("=" * 70)
    print("TEST 3: C++ Compilation")
    print("=" * 70)

    dc = DockerCompiler(verbose=True)

    # Test with llvm-175018.cpp
    source_file = Path(__file__).parent.parent / "evaluation" / "testcases" / "llvm-175018.cpp"
    if not source_file.exists():
        print(f"❌ Test file not found: {source_file}")
        return

    output_file = Path(__file__).parent / "test_cpp_output"

    # Test LLVM 19 (should work)
    print("\nTesting LLVM 19 (expected: ✅ compile success)...")
    success, stdout, stderr = dc.compile(
        str(source_file),
        str(output_file),
        "19",
        "-O1"
    )

    if success:
        print("✅ LLVM 19 compilation succeeded")
        # Test execution (use clang image for C++ runtime)
        run_success, returncode, stdout, stderr = dc.run_binary(
            str(output_file),
            use_clang_image=True,
            clang_version="19"
        )
        if run_success:
            print(f"   Output: {stdout.strip()}")
            print(f"   Expected: 0 (std::nullopt)")
            print(f"   ✅ Result matches expected" if stdout.strip() == "0" else f"   ❌ Result mismatch")
        else:
            print(f"   ❌ Execution failed: {stderr}")
        output_file.unlink()  # Cleanup
    else:
        print(f"❌ LLVM 19 compilation failed")
        print(f"   stderr: {stderr[:200]}")

    # Test LLVM 20 (should work but buggy output)
    print("\nTesting LLVM 20 (expected: ✅ compile success, ❌ buggy output)...")
    success, stdout, stderr = dc.compile(
        str(source_file),
        str(output_file),
        "20",
        "-O1"
    )

    if success:
        print("✅ LLVM 20 compilation succeeded")
        # Test execution (use clang image for C++ runtime)
        run_success, returncode, stdout, stderr = dc.run_binary(
            str(output_file),
            use_clang_image=True,
            clang_version="20"
        )
        if run_success:
            print(f"   Output: {stdout.strip()}")
            print(f"   Expected: 1 (buggy - incorrectly has value)")
            print(f"   ✅ Bug reproduced!" if stdout.strip() == "1" else f"   ⚠️  Unexpected result")
        else:
            print(f"   ❌ Execution failed: {stderr}")
        output_file.unlink()  # Cleanup
    else:
        print(f"❌ LLVM 20 compilation failed")
        print(f"   stderr: {stderr[:200]}")

    print()

def test_c_compilation_regression():
    """Test C file compilation (ensure no regression)."""
    print("=" * 70)
    print("TEST 4: C Compilation (Regression Test)")
    print("=" * 70)

    dc = DockerCompiler(verbose=True)

    # Create a simple C test file
    test_c_file = Path(__file__).parent / "test_simple.c"
    test_c_file.write_text("""
#include <stdio.h>

int main() {
    printf("Hello from C\\n");
    return 0;
}
""")

    output_file = Path(__file__).parent / "test_c_output"

    print("\nTesting C file compilation with LLVM 19...")
    success, stdout, stderr = dc.compile(
        str(test_c_file),
        str(output_file),
        "19",
        "-O2"
    )

    if success:
        print("✅ C file compilation succeeded")
        # Test execution (use Docker since binary is x86_64)
        run_success, returncode, stdout, stderr = dc.run_binary(str(output_file))
        if run_success:
            print(f"   Output: {stdout.strip()}")
            print(f"   ✅ C compilation works" if "Hello from C" in stdout else "   ❌ Unexpected output")
        else:
            print(f"   ❌ Execution failed: {stderr}")
        output_file.unlink()  # Cleanup
    else:
        print(f"❌ C file compilation failed")
        print(f"   stderr: {stderr[:200]}")

    # Cleanup test file
    test_c_file.unlink()

    print()

def main():
    """Run all tests."""
    print("\n" + "=" * 70)
    print("DOCKERCOMPILER C++ SUPPORT TESTS")
    print("=" * 70 + "\n")

    try:
        test_cpp_detection()
        test_cpp_standard_detection()
        test_cpp_compilation()
        test_c_compilation_regression()

        print("=" * 70)
        print("ALL TESTS COMPLETE")
        print("=" * 70)

    except Exception as e:
        print(f"\n❌ Test suite failed with error: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
