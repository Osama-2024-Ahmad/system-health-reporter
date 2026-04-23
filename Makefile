# Makefile for System Health Reporter
# Usage: make [target]
# Targets: help, lint, format, test, run, json, clean

.PHONY: help lint format test run json clean

# Default target
help:
	@echo "🛠️  System Health Reporter - Makefile Targets"
	@echo "=============================================="
	@echo "  make lint    - Run shellcheck on all .sh files"
	@echo "  make format  - Format code with shfmt"
	@echo "  make test    - Run bats tests (if tests/ exists)"
	@echo "  make run     - Execute script with default text output"
	@echo "  make json    - Execute script with JSON output + jq"
	@echo "  make clean   - Remove generated files (*.log, *.json)"
	@echo ""
	@echo "💡 Tip: Use 'make run' or 'make json' to test the script"

# Lint with ShellCheck
lint:
	@echo "🔍 Running ShellCheck..."
	shellcheck system_health_reporter.sh
	@echo "✅ ShellCheck passed"

# Format with shfmt
format:
	@echo "✨ Formatting code with shfmt..."
	shfmt -w system_health_reporter.sh
	@echo "✅ Formatting complete"

# Run Bats tests (if available)
test:
	@echo "🧪 Running tests..."
	@if [ -d "tests" ] && [ "$$(ls tests/*.bats 2>/dev/null)" ]; then \
		bats tests/; \
		echo "✅ All tests passed"; \
	else \
		echo "⚠️  No Bats tests found. Add tests to tests/*.bats to enable automated testing."; \
	fi

# Run script with default text output
run:
	@echo "🚀 Running System Health Reporter..."
	./system_health_reporter.sh

# Run script with JSON output + jq
json:
	@echo "📊 Running with JSON output..."
	./system_health_reporter.sh --format json | jq .

# Clean generated files
clean:
	@echo "🧹 Cleaning..."
	rm -f *.log *.json 2>/dev/null || true
	@echo "✅ Clean complete"
