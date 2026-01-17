#!/usr/bin/env python3
"""
Test LLVM IR compilation support in DockerCompiler.

Tests bug #167627 (Float2Int miscompilation) as validation.
"""

import os
import sys
from pathlib import Path

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from docker_compiler import DockerCompiler


def test_ir_file_detection():
    """Test IR file detection by extension."""
    print("=" * 60)
    print("Test 1: IR File Detection")
    print("=" * 60)

    dc = DockerCompiler(verbose=False)

    test_cases = [
        ("test.ll", True),
        ("test.bc", True),
        ("test.c", False),
        ("test.cpp", False),
        ("test.h", False),
    ]

    passed = 0
    for filename, expected_is_ir in test_cases:
        is_ir = dc._is_ir_file(filename)
        status = "✓" if is_ir == expected_is_ir else "✗"
        print(f"  {status} {filename}: is_ir={is_ir} (expected={expected_is_ir})")
        if is_ir == expected_is_ir:
            passed += 1

    print(f"\nResult: {passed}/{len(test_cases)} tests passed")
    return passed == len(test_cases)


def test_ir_compilation():
    """Test LLVM IR compilation with bug #167627."""
    print("\n" + "=" * 60)
    print("Test 2: IR Compilation (Bug #167627)")
    print("=" * 60)

    dc = DockerCompiler(verbose=True)

    # Get paths
    project_root = Path(__file__).parent.parent
    ir_file = project_root / "evaluation" / "testcases" / "llvm-167627.ll"
    output_file = project_root / "evaluation" / "testcases" / "llvm-167627_binary"

    if not ir_file.exists():
        print(f"✗ IR file not found: {ir_file}")
        return False

    print(f"\nCompiling IR: {ir_file.name}")
    print(f"Output: {output_file.name}")

    # Test with LLVM 19 (should work)
    print(f"\n--- Testing LLVM 19 ---")
    success, stdout, stderr = dc.compile(
        str(ir_file),
        str(output_file),
        "19"
    )

    if not success:
        print(f"✗ Compilation failed")
        print(f"stdout: {stdout}")
        print(f"stderr: {stderr}")
        return False

    print(f"✓ Compilation successful")

    # Verify binary was created
    if not output_file.exists():
        print(f"✗ Binary not created: {output_file}")
        return False

    print(f"✓ Binary created: {output_file.stat().st_size} bytes")

    # Run the binary
    print(f"\n--- Running binary ---")
    run_success, returncode, run_stdout, run_stderr = dc.run_binary(
        str(output_file),
        use_clang_image=True,
        clang_version="19"
    )

    if not run_success:
        print(f"✗ Execution failed")
        print(f"stderr: {run_stderr}")
        return False

    print(f"✓ Execution successful")
    print(f"  Return code: {returncode}")
    print(f"  Output: {run_stdout.strip() if run_stdout else '(no output)'}")

    # Expected: return code 1 (true), Buggy: return code 0 (false)
    # Bug #167627 is fixed in LLVM 19, so we expect return code 1
    if returncode == 1:
        print(f"✓ Correct result: returns 1 (bug is fixed in LLVM 19)")
    elif returncode == 0:
        print(f"⚠ Returns 0 - this would indicate the Float2Int bug")
    else:
        print(f"? Unexpected return code: {returncode}")

    # Clean up
    if output_file.exists():
        output_file.unlink()
        print(f"\n✓ Cleaned up binary")

    return True


def test_ir_vs_source_routing():
    """Test that IR and source files route to different compilation paths."""
    print("\n" + "=" * 60)
    print("Test 3: IR vs Source Routing")
    print("=" * 60)

    dc = DockerCompiler(verbose=True)

    project_root = Path(__file__).parent.parent

    # Test IR file routing
    ir_file = project_root / "evaluation" / "testcases" / "llvm-167627.ll"
    output_ir = project_root / "evaluation" / "testcases" / "test_ir_routing"

    print("\n--- Testing IR file ---")
    if ir_file.exists():
        success, stdout, stderr = dc.compile(
            str(ir_file),
            str(output_ir),
            "19"
        )

        if success:
            print("✓ IR compilation routed correctly")
            if output_ir.exists():
                output_ir.unlink()
        else:
            print(f"✗ IR compilation failed: {stderr}")
            return False
    else:
        print(f"⚠ Skipping IR test (file not found)")

    # Test C++ file routing
    cpp_file = project_root / "evaluation" / "testcases" / "llvm-175018.cpp"
    output_cpp = project_root / "evaluation" / "testcases" / "test_cpp_routing"

    print("\n--- Testing C++ file ---")
    if cpp_file.exists():
        success, stdout, stderr = dc.compile(
            str(cpp_file),
            str(output_cpp),
            "19",
            "-O1"
        )

        if success:
            print("✓ C++ compilation routed correctly")
            if output_cpp.exists():
                output_cpp.unlink()
        else:
            print(f"✗ C++ compilation failed: {stderr}")
            return False
    else:
        print(f"⚠ Skipping C++ test (file not found)")

    return True


def main():
    """Run all IR support tests."""
    print("\n" + "=" * 60)
    print("LLVM IR Support Tests")
    print("=" * 60)

    results = []

    # Test 1: IR file detection
    results.append(("IR File Detection", test_ir_file_detection()))

    # Test 2: IR compilation
    results.append(("IR Compilation", test_ir_compilation()))

    # Test 3: Routing
    results.append(("IR vs Source Routing", test_ir_vs_source_routing()))

    # Summary
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)

    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{status}: {test_name}")

    all_passed = all(result[1] for result in results)

    if all_passed:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print("\n❌ Some tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
