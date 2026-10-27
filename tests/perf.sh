#!/bin/sh
# Measure the desktop shell at idle, inside a running Foxtail session:
# CPU use over a quiet minute, and memory. Fails if over budget.
#   tests/perf.sh [seconds]
# Budget, on real hardware with a GPU. Software rendering (VMs) keeps every
# surface in RAM: an empty two-window Quickshell config already uses ~390 MB
# there (measured on VirtualBox 7.2), so the memory budget grows by that much.
SECS=${1:-60}
pid=$(pgrep -f "^qs -p .*foxtail/shell" | head -1)
[ -n "$pid" ] || pid=$(pgrep -x qs | head -1)
[ -n "$pid" ] || { echo "the shell (qs) isn't running"; exit 1; }
if tr '\0' '\n' < /proc/$pid/environ | grep -q '^LIBGL_ALWAYS_SOFTWARE=1'; then
    soft=1; echo "(software rendering: VM budget)"
fi
CPU_BUDGET=${CPU_BUDGET:-2.0}                              # % of one core, averaged
RSS_BUDGET=${RSS_BUDGET:-$([ -n "${soft:-}" ] && echo 900 || echo 500)}   # MB
tck=$(getconf CLK_TCK)
t0=$(awk '{print $14 + $15}' /proc/$pid/stat)
sleep "$SECS"
t1=$(awk '{print $14 + $15}' /proc/$pid/stat)
cpu=$(echo "$t0 $t1 $tck $SECS" | awk '{printf "%.2f", ($2 - $1) / $3 / $4 * 100}')
rss=$(awk '/VmRSS/ {printf "%d", $2 / 1024}' /proc/$pid/status)
echo "shell idle CPU: ${cpu}% of a core over ${SECS}s (budget ${CPU_BUDGET}%)"
echo "shell memory:   ${rss} MB (budget ${RSS_BUDGET} MB)"
echo "threads:        $(ls /proc/$pid/task | wc -l)"
ok=$(echo "$cpu $CPU_BUDGET $rss $RSS_BUDGET" | awk '{print ($1 <= $2 && $3 <= $4) ? 1 : 0}')
[ "$ok" = 1 ] && echo "PASS" || { echo "OVER BUDGET"; exit 1; }
