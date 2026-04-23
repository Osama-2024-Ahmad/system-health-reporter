#!/usr/bin/env bash
# =============================================================================
# System Health & Status Reporter
# =============================================================================
# Collects CPU, memory, disk, network, and process metrics.
# Evaluates thresholds and exits with appropriate status codes:
#   0 = OK, 1 = WARNING, 2 = CRITICAL
# Designed for cron, monitoring dashboards, or manual diagnostics.
# =============================================================================

# Strict mode: undefined vars fail, pipelines fail on any step, errexit on
# unexpected failures. We handle intentional non-zero exits explicitly.
set -uo pipefail

# Force consistent number formatting across all locales (prevents comma/decimal bugs)
export LC_ALL=C

# =============================================================================
# CONFIGURATION & DEFAULTS
# =============================================================================
# SC2155 fix: Declare and assign separately to avoid masking return values
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly VERSION="1.0.0"

# Thresholds (percentage or multipliers)
readonly DISK_WARN_PCT=85
readonly DISK_CRIT_PCT=95
readonly MEM_WARN_PCT=80
readonly MEM_CRIT_PCT=95
readonly LOAD_WARN_MULTIPLIER=1.5 # cores * multiplier
readonly LOAD_CRIT_MULTIPLIER=2.0

# Output format
FORMAT="text"

# Global severity tracker (0=OK, 1=WARNING, 2=CRITICAL)
OVERALL_STATUS=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Logging functions (write to stderr to avoid polluting stdout/output)
log_info() { printf '[INFO]  %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_warn() { printf '[WARN]  %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
log_error() { printf '[ERROR] %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

# Update global status to the highest severity encountered
update_status() {
	local status_code="$1"
	if ((status_code > OVERALL_STATUS)); then
		OVERALL_STATUS=$status_code
	fi
}

# Basic string escaping for JSON output
json_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\n/\\n/g'
}

# =============================================================================
# METRIC COLLECTORS
# =============================================================================

# Returns: hostname uptime_seconds kernel_version
get_system_info() {
	local uptime_sec
	uptime_sec=$(awk '{print $1}' /proc/uptime 2>/dev/null | cut -d. -f1)
	printf '%s %s %s' "$(hostname)" "$uptime_sec" "$(uname -r)"
}

# Returns: load1 load5 load15 cpu_cores
get_cpu_load() {
	local load1 load5 load15
	read -r load1 load5 load15 _ < <(cat /proc/loadavg)
	local cores
	cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo)
	printf '%s %s %s %s' "$load1" "$load5" "$load15" "$cores"
}

# Returns: total_bytes used_bytes available_bytes usage_pct
get_memory_usage() {
	free -b | awk '/^Mem:/ {
    total=$2; used=$3; avail=$7;
    pct=0; if(total>0) pct=(used/total)*100;
    printf "%d %d %d %.1f\n", total, used, avail, pct
  }'
}

# Returns: mount usage_pct size used avail (one line per filesystem)
get_disk_usage() {
	# -P: POSIX format, -x: exclude pseudo/temporary fs (including efivarfs)
	df -P -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs 2>/dev/null |
		awk 'NR>1 && $5 ~ /^[0-9]+%/ {
      gsub(/%/,"",$5);
      if ($5+0 > 0) printf "%s %d %s %s %s\n", $1, $5, $2, $3, $4
    }' || true
}

# Returns: interface ip_address (one per line)
get_network_interfaces() {
	ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}' || true
}

# Returns: pid cpu% mem% command (top 5 by CPU)
get_top_processes() {
	ps -eo pid,pcpu,pmem,comm --sort=-pcpu 2>/dev/null | head -n 6 || true
}

# =============================================================================
# THRESHOLD EVALUATOR
# =============================================================================
evaluate_thresholds() {
	local cpu_cores load1
	local mem_pct
	local mount disk_pct

	# CPU Load
	read -r _ _ load1 cpu_cores < <(get_cpu_load)
	if awk "BEGIN {exit !($load1 > $cpu_cores * $LOAD_CRIT_MULTIPLIER)}"; then
		update_status 2
	elif awk "BEGIN {exit !($load1 > $cpu_cores * $LOAD_WARN_MULTIPLIER)}"; then
		update_status 1
	fi

	# Memory
	read -r _ _ _ mem_pct < <(get_memory_usage)
	if awk "BEGIN {exit !($mem_pct > $MEM_CRIT_PCT)}"; then
		update_status 2
	elif awk "BEGIN {exit !($mem_pct > $MEM_WARN_PCT)}"; then
		update_status 1
	fi

	# Disk
	while read -r mount disk_pct _ _ _; do
		if ((disk_pct >= DISK_CRIT_PCT)); then
			log_warn "Critical disk usage on $mount: ${disk_pct}%"
			update_status 2
		elif ((disk_pct >= DISK_WARN_PCT)); then
			log_warn "Warning disk usage on $mount: ${disk_pct}%"
			update_status 1
		fi
	done < <(get_disk_usage)
}

# =============================================================================
# REPORT GENERATORS
# =============================================================================

format_text_report() {
	# SC2034 fix: Removed unused variables: sys_info cpu_info mem_info
	local host uptime kernel cores load1 load5 load15
	local mem_total mem_used mem_avail mem_pct

	read -r host uptime kernel <<<"$(get_system_info)"
	read -r load1 load5 load15 cores <<<"$(get_cpu_load)"
	read -r mem_total mem_used mem_avail mem_pct <<<"$(get_memory_usage)"

	# Convert bytes to human-readable
	local mem_hr used_hr avail_hr
	mem_hr=$(numfmt --to=iec-i --suffix=B "$mem_total" 2>/dev/null || echo "${mem_total}B")
	used_hr=$(numfmt --to=iec-i --suffix=B "$mem_used" 2>/dev/null || echo "${mem_used}B")
	avail_hr=$(numfmt --to=iec-i --suffix=B "$mem_avail" 2>/dev/null || echo "${mem_avail}B")

	printf '=== System Health Report ===\n'
	printf 'Host: %s | Kernel: %s | Uptime: %s\n' "$host" "$kernel" "$(echo "$uptime" | awk '{d=$1/86400; h=$1%86400/3600; m=$1%3600/60; s=$1%60; printf "%dd %dh %dm %ds", d, h, m, s}')"
	printf '\n--- CPU ---\n'
	printf 'Cores: %s | Load (1m/5m/15m): %s / %s / %s\n' "$cores" "$load1" "$load5" "$load15"
	printf 'Load per Core: %.2f\n' "$(awk "BEGIN {printf \"%.2f\", $load1/$cores}")"

	printf '\n--- Memory ---\n'
	printf 'Total: %s | Used: %s | Available: %s\n' "$mem_hr" "$used_hr" "$avail_hr"
	printf 'Usage: %.1f%%\n' "$mem_pct"

	printf '\n--- Disk ---\n'
	printf '%-15s %-8s %-10s %-10s %-10s\n' "MOUNT" "USE%" "SIZE" "USED" "AVAIL"
	while read -r mount disk_pct size used avail; do
		printf '%-15s %-8s %-10s %-10s %-10s\n' "$mount" "${disk_pct}%" "$size" "$used" "$avail"
	done < <(get_disk_usage)

	printf '\n--- Network Interfaces ---\n'
	get_network_interfaces | while read -r iface ip; do
		printf '%-10s %s\n' "$iface" "$ip"
	done

	printf '\n--- Top Processes (by CPU) ---\n'
	get_top_processes | head -n 6

	printf '\n--- Status ---\n'
	case $OVERALL_STATUS in
	0) printf 'STATUS: OK\n' ;;
	1) printf 'STATUS: WARNING\n' ;;
	2) printf 'STATUS: CRITICAL\n' ;;
	esac
}

format_json_report() {
	# SC2034 fix: Removed unused variables: sys_info cpu_info mem_info
	local host uptime kernel cores load1 load5 load15
	local mem_total mem_used mem_avail mem_pct

	read -r host uptime kernel <<<"$(get_system_info)"
	read -r load1 load5 load15 cores <<<"$(get_cpu_load)"
	read -r mem_total mem_used mem_avail mem_pct <<<"$(get_memory_usage)"

	# Build disk JSON array
	local disk_json="["
	local first=true
	while read -r mount disk_pct size used avail; do
		if [[ "$first" == true ]]; then first=false; else disk_json+=","; fi
		disk_json+=$(printf '{"mount":"%s","usage_pct":%d,"size":"%s","used":"%s","avail":"%s"}' \
			"$(json_escape "$mount")" "$disk_pct" "$size" "$used" "$avail")
	done < <(get_disk_usage)
	disk_json+="]"

	# Build network JSON array
	local net_json="["
	first=true
	while read -r iface ip; do
		if [[ "$first" == true ]]; then first=false; else net_json+=","; fi
		net_json+=$(printf '{"interface":"%s","ip":"%s"}' "$(json_escape "$iface")" "$(json_escape "$ip")")
	done < <(get_network_interfaces)
	net_json+="]"

	# SC2027 fix: Proper quoting for command substitution in JSON array build
	local proc_json
	proc_json="[$(get_top_processes | tail -n +2 | awk '{printf "%s{\"pid\":\"%s\",\"cpu_pct\":\"%s\",\"mem_pct\":\"%s\",\"cmd\":\"%s\"}", (NR>1?",":""), $1, $2, $3, $4}')]"

	local status_str
	case $OVERALL_STATUS in
	0) status_str="OK" ;;
	1) status_str="WARNING" ;;
	2) status_str="CRITICAL" ;;
	esac

	printf '{
  "timestamp": "%s",
  "host": "%s",
  "kernel": "%s",
  "uptime_seconds": %s,
  "cpu": {
    "cores": %s,
    "load_1m": %s,
    "load_5m": %s,
    "load_15m": %s
  },
  "memory": {
    "total_bytes": %s,
    "used_bytes": %s,
    "available_bytes": %s,
    "usage_pct": %s
  },
  "disk": %s,
  "network": %s,
  "processes": %s,
  "status": "%s"
}\n' \
		"$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
		"$(json_escape "$host")" \
		"$(json_escape "$kernel")" \
		"$uptime" \
		"$cores" "$load1" "$load5" "$load15" \
		"$mem_total" "$mem_used" "$mem_avail" "$mem_pct" \
		"$disk_json" "$net_json" "$proc_json" "$status_str"
}

# =============================================================================
# ARGUMENT PARSER & MAIN
# =============================================================================
usage() {
	cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

System Health & Status Reporter

Options:
  --format FORMAT   Output format: text (default) or json
  -h, --help        Show this help message
  -v, --version     Show version
  --dry-run         Show thresholds and exit without evaluating (for testing)

Exit Codes:
  0 = OK
  1 = WARNING (threshold exceeded)
  2 = CRITICAL (critical threshold exceeded)
EOF
}

main() {
	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--format)
			FORMAT="$2"
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		-v | --version)
			echo "$SCRIPT_NAME $VERSION"
			exit 0
			;;
		--dry-run)
			log_info "Dry-run mode: showing configured thresholds."
			printf "DISK_WARN=%s%% DISK_CRIT=%s%%\n" "$DISK_WARN_PCT" "$DISK_CRIT_PCT"
			printf "MEM_WARN=%s%% MEM_CRIT=%s%%\n" "$MEM_WARN_PCT" "$MEM_CRIT_PCT"
			printf "LOAD_WARN_MULTIPLIER=%s LOAD_CRIT_MULTIPLIER=%s\n" \
				"$LOAD_WARN_MULTIPLIER" "$LOAD_CRIT_MULTIPLIER"
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			usage
			exit 1
			;;
		esac
	done

	# Validate format
	if [[ "$FORMAT" != "text" && "$FORMAT" != "json" ]]; then
		log_error "Unsupported format: $FORMAT. Use 'text' or 'json'."
		exit 1
	fi

	log_info "Collecting system metrics..."
	evaluate_thresholds

	log_info "Generating report in $FORMAT format..."
	case "$FORMAT" in
	text) format_text_report ;;
	json) format_json_report ;;
	esac

	log_info "Report complete. Exit code: $OVERALL_STATUS"
	exit "$OVERALL_STATUS"
}

# Run main
main "$@"
