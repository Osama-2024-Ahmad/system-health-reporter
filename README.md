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

---

## 📸 Output

### 1️⃣ Text Format Output

![Text Output](docs/screenshots/text-output.png)

*Figure 1: Human-readable system health report with CPU, memory, disk, network, and process metrics.*

---

### 2️⃣ JSON Format Output (Example 1)

![JSON Output 1](https://docs/screenshots/json-output1.png)

*Figure 2: Machine-parseable JSON report - ideal for dashboards and automation.*

---

### 3️⃣ JSON Format Output (Example 2)

![JSON Output 2](https://github.com/Osama-2024-Ahmad/system-health-reporter/blob/main/docs/screenshots/json-output2.png)

*Figure 3: Detailed JSON structure with nested objects for disk, network, and processes.*

---

### 4️⃣ Manual Tests

![Manual Tests](https://github.com/Osama-2024-Ahmad/system-health-reporter/blob/main/docs/screenshots/Manual%20Tests.png)

*Figure 4: Verification of exit codes, threshold alerts, and dry-run mode.*

> 💡 **Tip**: If images don't load, ensure the `docs/screenshots/` folder is committed to your repository.

---
