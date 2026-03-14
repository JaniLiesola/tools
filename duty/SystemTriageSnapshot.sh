#!/bin/bash

# Print AI analysis instructions first
cat << 'EOF'
### AI ANALYSIS CONTEXT - DO NOT IGNORE ###
Role: Senior Infrastructure Architect / Senior Technical Lead.
Task: Analyze the following diagnostic output from a critical server environment.
Instructions: Provide a concise, high-level technical summary. Identify root causes or anomalies (resource exhaustion, service failures, or specific error codes). Skip basic explanations; focus on advanced troubleshooting steps, performance bottlenecks, and architectural impact.
###########################################

EOF

# Color codes
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verifies OS and core command availability before deeper checks.
print_compatibility_check() {
	echo -e "${YELLOW}--- COMPATIBILITY CHECK ---${NC}"

	if [[ "$(uname -s)" != "Linux" ]]; then
		echo "Unsupported OS: $(uname -s). This script is intended for Linux hosts."
		return
	fi

	# Commands used by the script for diagnostics.
	local required_cmds=(hostname uname uptime ps free df ss ls journalctl)
	local missing=()

	for cmd in "${required_cmds[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing+=("$cmd")
		fi
	done

	if command -v systemctl >/dev/null 2>&1; then
		echo "systemd detected: yes"
	else
		echo "systemd detected: no (failed unit section may be empty)"
	fi

	if [[ -r /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		echo "Distribution: ${PRETTY_NAME:-Unknown}"
	fi

	if [[ ${#missing[@]} -eq 0 ]]; then
		echo "Required commands: OK"
	else
		echo "Missing commands: ${missing[*]}"
	fi
	echo ""
}

# Shows recently installed package updates from the distro-specific history source.
print_latest_updates() {
	echo -e "${YELLOW}--- LATEST INSTALLED UPDATES ---${NC}"

	if [[ -f /var/log/dpkg.log ]] || ls /var/log/dpkg.log* >/dev/null 2>&1; then
		echo "Source: dpkg logs (Debian/Ubuntu)"
		zgrep -hE " (install|upgrade) " /var/log/dpkg.log* 2>/dev/null | tail -n 15
		echo ""
		return
	fi

	if [[ -f /var/log/pacman.log ]]; then
		echo "Source: pacman log (Arch)"
		grep -E "\[ALPM\] (upgraded|installed)" /var/log/pacman.log | tail -n 15
		echo ""
		return
	fi

	if command -v rpm >/dev/null 2>&1; then
		echo "Source: rpm database (RHEL/SUSE family)"
		rpm -qa --last | head -n 15
		echo ""
		return
	fi

	echo "Could not determine package update history source on this system."
	echo ""
}

# Summarizes pending updates with distro-aware commands.
print_pending_update_status() {
	echo -e "${YELLOW}--- PENDING UPDATE STATUS ---${NC}"

	if command -v apt >/dev/null 2>&1; then
		echo "Source: apt (Debian/Ubuntu family)"
		local upgradable
		upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2)
		local count
		count=$(printf '%s\n' "$upgradable" | sed '/^\s*$/d' | wc -l)
		echo "Pending updates: $count"
		printf '%s\n' "$upgradable" | sed '/^\s*$/d' | head -n 15

		local sec_count
		sec_count=$(printf '%s\n' "$upgradable" | grep -ci security || true)
		echo "Potential security updates: $sec_count"
		echo ""
		return
	fi

	if command -v dnf >/dev/null 2>&1; then
		echo "Source: dnf (RHEL/Rocky/Alma/Fedora family)"
		local dnf_output
		dnf_output=$(dnf -q check-update 2>/dev/null || true)
		printf '%s\n' "$dnf_output" | sed '/^\s*$/d' | head -n 20
		if command -v dnf >/dev/null 2>&1; then
			echo "Security update summary:"
			dnf -q updateinfo list security 2>/dev/null | head -n 15
		fi
		echo ""
		return
	fi

	if command -v yum >/dev/null 2>&1; then
		echo "Source: yum (legacy RHEL family)"
		yum -q check-update 2>/dev/null | head -n 20 || true
		echo ""
		return
	fi

	if command -v zypper >/dev/null 2>&1; then
		echo "Source: zypper (SUSE family)"
		zypper --non-interactive list-updates 2>/dev/null | head -n 20
		echo ""
		return
	fi

	if command -v checkupdates >/dev/null 2>&1; then
		echo "Source: checkupdates (Arch family)"
		checkupdates 2>/dev/null | head -n 20
		echo ""
		return
	fi

	echo "Pending update check is not implemented for this distribution/tooling."
	echo ""
}

# Detects whether the host likely needs a reboot after updates.
print_reboot_requirement() {
	echo -e "${YELLOW}--- REBOOT REQUIREMENT ---${NC}"

	if [[ -f /var/run/reboot-required ]]; then
		echo "Reboot required: yes"
		if [[ -f /var/run/reboot-required.pkgs ]]; then
			echo "Packages requiring reboot:"
			head -n 20 /var/run/reboot-required.pkgs
		fi
		echo ""
		return
	fi

	if command -v needs-restarting >/dev/null 2>&1; then
		if needs-restarting -r >/dev/null 2>&1; then
			echo "Reboot required: no"
		else
			echo "Reboot required: yes (needs-restarting reported requirement)"
		fi
		echo ""
		return
	fi

	echo "Reboot required: unknown (no reboot indicator available)"
	echo ""
}

# Displays recent successful and failed login activity.
print_recent_logins() {
	echo -e "${YELLOW}--- RECENT LOGIN ACTIVITY ---${NC}"

	if command -v last >/dev/null 2>&1; then
		echo "Recent successful logins (last):"
		last -n 10 -a 2>/dev/null
	else
		echo "last command not available."
	fi

	echo ""
	if command -v lastb >/dev/null 2>&1; then
		echo "Recent failed logins (lastb):"
		lastb -n 10 -a 2>/dev/null
	else
		echo "lastb command not available."
	fi

	echo ""
	if command -v journalctl >/dev/null 2>&1; then
		echo "Recent SSH authentication failures (journalctl, last 24h):"
		journalctl --since "24 hours ago" -u ssh -u sshd --no-pager 2>/dev/null |
			grep -Ei "failed|invalid user|authentication failure" |
			tail -n 10
	fi
	echo ""
}

# Start with environment/tooling validation.
print_compatibility_check

# Core runtime health snapshot sections.
echo -e "${YELLOW}--- SYSTEM SNAPSHOT ---${NC}"
echo "Hostname: $(hostname) | Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""
echo -e "${YELLOW}--- CPU & LOAD (Top 5) ---${NC}"
ps -eo pcpu,pmem,user,args --sort=-pcpu | head -6
echo ""
echo -e "${YELLOW}--- MEMORY USAGE ---${NC}"
free -h
echo ""
echo -e "${YELLOW}--- STORAGE & MOUNT POINTS ---${NC}"
df -hT | grep -E '^/dev/|Filesystem'
echo ""
echo -e "${YELLOW}--- NETWORK: LISTENING PORTS ---${NC}"
ss -tulpn | grep LISTEN | head -n 15
echo ""
echo -e "${YELLOW}--- LOG FRESHNESS (Last modified in /var/log) ---${NC}"
ls -lt /var/log | head -n 10
echo ""
echo -e "${YELLOW}--- FAILED SYSTEMD UNITS ---${NC}"
if command -v systemctl >/dev/null 2>&1; then
	systemctl --failed --no-legend
else
	echo "systemctl not available on this host, skipping section."
fi
echo ""
echo -e "${YELLOW}--- CRITICAL LOGS (Journalctl -p 3) ---${NC}"
if command -v journalctl >/dev/null 2>&1; then
	journalctl -p 3 -n 15 --no-pager
else
	echo "journalctl not available on this host, skipping section."
fi
echo ""

# Update and access-focused triage sections.
print_latest_updates
print_pending_update_status
print_reboot_requirement
print_recent_logins