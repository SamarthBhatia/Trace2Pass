"""
Report Generator

Generates thesis-ready evaluation reports with tables, charts, and analysis.
"""

import csv
from pathlib import Path
from typing import Dict
from datetime import datetime


class ReportGenerator:
    """Generates evaluation reports in multiple formats."""

    def __init__(self, aggregated_results: Dict, base_dir: Path):
        """
        Initialize report generator.

        Args:
            aggregated_results: Aggregated statistics from ResultsAggregator
            base_dir: Base directory for saving reports
        """
        self.results = aggregated_results
        self.base_dir = Path(base_dir)
        self.reports_dir = self.base_dir / "reports"
        self.charts_dir = self.reports_dir / "charts"
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        self.charts_dir.mkdir(parents=True, exist_ok=True)

    def generate_markdown(self) -> str:
        """Generate comprehensive markdown report."""
        report_path = self.reports_dir / "evaluation_report.md"

        overall = self.results['overall']
        by_compiler = self.results['by_compiler']
        by_pass = self.results['by_pass']
        by_verdict = self.results['by_verdict']
        failures = self.results['failures']
        misdiagnoses = self.results['misdiagnoses']

        report = []

        # Header
        report.append("# Trace2Pass Evaluation Report")
        report.append(f"\n**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"**Total Bugs Evaluated**: {overall['total_bugs']}")
        report.append("\n---\n")

        # Executive Summary
        report.append("## Executive Summary\n")
        report.append(f"- **Detection Rate**: {overall['detection_rate']:.1%} ({overall['detected_count']}/{overall['total_bugs']} bugs)")
        report.append(f"- **Diagnosis Accuracy**: {overall['diagnosis_accuracy']:.1%} ({overall['correct_diagnoses']}/{overall['detected_count']} detected bugs)")
        report.append(f"- **Average Time to Diagnosis**: {overall['avg_time_to_diagnosis']:.2f} seconds")
        report.append(f"- **False Positive Rate**: {overall['false_positive_rate']:.1%} ({overall['false_positive_count']}/{overall['total_bugs']} bugs)")
        report.append("\n")

        # Key Findings
        report.append("### Key Findings\n")

        if overall['detection_rate'] >= 0.70:
            report.append(f"✅ **Strong Detection**: {overall['detection_rate']:.1%} detection rate exceeds 70% target")
        else:
            report.append(f"⚠️  **Detection Below Target**: {overall['detection_rate']:.1%} detection rate below 70% target")

        if overall['diagnosis_accuracy'] >= 0.60:
            report.append(f"✅ **Good Diagnosis Accuracy**: {overall['diagnosis_accuracy']:.1%} accuracy exceeds 60% target")
        else:
            report.append(f"⚠️  **Diagnosis Needs Improvement**: {overall['diagnosis_accuracy']:.1%} accuracy below 60% target")

        if overall['avg_time_to_diagnosis'] <= 120:
            report.append(f"✅ **Fast Diagnosis**: Average {overall['avg_time_to_diagnosis']:.1f}s under 2-minute target")
        else:
            report.append(f"⚠️  **Slow Diagnosis**: Average {overall['avg_time_to_diagnosis']:.1f}s exceeds 2-minute target")

        if overall['false_positive_rate'] <= 0.05:
            report.append(f"✅ **Low False Positives**: {overall['false_positive_rate']:.1%} rate under 5% target")
        else:
            report.append(f"⚠️  **High False Positives**: {overall['false_positive_rate']:.1%} rate exceeds 5% target")

        report.append("\n---\n")

        # Verdict Breakdown
        report.append("## Verdict Breakdown\n")
        report.append("| Verdict | Count | Percentage |")
        report.append("|---------|-------|------------|")
        for verdict, count in by_verdict.items():
            pct = (count / overall['total_bugs'] * 100) if overall['total_bugs'] > 0 else 0
            report.append(f"| {verdict} | {count} | {pct:.1f}% |")
        report.append("\n")

        # Compiler Comparison
        report.append("## Results by Compiler\n")
        report.append("| Compiler | Total | Detected | Detection Rate | Correct | Accuracy | Avg Time (s) |")
        report.append("|----------|-------|----------|----------------|---------|----------|--------------|")
        for compiler, stats in by_compiler.items():
            report.append(
                f"| {compiler.upper()} | "
                f"{stats['total']} | "
                f"{stats['detected']} | "
                f"{stats['detection_rate']:.1%} | "
                f"{stats['correct_diagnoses']} | "
                f"{stats['diagnosis_accuracy']:.1%} | "
                f"{stats['avg_time']:.2f} |"
            )
        report.append("\n")

        # Pass-Level Analysis
        report.append("## Results by Optimization Pass\n")
        report.append("Top bug-prone passes with detection and diagnosis results:\n\n")
        report.append("| Pass | Total | Detected | Detection Rate | Correct | Accuracy |")
        report.append("|------|-------|----------|----------------|---------|----------|")

        # Show top 10 passes by bug count
        top_passes = list(by_pass.items())[:10]
        for pass_name, stats in top_passes:
            report.append(
                f"| {pass_name} | "
                f"{stats['total']} | "
                f"{stats['detected']} | "
                f"{stats['detection_rate']:.1%} | "
                f"{stats['correct']} | "
                f"{stats['accuracy']:.1%} |"
            )
        report.append("\n")

        # Timing Analysis
        report.append("## Timing Analysis\n")
        report.append(f"- **Compilation**: {overall['avg_time_compilation']:.2f}s average")
        report.append(f"- **Runtime**: {overall['avg_time_runtime']:.2f}s average")
        report.append(f"- **Diagnosis**: {overall['avg_time_diagnosis']:.2f}s average")
        report.append(f"- **Total**: {overall['avg_time_to_diagnosis']:.2f}s average")
        report.append("\n")

        # Failure Analysis
        if failures:
            report.append("## Failure Analysis\n")
            report.append(f"**{len(failures)} bugs** could not be successfully diagnosed:\n\n")
            report.append("| Bug ID | Compiler | Expected Pass | Verdict | Reason |")
            report.append("|--------|----------|---------------|---------|--------|")
            for failure in failures:
                report.append(
                    f"| {failure['bug_id']} | "
                    f"{failure['compiler'].upper()} | "
                    f"{failure['expected_pass']} | "
                    f"{failure['verdict']} | "
                    f"{failure['reason']} |"
                )
            report.append("\n")
        else:
            report.append("## Failure Analysis\n")
            report.append("✅ No failures - all bugs were successfully processed!\n\n")

        # Misdiagnosis Analysis
        if misdiagnoses:
            report.append("## Misdiagnosis Analysis\n")
            report.append(f"**{len(misdiagnoses)} bugs** were detected but incorrectly diagnosed:\n\n")
            report.append("| Bug ID | Compiler | Expected Pass | Diagnosed Pass | Confidence |")
            report.append("|--------|----------|---------------|----------------|------------|")
            for mis in misdiagnoses:
                report.append(
                    f"| {mis['bug_id']} | "
                    f"{mis['compiler'].upper()} | "
                    f"{mis['expected_pass']} | "
                    f"{mis['diagnosed_pass']} | "
                    f"{mis['confidence']:.0f}% |"
                )
            report.append("\n")
        else:
            report.append("## Misdiagnosis Analysis\n")
            report.append("✅ No misdiagnoses - all detected bugs were correctly diagnosed!\n\n")

        # Validation Against Targets
        report.append("## Validation Against Target Metrics\n")
        report.append("| Metric | Target | Actual | Status |")
        report.append("|--------|--------|--------|--------|")

        targets = [
            ("Detection Rate", "≥70%", f"{overall['detection_rate']:.1%}", overall['detection_rate'] >= 0.70),
            ("Diagnosis Accuracy", "≥60%", f"{overall['diagnosis_accuracy']:.1%}", overall['diagnosis_accuracy'] >= 0.60),
            ("Avg Time to Diagnosis", "≤120s", f"{overall['avg_time_to_diagnosis']:.1f}s", overall['avg_time_to_diagnosis'] <= 120),
            ("False Positive Rate", "≤5%", f"{overall['false_positive_rate']:.1%}", overall['false_positive_rate'] <= 0.05),
        ]

        for metric, target, actual, passed in targets:
            status = "✅ PASS" if passed else "❌ FAIL"
            report.append(f"| {metric} | {target} | {actual} | {status} |")

        report.append("\n")

        # Conclusion
        report.append("## Conclusion\n")
        passed_count = sum(1 for _, _, _, passed in targets if passed)
        report.append(f"**Overall**: {passed_count}/4 target metrics achieved\n\n")

        if passed_count == 4:
            report.append("✅ **Evaluation SUCCESS** - All target metrics met!")
        elif passed_count >= 2:
            report.append("⚠️  **Partial Success** - Some target metrics not met. See analysis above.")
        else:
            report.append("❌ **Evaluation needs improvement** - Most target metrics not met.")

        report.append("\n\n---\n\n")
        report.append("*This report was generated automatically by the Trace2Pass Evaluation Framework*")

        # Write report
        with open(report_path, 'w') as f:
            f.write('\n'.join(report))

        return str(report_path)

    def generate_latex(self) -> str:
        """Generate LaTeX tables for thesis."""
        latex_path = self.reports_dir / "evaluation_tables.tex"

        overall = self.results['overall']
        by_compiler = self.results['by_compiler']
        by_pass = self.results['by_pass']

        latex = []

        # Overall results table
        latex.append("% Overall Evaluation Results")
        latex.append("\\begin{table}[h]")
        latex.append("\\centering")
        latex.append("\\caption{Trace2Pass Evaluation Results on 54 Historical Bugs}")
        latex.append("\\label{tab:eval-overall}")
        latex.append("\\begin{tabular}{lr}")
        latex.append("\\toprule")
        latex.append("\\textbf{Metric} & \\textbf{Value} \\\\")
        latex.append("\\midrule")
        latex.append(f"Total Bugs Evaluated & {overall['total_bugs']} \\\\")
        latex.append(f"Detection Rate & {overall['detection_rate']:.1%} \\\\")
        latex.append(f"Diagnosis Accuracy & {overall['diagnosis_accuracy']:.1%} \\\\")
        latex.append(f"Avg Time to Diagnosis & {overall['avg_time_to_diagnosis']:.2f}s \\\\")
        latex.append(f"False Positive Rate & {overall['false_positive_rate']:.1%} \\\\")
        latex.append("\\bottomrule")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}\n\n")

        # Compiler comparison table
        latex.append("% Results by Compiler")
        latex.append("\\begin{table}[h]")
        latex.append("\\centering")
        latex.append("\\caption{Evaluation Results by Compiler}")
        latex.append("\\label{tab:eval-compiler}")
        latex.append("\\begin{tabular}{lrrrrr}")
        latex.append("\\toprule")
        latex.append("\\textbf{Compiler} & \\textbf{Total} & \\textbf{Detected} & \\textbf{Detection} & \\textbf{Correct} & \\textbf{Accuracy} \\\\")
        latex.append("\\midrule")

        for compiler, stats in by_compiler.items():
            latex.append(
                f"{compiler.upper()} & "
                f"{stats['total']} & "
                f"{stats['detected']} & "
                f"{stats['detection_rate']:.1%} & "
                f"{stats['correct_diagnoses']} & "
                f"{stats['diagnosis_accuracy']:.1%} \\\\"
            )

        latex.append("\\bottomrule")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}\n\n")

        # Top passes table
        latex.append("% Top Bug-Prone Passes")
        latex.append("\\begin{table}[h]")
        latex.append("\\centering")
        latex.append("\\caption{Results for Top Bug-Prone Optimization Passes}")
        latex.append("\\label{tab:eval-passes}")
        latex.append("\\begin{tabular}{lrrrrr}")
        latex.append("\\toprule")
        latex.append("\\textbf{Pass} & \\textbf{Total} & \\textbf{Detected} & \\textbf{Detection} & \\textbf{Correct} & \\textbf{Accuracy} \\\\")
        latex.append("\\midrule")

        # Top 10 passes
        top_passes = list(by_pass.items())[:10]
        for pass_name, stats in top_passes:
            latex.append(
                f"{pass_name} & "
                f"{stats['total']} & "
                f"{stats['detected']} & "
                f"{stats['detection_rate']:.1%} & "
                f"{stats['correct']} & "
                f"{stats['accuracy']:.1%} \\\\"
            )

        latex.append("\\bottomrule")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}\n")

        # Write LaTeX
        with open(latex_path, 'w') as f:
            f.write('\n'.join(latex))

        return str(latex_path)

    def generate_csv(self) -> str:
        """Generate CSV export of detailed results."""
        csv_path = self.reports_dir / "evaluation_data.csv"

        detailed = self.results['detailed_results']

        with open(csv_path, 'w', newline='') as f:
            if not detailed:
                return str(csv_path)

            writer = csv.DictWriter(f, fieldnames=detailed[0].keys())
            writer.writeheader()
            writer.writerows(detailed)

        return str(csv_path)

    def generate_charts(self) -> Dict[str, str]:
        """Generate visualization charts."""
        try:
            import matplotlib.pyplot as plt
            import matplotlib
            matplotlib.use('Agg')  # Use non-interactive backend
        except ImportError:
            print("Warning: matplotlib not available, skipping chart generation")
            return {}

        charts = {}
        overall = self.results['overall']
        by_compiler = self.results['by_compiler']
        by_pass = self.results['by_pass']

        # Chart 1: Overall metrics bar chart
        fig, ax = plt.subplots(figsize=(10, 6))
        metrics = ['Detection\nRate', 'Diagnosis\nAccuracy', 'False Positive\nRate']
        values = [
            overall['detection_rate'] * 100,
            overall['diagnosis_accuracy'] * 100,
            overall['false_positive_rate'] * 100
        ]
        colors = ['#2ecc71' if v >= 60 else '#e74c3c' for v in values]
        ax.bar(metrics, values, color=colors, alpha=0.7)
        ax.set_ylabel('Percentage (%)')
        ax.set_title('Trace2Pass Evaluation Metrics')
        ax.set_ylim(0, 100)
        ax.axhline(y=70, color='r', linestyle='--', label='Detection Target (70%)')
        ax.axhline(y=60, color='b', linestyle='--', label='Accuracy Target (60%)')
        ax.legend()
        plt.tight_layout()
        chart_path = self.charts_dir / "overall_metrics.png"
        plt.savefig(chart_path, dpi=300, bbox_inches='tight')
        plt.close()
        charts['overall_metrics'] = str(chart_path)

        # Chart 2: Compiler comparison
        if by_compiler:
            fig, ax = plt.subplots(figsize=(10, 6))
            compilers = list(by_compiler.keys())
            detection_rates = [by_compiler[c]['detection_rate'] * 100 for c in compilers]
            accuracy_rates = [by_compiler[c]['diagnosis_accuracy'] * 100 for c in compilers]

            x = range(len(compilers))
            width = 0.35

            ax.bar([i - width/2 for i in x], detection_rates, width, label='Detection Rate', alpha=0.7)
            ax.bar([i + width/2 for i in x], accuracy_rates, width, label='Diagnosis Accuracy', alpha=0.7)

            ax.set_ylabel('Percentage (%)')
            ax.set_title('Detection and Diagnosis Rates by Compiler')
            ax.set_xticks(x)
            ax.set_xticklabels([c.upper() for c in compilers])
            ax.legend()
            ax.set_ylim(0, 100)
            plt.tight_layout()
            chart_path = self.charts_dir / "compiler_comparison.png"
            plt.savefig(chart_path, dpi=300, bbox_inches='tight')
            plt.close()
            charts['compiler_comparison'] = str(chart_path)

        # Chart 3: Top passes detection rate
        if by_pass:
            top_passes = list(by_pass.items())[:8]  # Top 8 passes
            fig, ax = plt.subplots(figsize=(12, 6))

            pass_names = [p[0] for p in top_passes]
            detection_rates = [p[1]['detection_rate'] * 100 for p in top_passes]

            ax.barh(pass_names, detection_rates, alpha=0.7, color='#3498db')
            ax.set_xlabel('Detection Rate (%)')
            ax.set_title('Detection Rate by Optimization Pass (Top 8)')
            ax.set_xlim(0, 100)
            ax.axvline(x=70, color='r', linestyle='--', label='Target (70%)')
            ax.legend()
            plt.tight_layout()
            chart_path = self.charts_dir / "pass_detection_rates.png"
            plt.savefig(chart_path, dpi=300, bbox_inches='tight')
            plt.close()
            charts['pass_detection_rates'] = str(chart_path)

        return charts
