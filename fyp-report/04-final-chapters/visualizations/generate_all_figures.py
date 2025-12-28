#!/usr/bin/env python3
"""
Master Script: Generate All Chapter 4 Figures
Runs all visualization scripts and generates a comprehensive report
"""

import subprocess
import sys
import os
from datetime import datetime

print("=" * 70)
print("SWARMGUARD THESIS - CHAPTER 4 FIGURE GENERATION")
print("=" * 70)
print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()

# Check dependencies
print("Checking dependencies...")
required_packages = ['matplotlib', 'numpy', 'seaborn']
missing_packages = []

for package in required_packages:
    try:
        __import__(package)
        print(f"  ✓ {package}")
    except ImportError:
        print(f"  ✗ {package} (MISSING)")
        missing_packages.append(package)

if missing_packages:
    print("\nERROR: Missing required packages!")
    print(f"Install with: pip install {' '.join(missing_packages)}")
    sys.exit(1)

print("\nAll dependencies satisfied!\n")
print("=" * 70)

# Scripts to run
scripts = [
    {
        'name': 'MTTR Comparison Visualizations',
        'file': 'mttr_comparison.py',
        'figures': 5,
        'description': 'MTTR analysis, distributions, and downtime metrics'
    },
    {
        'name': 'Scaling Timeline Visualizations',
        'file': 'scaling_timeline.py',
        'figures': 3,
        'description': 'Dynamic scaling behavior and efficiency metrics'
    },
    {
        'name': 'Resource Overhead Visualizations',
        'file': 'resource_overhead.py',
        'figures': 5,
        'description': 'Memory, CPU, network overhead and cost-benefit analysis'
    }
]

# Run each script
total_figures = 0
successful_scripts = 0
failed_scripts = []

for i, script in enumerate(scripts, 1):
    print(f"\n[{i}/{len(scripts)}] Generating: {script['name']}")
    print(f"    Description: {script['description']}")
    print(f"    Expected figures: {script['figures']}")
    print()

    try:
        # Run the script
        result = subprocess.run(
            [sys.executable, script['file']],
            capture_output=True,
            text=True,
            check=True
        )

        # Print script output
        print(result.stdout)

        total_figures += script['figures']
        successful_scripts += 1
        print(f"    ✓ SUCCESS: {script['figures']} figures generated")

    except subprocess.CalledProcessError as e:
        print(f"    ✗ FAILED: Error running {script['file']}")
        print(f"    Error output:\n{e.stderr}")
        failed_scripts.append(script['name'])

    print("-" * 70)

# Summary
print("\n" + "=" * 70)
print("GENERATION COMPLETE")
print("=" * 70)
print(f"Finished: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print()
print(f"Scripts run:        {len(scripts)}")
print(f"Successful:         {successful_scripts}")
print(f"Failed:             {len(failed_scripts)}")
print(f"Total figures:      {total_figures}")
print()

if failed_scripts:
    print("FAILED SCRIPTS:")
    for script in failed_scripts:
        print(f"  ✗ {script}")
    print()
    sys.exit(1)

# List all generated files
print("GENERATED FILES:")
print()

figure_files = sorted([f for f in os.listdir('.') if f.startswith('figure_4_')])

png_files = [f for f in figure_files if f.endswith('.png')]
pdf_files = [f for f in figure_files if f.endswith('.pdf')]

print(f"PNG files ({len(png_files)}):")
for f in png_files:
    size = os.path.getsize(f) / 1024  # KB
    print(f"  • {f:50s} ({size:6.1f} KB)")

print()
print(f"PDF files ({len(pdf_files)}):")
for f in pdf_files:
    size = os.path.getsize(f) / 1024  # KB
    print(f"  • {f:50s} ({size:6.1f} KB)")

print()
print("=" * 70)
print("ALL FIGURES GENERATED SUCCESSFULLY!")
print("=" * 70)
print()
print("Next steps:")
print("  1. Review the generated PNG files")
print("  2. Use PDF files for LaTeX inclusion")
print("  3. Update chapter4_latex_IMPROVED.tex with \\includegraphics commands")
print()
print("Example LaTeX usage:")
print("  \\begin{figure}[htbp]")
print("    \\centering")
print("    \\includegraphics[width=0.9\\textwidth]{figure_4_1_mttr_comparison.pdf}")
print("    \\caption{MTTR Comparison: Baseline vs SwarmGuard Scenarios}")
print("    \\label{fig:mttr_comparison}")
print("  \\end{figure}")
print()
print("=" * 70)
