"""
Test Case Manager

Fetches, stores, and manages test cases from historical bug URLs.
Supports both automated scraping and manual test case addition.
"""

import os
import csv
import json
import re
import requests
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from bs4 import BeautifulSoup
from tqdm import tqdm


@dataclass
class TestCase:
    """Represents a single test case for evaluation."""
    bug_id: str
    compiler: str
    source_file: Optional[str]
    expected_pass: str
    optimization_level: str
    status: str  # 'verified', 'failed_fetch', 'compile_error', 'manual'
    url: str
    notes: str


class TestCaseManager:
    """Manages test case fetching and storage."""

    def __init__(self, base_dir: Path):
        self.base_dir = Path(base_dir)
        self.testcases_dir = self.base_dir / "testcases"
        self.testcases_dir.mkdir(parents=True, exist_ok=True)

        # Path to historical bugs dataset
        self.dataset_path = self.base_dir.parent / "historical-bugs" / "bug-dataset.csv"
        self.metadata_path = self.testcases_dir / "metadata.json"

        # Load existing metadata
        self.metadata = self._load_metadata()

    def _load_metadata(self) -> Dict:
        """Load test case metadata from disk."""
        if self.metadata_path.exists():
            with open(self.metadata_path, 'r') as f:
                return json.load(f)
        return {}

    def _save_metadata(self):
        """Save test case metadata to disk."""
        with open(self.metadata_path, 'w') as f:
            json.dump(self.metadata, f, indent=2)

    def _load_bug_dataset(self) -> List[Dict]:
        """Load historical bug dataset from CSV."""
        bugs = []
        with open(self.dataset_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row['Bug ID']:  # Skip empty rows
                    bugs.append(row)
        return bugs

    def _make_bug_id(self, compiler: str, bug_num: str) -> str:
        """Create standardized bug ID."""
        return f"{compiler.lower()}-{bug_num}"

    def _fetch_llvm_test_case(self, url: str) -> Optional[str]:
        """
        Fetch test case from LLVM GitHub issue.

        Looks for code blocks in the issue description and comments.
        """
        try:
            # Extract issue number from URL
            match = re.search(r'/issues/(\d+)', url)
            if not match:
                return None

            # Fetch issue page
            response = requests.get(url, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.text, 'html.parser')

            # Look for code blocks (```c, ```cpp, etc.)
            code_blocks = soup.find_all('pre')
            for block in code_blocks:
                code = block.get_text()
                # Check if it looks like C/C++ code (has main function or includes)
                if 'int main(' in code or '#include' in code:
                    return code

            return None

        except Exception as e:
            print(f"  ⚠️  Failed to fetch from {url}: {e}")
            return None

    def _fetch_gcc_test_case(self, url: str) -> Optional[str]:
        """
        Fetch test case from GCC Bugzilla.

        Looks for attachments or code in description.
        """
        try:
            # For GCC mailing list URLs, we can't easily scrape
            # For Bugzilla URLs, we could scrape but may need authentication
            # For now, return None (manual reproduction needed)
            return None

        except Exception as e:
            print(f"  ⚠️  Failed to fetch from {url}: {e}")
            return None

    def fetch_bug(self, bug_id: str, bug_data: Dict) -> TestCase:
        """Fetch a single test case."""
        compiler = bug_data['Compiler'].lower()
        bug_num = bug_data['Bug ID']
        url = bug_data['URL']
        expected_pass = bug_data['Optimization Pass']
        notes = bug_data['Notes']

        # Check if already fetched
        if bug_id in self.metadata:
            existing = self.metadata[bug_id]
            if existing['status'] == 'verified':
                return TestCase(**existing)

        # Try to fetch test case
        source_code = None
        if compiler == 'llvm':
            source_code = self._fetch_llvm_test_case(url)
        elif compiler == 'gcc':
            source_code = self._fetch_gcc_test_case(url)

        # Save test case if fetched
        if source_code:
            source_file = self.testcases_dir / f"{bug_id}.c"
            with open(source_file, 'w') as f:
                f.write(source_code)

            testcase = TestCase(
                bug_id=bug_id,
                compiler=compiler,
                source_file=str(source_file),
                expected_pass=expected_pass,
                optimization_level="-O2",  # Default, can be overridden
                status='verified',
                url=url,
                notes=notes
            )
        else:
            testcase = TestCase(
                bug_id=bug_id,
                compiler=compiler,
                source_file=None,
                expected_pass=expected_pass,
                optimization_level="-O2",
                status='failed_fetch',
                url=url,
                notes=notes
            )

        # Save metadata
        self.metadata[bug_id] = asdict(testcase)
        self._save_metadata()

        return testcase

    def fetch_all(self) -> Dict:
        """Fetch all test cases from bug dataset."""
        bugs = self._load_bug_dataset()
        results = {
            'total': len(bugs),
            'fetched': 0,
            'cached': 0,
            'failed': 0,
            'total_available': 0
        }

        print(f"\nFetching test cases for {len(bugs)} bugs...")
        for bug_data in tqdm(bugs, desc="Fetching", unit="bug"):
            bug_id = self._make_bug_id(bug_data['Compiler'], bug_data['Bug ID'])

            # Check if already fetched
            if bug_id in self.metadata and self.metadata[bug_id]['status'] == 'verified':
                results['cached'] += 1
                results['total_available'] += 1
                continue

            # Fetch test case
            testcase = self.fetch_bug(bug_id, bug_data)

            if testcase.status == 'verified':
                results['fetched'] += 1
                results['total_available'] += 1
            else:
                results['failed'] += 1

        return results

    def fetch_bugs(self, bug_ids: List[str]) -> Dict:
        """Fetch specific bugs by ID."""
        all_bugs = self._load_bug_dataset()
        bugs_dict = {
            self._make_bug_id(b['Compiler'], b['Bug ID']): b
            for b in all_bugs
        }

        results = {
            'total': len(bug_ids),
            'fetched': 0,
            'cached': 0,
            'failed': 0,
            'total_available': 0
        }

        for bug_id in tqdm(bug_ids, desc="Fetching", unit="bug"):
            if bug_id not in bugs_dict:
                print(f"  ⚠️  Bug {bug_id} not found in dataset")
                results['failed'] += 1
                continue

            # Check if already fetched
            if bug_id in self.metadata and self.metadata[bug_id]['status'] == 'verified':
                results['cached'] += 1
                results['total_available'] += 1
                continue

            # Fetch test case
            testcase = self.fetch_bug(bug_id, bugs_dict[bug_id])

            if testcase.status == 'verified':
                results['fetched'] += 1
                results['total_available'] += 1
            else:
                results['failed'] += 1

        return results

    def fetch_by_compiler(self, compiler: str) -> Dict:
        """Fetch bugs for specific compiler (llvm or gcc)."""
        all_bugs = self._load_bug_dataset()
        compiler_bugs = [b for b in all_bugs if b['Compiler'].lower() == compiler.lower()]

        results = {
            'total': len(compiler_bugs),
            'fetched': 0,
            'cached': 0,
            'failed': 0,
            'total_available': 0
        }

        print(f"\nFetching {compiler.upper()} test cases ({len(compiler_bugs)} bugs)...")
        for bug_data in tqdm(compiler_bugs, desc="Fetching", unit="bug"):
            bug_id = self._make_bug_id(bug_data['Compiler'], bug_data['Bug ID'])

            # Check if already fetched
            if bug_id in self.metadata and self.metadata[bug_id]['status'] == 'verified':
                results['cached'] += 1
                results['total_available'] += 1
                continue

            # Fetch test case
            testcase = self.fetch_bug(bug_id, bug_data)

            if testcase.status == 'verified':
                results['fetched'] += 1
                results['total_available'] += 1
            else:
                results['failed'] += 1

        return results

    def get_available_testcases(self) -> List[TestCase]:
        """Get all successfully fetched test cases."""
        return [
            TestCase(**data)
            for bug_id, data in self.metadata.items()
            if data['status'] == 'verified'
        ]

    def add_manual_testcase(self, bug_id: str, source_file: str, expected_pass: str,
                           compiler: str, optimization_level: str = "-O2") -> TestCase:
        """
        Manually add a test case (for bugs that couldn't be auto-fetched).

        Args:
            bug_id: Bug identifier (e.g., "llvm-64188")
            source_file: Path to source file
            expected_pass: Expected culprit pass
            compiler: Compiler name (llvm or gcc)
            optimization_level: Optimization flag

        Returns:
            TestCase object
        """
        testcase = TestCase(
            bug_id=bug_id,
            compiler=compiler.lower(),
            source_file=source_file,
            expected_pass=expected_pass,
            optimization_level=optimization_level,
            status='manual',
            url='',
            notes='Manually added test case'
        )

        self.metadata[bug_id] = asdict(testcase)
        self._save_metadata()

        return testcase
