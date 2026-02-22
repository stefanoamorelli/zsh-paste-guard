# paste-guard Makefile
# Usage: make [target]

INSTALL_PATH := $(HOME)/.paste-guard.zsh
ZSHRC        := $(HOME)/.zshrc
SOURCE_LINE  := source ~/.paste-guard.zsh

.PHONY: help install uninstall test lint clean

# Default target — print available commands
help:
	@echo ""
	@echo "  paste-guard"
	@echo "  ==========="
	@echo ""
	@echo "  make install     Copy plugin to ~/.paste-guard.zsh and source in ~/.zshrc"
	@echo "  make uninstall   Remove plugin and source line from ~/.zshrc"
	@echo "  make test        Run the test suite"
	@echo "  make lint        Run shellcheck (if installed)"
	@echo "  make clean       No-op placeholder"
	@echo ""

# Install the plugin
install:
	@cp paste-guard.zsh "$(INSTALL_PATH)"
	@echo "Copied paste-guard.zsh -> $(INSTALL_PATH)"
	@if [ ! -f "$(ZSHRC)" ]; then \
		touch "$(ZSHRC)"; \
		echo "Created $(ZSHRC)"; \
	fi
	@if grep -qF '$(SOURCE_LINE)' "$(ZSHRC)" 2>/dev/null; then \
		echo "Already sourced in $(ZSHRC) -- skipping."; \
	else \
		echo "" >> "$(ZSHRC)"; \
		echo "# paste-guard: confirm before running pasted commands" >> "$(ZSHRC)"; \
		echo '$(SOURCE_LINE)' >> "$(ZSHRC)"; \
		echo "Added source line to $(ZSHRC)"; \
	fi
	@echo "Done. Open a new terminal window to activate."

# Uninstall the plugin
uninstall:
	@if [ -f "$(INSTALL_PATH)" ]; then \
		rm "$(INSTALL_PATH)"; \
		echo "Removed $(INSTALL_PATH)"; \
	else \
		echo "$(INSTALL_PATH) not found -- skipping."; \
	fi
	@if [ -f "$(ZSHRC)" ]; then \
		sed -i '' '/^# paste-guard: confirm before running pasted commands$$/d' "$(ZSHRC)"; \
		sed -i '' '/^source ~\/\.paste-guard\.zsh$$/d' "$(ZSHRC)"; \
		echo "Removed paste-guard lines from $(ZSHRC)"; \
	fi
	@echo "Done. Open a new terminal window to complete removal."

# Run tests
test:
	@zsh tests/test_paste_guard.zsh

# Lint with shellcheck (optional dependency)
lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck paste-guard.zsh; \
		echo "shellcheck passed."; \
	else \
		echo "shellcheck is not installed. Install it with: brew install shellcheck"; \
	fi

# Placeholder for future cleanup tasks
clean:
	@echo "Nothing to clean."
