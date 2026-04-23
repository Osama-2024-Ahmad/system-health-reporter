# 🖥️ System Health & Status Reporter

[![ShellCheck](https://github.com/Osama-2024-Ahmad/system-health-reporter/actions/workflows/ci.yml/badge.svg)](https://github.com/Osama-2024-Ahmad/system-health-reporter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)

A production-ready Bash script that collects CPU, memory, disk, network, and process metrics, evaluates configurable thresholds, and outputs structured reports in **text** or **JSON** format. Designed for cron jobs, monitoring dashboards, or manual diagnostics.

> ✅ Exit codes follow Nagios/Icinga convention: `0=OK`, `1=WARNING`, `2=CRITICAL`

---

## ✨ Features

- 📊 **Multi-format output**: Human-readable text or machine-parseable JSON
- 🎯 **Threshold-based alerting**: Configurable warnings for disk, memory, and CPU load
- 🔒 **Safe by design**: `set -euo pipefail`, explicit error handling, `stderr` logging
- 🌍 **Locale-independent**: Forces `LC_ALL=C` to avoid decimal separator bugs
- 🧹 **Clean dependencies**: Uses only standard Linux utilities (`awk`, `df`, `free`, `ps`, `ip`)
- 🔄 **Cron-friendly**: Structured output to `stdout`, logs to `stderr`, meaningful exit codes

---

## 🚀 Quick Start

### Requirements

- Bash 4.0+
- Standard Linux utilities: `awk`, `df`, `free`, `ps`, `ip`, `nproc`, `numfmt`
- Optional: `jq` for pretty-printing JSON output

### Installation & Running

```bash
# Clone the repository
git clone https://github.com/Osama-2024-Ahmad/system-health-reporter.git
cd system-health-reporter

# Make the script executable
chmod +x system_health_reporter.sh

# Generate a human-readable text report
./system_health_reporter.sh

# Generate a JSON report and format with jq
./system_health_reporter.sh --format json | jq .

# Show configured thresholds without evaluation (dry-run)
./system_health_reporter.sh --dry-run

# Check the exit code (useful for cron/monitoring)
./system_health_reporter.sh >/dev/null 2>&1
echo $?  # 0=OK, 1=WARNING, 2=CRITICAL


