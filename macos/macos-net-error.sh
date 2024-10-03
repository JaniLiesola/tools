# This script restarts the Cisco Secure Client VPN service agent on macOS.
# It uses the `launchctl kickstart` command with the `-k` option to forcefully 
# restart the specified service, which is identified by its service label 
# `system/com.cisco.secureclient.vpn.service.agent`.
# 
# Usage:
#   sudo ./macos-net-error.sh
#
# Note:
#   - This script requires superuser privileges to execute.
#   - The `launchctl kickstart` command is only available on macOS 10.10 and later.
#

# Restart the Cisco Secure Client VPN service agent.
sudo launchctl kickstart -k system/com.cisco.secureclient.vpn.service.agent

# Restart the mDNSResponder service to flush the DNS cache.
sudo killall -HUP mDNSResponder


