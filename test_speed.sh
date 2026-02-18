#!/bin/bash

# NetBoltZ Speed Test Script
# Tests website performance: Direct vs HTTP/2 vs HTTP/3 (QUIC)
# Usage: ./test_speed.sh <website.com> <proxy-url>
# Example: ./test_speed.sh youtube.com https://netboltz.yourdomain.com

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$#" -lt 2 ]; then
    echo -e "${RED}Usage: $0 <website.com> <proxy-url>${NC}"
    echo "Example: $0 youtube.com https://netboltz.yourdomain.com"
    exit 1
fi

WEBSITE=$1
PROXY_URL=$2
RUNS=${3:-5}

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  ⚡ NetBoltZ Speed Benchmark${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Site:   ${CYAN}$WEBSITE${NC}"
echo -e "Proxy:  ${CYAN}$PROXY_URL${NC}"
echo -e "Runs:   ${CYAN}$RUNS per test${NC}"
echo ""

# Average calculator
avg() {
    local sum=0; local n=0
    for v in "$@"; do sum=$(echo "$sum + $v" | bc); ((n++)); done
    echo "scale=4; $sum / $n" | bc
}

# Run direct tests
echo -e "${YELLOW}▶ Direct Connection${NC}"
direct_times=()
for i in $(seq 1 $RUNS); do
    t=$(curl -o /dev/null -s -w "%{time_total}" https://$WEBSITE 2>/dev/null)
    echo "  Run $i: ${t}s"
    direct_times+=($t)
    sleep 0.5
done
direct_avg=$(avg "${direct_times[@]}")
echo -e "  ${GREEN}Average: ${direct_avg}s${NC}"
echo ""

# Run HTTP/2 proxy tests
echo -e "${YELLOW}▶ HTTP/2 Proxy${NC}"
http2_times=()
for i in $(seq 1 $RUNS); do
    t=$(curl --http2 -k -o /dev/null -s -w "%{time_total}" $PROXY_URL 2>/dev/null || echo "0")
    echo "  Run $i: ${t}s"
    [ "$t" != "0" ] && http2_times+=($t)
    sleep 0.5
done
if [ ${#http2_times[@]} -gt 0 ]; then
    http2_avg=$(avg "${http2_times[@]}")
    echo -e "  ${GREEN}Average: ${http2_avg}s${NC}"
else
    http2_avg=0
    echo -e "  ${RED}Failed${NC}"
fi
echo ""

# Run HTTP/3 (QUIC) tests
echo -e "${YELLOW}▶ HTTP/3 (QUIC) Proxy${NC}"
if curl --version 2>&1 | grep -q "HTTP3\|http3"; then
    http3_times=()
    for i in $(seq 1 $RUNS); do
        t=$(curl --http3 -k -o /dev/null -s -w "%{time_total}" $PROXY_URL 2>/dev/null || echo "0")
        echo "  Run $i: ${t}s"
        [ "$t" != "0" ] && http3_times+=($t)
        sleep 0.5
    done
    if [ ${#http3_times[@]} -gt 0 ]; then
        http3_avg=$(avg "${http3_times[@]}")
        echo -e "  ${GREEN}Average: ${http3_avg}s${NC}"
    else
        http3_avg=0
        echo -e "  ${RED}Failed${NC}"
    fi
else
    echo -e "  ${RED}curl HTTP/3 not supported. Use Firefox with http3 enabled.${NC}"
    http3_avg=0
fi
echo ""

# Results summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  📊 Results Summary: $WEBSITE${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Direct:          ${direct_avg}s"

if [ "$http2_avg" != "0" ]; then
    imp=$(echo "scale=1; (($direct_avg - $http2_avg) / $direct_avg) * 100" | bc)
    if (( $(echo "$imp > 0" | bc -l) )); then
        echo -e "HTTP/2 Proxy:    ${http2_avg}s  ${GREEN}(+${imp}% faster)${NC}"
    else
        echo -e "HTTP/2 Proxy:    ${http2_avg}s  ${RED}(${imp}% slower)${NC}"
    fi
fi

if [ "$http3_avg" != "0" ]; then
    imp=$(echo "scale=1; (($direct_avg - $http3_avg) / $direct_avg) * 100" | bc)
    if (( $(echo "$imp > 0" | bc -l) )); then
        echo -e "HTTP/3 (QUIC):   ${http3_avg}s  ${GREEN}(+${imp}% faster)${NC}"
    else
        echo -e "HTTP/3 (QUIC):   ${http3_avg}s  ${RED}(${imp}% slower)${NC}"
    fi
fi

echo ""
echo -e "${BLUE}======================================${NC}"
