"""
Docker Compiler Wrapper for Version Bisection

Provides Docker-based compilation and testing for LLVM versions not installed locally.
Uses pre-built silkeh/clang images from Docker Hub.

Supported versions: 14, 15, 16, 17, 18, 19, 20, 21
"""

import subprocess
import os
import tempfile
import shutil
from pathlib import Path
from typing import Optional, Tuple


class DockerCompiler:
    """Wrapper for compiling and testing with LLVM in Docker containers."""

    # Pre-built LLVM Docker images (silkeh/clang)
    # These are official LLVM builds, ~200MB each
    DOCKER_IMAGE_PREFIX = "silkeh/clang"

    # Supported major versions
    SUPPORTED_VERSIONS = ["14", "15", "16", "17", "18", "19", "20", "21"]

    # C++ file extensions
    CPP_EXTENSIONS = {'.cpp', '.cxx', '.cc', '.C', '.CPP', '.c++', '.cp'}
    CPP_HEADER_EXTENSIONS = {'.hpp', '.hxx', '.h++', '.hh', '.H'}

    def __init__(self, verbose: bool = False):
        """
        Initialize Docker compiler.

        Args:
            verbose: Print debug information
        """
        self.verbose = verbose
        self._check_docker_available()

    def _log(self, msg: str):
        """Print log message if verbose enabled."""
        if self.verbose:
            print(f"[DockerCompiler] {msg}")

    def _check_docker_available(self) -> bool:
        """Check if Docker is installed and running."""
        try:
            result = subprocess.run(
                ["docker", "version"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False

    def get_image_name(self, version: str) -> str:
        """
        Get Docker image name for LLVM version.

        Args:
            version: LLVM version (e.g., "17", "17.0.3")

        Returns:
            Docker image name (e.g., "silkeh/clang:17")
        """
        # Extract major version (17.0.3 -> 17)
        major_version = version.split('.')[0]
        return f"{self.DOCKER_IMAGE_PREFIX}:{major_version}"

    def pull_image(self, version: str) -> bool:
        """
        Pull Docker image for LLVM version.

        Args:
            version: LLVM version

        Returns:
            True if successful, False otherwise
        """
        image = self.get_image_name(version)
        self._log(f"Pulling Docker image: {image}")

        try:
            result = subprocess.run(
                ["docker", "pull", image],
                capture_output=True,
                timeout=300  # 5 minutes timeout for download
            )

            if result.returncode == 0:
                self._log(f"Successfully pulled {image}")
                return True
            else:
                self._log(f"Failed to pull {image}: {result.stderr.decode()}")
                return False

        except subprocess.TimeoutExpired:
            self._log(f"Timeout pulling {image}")
            return False
        except Exception as e:
            self._log(f"Error pulling {image}: {e}")
            return False

    def check_image_available(self, version: str) -> bool:
        """
        Check if Docker image is available locally.

        Args:
            version: LLVM version

        Returns:
            True if image exists locally
        """
        image = self.get_image_name(version)

        try:
            result = subprocess.run(
                ["docker", "image", "inspect", image],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except:
            return False

    def _is_cpp_file(self, source_file: str) -> bool:
        """
        Check if source file is C++ based on extension.

        Args:
            source_file: Path to source file

        Returns:
            True if C++ file, False if C file
        """
        suffix = Path(source_file).suffix
        return suffix in self.CPP_EXTENSIONS or suffix in self.CPP_HEADER_EXTENSIONS

    def _detect_cpp_standard(self, source_file: str) -> Optional[str]:
        """
        Detect required C++ standard from source code patterns.

        Args:
            source_file: Path to source file

        Returns:
            C++ standard flag (e.g., "-std=c++20") or None for default
        """
        try:
            with open(source_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            # C++20 indicators
            cpp20_patterns = [
                'std::optional', 'std::span', 'concept ', 'requires ',
                'consteval ', 'std::format', 'co_await', 'co_yield',
                '<ranges>', '<concepts>', '<coroutine>', 'std::jthread'
            ]
            if any(pattern in content for pattern in cpp20_patterns):
                return '-std=c++20'

            # C++17 indicators
            cpp17_patterns = [
                'std::variant', 'std::filesystem', 'if constexpr',
                'std::string_view', 'std::optional', 'std::any',
                '<filesystem>', 'fold expression', 'structured binding'
            ]
            if any(pattern in content for pattern in cpp17_patterns):
                return '-std=c++17'

            # C++14 indicators
            cpp14_patterns = [
                'std::make_unique', 'auto ', '[[deprecated]]',
                'std::integer_sequence', 'constexpr '
            ]
            if any(pattern in content for pattern in cpp14_patterns):
                return '-std=c++14'

            # Default to C++11 for C++ files
            return '-std=c++11'

        except Exception as e:
            self._log(f"Warning: Could not detect C++ standard: {e}")
            return '-std=c++11'  # Safe default

    def compile(
        self,
        source_file: str,
        output_file: str,
        version: str,
        optimization_level: str = "-O2",
        extra_flags: Optional[list] = None
    ) -> Tuple[bool, str, str]:
        """
        Compile source file using Docker container.

        Args:
            source_file: Path to source file
            output_file: Path to output binary
            version: LLVM version to use
            optimization_level: Optimization level (e.g., "-O2")
            extra_flags: Additional compiler flags

        Returns:
            Tuple of (success, stdout, stderr)
        """
        # Ensure image is available
        if not self.check_image_available(version):
            self._log(f"Image not available, pulling...")
            if not self.pull_image(version):
                return (False, "", f"Failed to pull Docker image for version {version}")

        # Get absolute paths
        source_path = Path(source_file).resolve()
        output_path = Path(output_file).resolve()

        # Get parent directories for mounting
        source_dir = source_path.parent
        output_dir = output_path.parent

        # Container paths
        container_source = f"/src/{source_path.name}"
        container_output = f"/out/{output_path.name}"

        # Detect if C++ file and choose appropriate compiler
        is_cpp = self._is_cpp_file(source_file)
        compiler = "clang++" if is_cpp else "clang"

        # Build compile command
        compile_cmd = [compiler, optimization_level]

        # Add C++ standard flag if C++ file
        if is_cpp:
            cpp_std = self._detect_cpp_standard(source_file)
            if cpp_std:
                compile_cmd.append(cpp_std)
                self._log(f"Detected C++ standard: {cpp_std}")

            # Explicitly use libc++ for consistency across LLVM versions
            # silkeh/clang images use libc++ by default, but be explicit
            compile_cmd.append("-stdlib=libc++")

        if extra_flags:
            compile_cmd.extend(extra_flags)
        compile_cmd.extend([container_source, "-o", container_output])

        # Docker run command
        docker_cmd = [
            "docker", "run",
            "--rm",  # Remove container after execution
            "--platform", "linux/amd64",  # Force amd64 architecture for consistency
            "-v", f"{source_dir}:/src:ro",  # Mount source directory (read-only)
            "-v", f"{output_dir}:/out",      # Mount output directory (read-write)
            self.get_image_name(version),
            *compile_cmd
        ]

        self._log(f"Running: {' '.join(docker_cmd)}")

        try:
            result = subprocess.run(
                docker_cmd,
                capture_output=True,
                text=True,
                timeout=60  # 1 minute timeout for compilation
            )

            success = result.returncode == 0
            return (success, result.stdout, result.stderr)

        except subprocess.TimeoutExpired:
            return (False, "", "Compilation timeout")
        except Exception as e:
            return (False, "", f"Docker compilation error: {e}")

    def run_binary(
        self,
        binary_file: str,
        timeout: int = 10,
        use_clang_image: bool = False,
        clang_version: str = "19"
    ) -> Tuple[bool, int, str, str]:
        """
        Run binary inside Docker container.

        Args:
            binary_file: Path to binary
            timeout: Execution timeout in seconds
            use_clang_image: Use silkeh/clang image instead of ubuntu (for C++ binaries needing libc++)
            clang_version: LLVM version to use if use_clang_image=True (default: 19)

        Returns:
            Tuple of (success, returncode, stdout, stderr)
        """
        # Get absolute path
        binary_path = Path(binary_file).resolve()
        binary_dir = binary_path.parent

        # Container path
        container_binary = f"/bin_dir/{binary_path.name}"

        # Choose Docker image based on whether C++ runtime is needed
        if use_clang_image:
            image = self.get_image_name(clang_version)
        else:
            image = "ubuntu:22.04"  # Use minimal Ubuntu for C binaries

        # Docker run command
        docker_cmd = [
            "docker", "run",
            "--rm",
            "--platform", "linux/amd64",  # Force amd64 to match compilation architecture
            "-v", f"{binary_dir}:/bin_dir",
            image,
            container_binary
        ]

        self._log(f"Running binary: {' '.join(docker_cmd)}")

        try:
            result = subprocess.run(
                docker_cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )

            return (True, result.returncode, result.stdout, result.stderr)

        except subprocess.TimeoutExpired:
            return (False, -1, "", "Execution timeout")
        except Exception as e:
            return (False, -1, "", f"Execution error: {e}")

    def compile_and_test(
        self,
        source_file: str,
        version: str,
        test_func,
        optimization_level: str = "-O2",
        extra_flags: Optional[list] = None
    ) -> Tuple[bool, str]:
        """
        Compile source file and run test function.

        Args:
            source_file: Path to source file
            version: LLVM version to use
            test_func: Test function(binary_path) -> bool (returns True if test passes)
            optimization_level: Optimization level
            extra_flags: Additional compiler flags

        Returns:
            Tuple of (test_passed, error_message)
        """
        # Create temporary output file
        with tempfile.NamedTemporaryFile(delete=False, suffix='_test_binary') as tmp:
            output_file = tmp.name

        try:
            # Compile with Docker
            success, stdout, stderr = self.compile(
                source_file,
                output_file,
                version,
                optimization_level,
                extra_flags
            )

            if not success:
                return (False, f"Compilation failed: {stderr}")

            # Make binary executable
            os.chmod(output_file, 0o755)

            # Run test function
            try:
                test_passed = test_func(output_file)
                return (test_passed, "")
            except Exception as e:
                return (False, f"Test execution failed: {e}")

        finally:
            # Cleanup temporary file
            if os.path.exists(output_file):
                os.remove(output_file)

    def pull_all_versions(self, versions: Optional[list] = None) -> dict:
        """
        Pull all Docker images for specified versions.

        Args:
            versions: List of versions to pull (default: all supported)

        Returns:
            Dict mapping version -> success status
        """
        if versions is None:
            versions = self.SUPPORTED_VERSIONS

        results = {}
        for version in versions:
            print(f"Pulling LLVM {version}...")
            success = self.pull_image(version)
            results[version] = success

            if success:
                print(f"  ✅ LLVM {version} ready")
            else:
                print(f"  ❌ LLVM {version} failed")

        return results
