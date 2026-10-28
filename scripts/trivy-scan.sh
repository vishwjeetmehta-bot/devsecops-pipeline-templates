#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# trivy-scan.sh — Standalone Trivy container & filesystem scanner
#
# Usage:
#   ./trivy-scan.sh --image <image:tag>           # Scan container image
#   ./trivy-scan.sh --fs <directory>              # Scan filesystem/repo
#   ./trivy-scan.sh --image <image:tag> --fail    # Exit 1 on CRITICAL/HIGH
#
# Dependencies: trivy, jq
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

# ── Defaults ──────────────────────────────────────────────────────────────────
SCAN_TARGET=""
SCAN_TYPE=""          # "image" or "fs"
SEVERITY="CRITICAL,HIGH"
FAIL_ON_VULN=false
OUTPUT_FORMAT="table"
REPORT_DIR="./trivy-reports"
IGNORE_UNFIXED=true

# ── Functions ─────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Trivy DevSecOps Scanner${NC}

USAGE:
  $0 --image <image:tag> [OPTIONS]
  $0 --fs <directory>   [OPTIONS]

OPTIONS:
  --image   <image:tag>       Docker image to scan
  --fs      <path>            Filesystem path to scan
  --severity <levels>         Comma-separated: CRITICAL,HIGH,MEDIUM,LOW (default: CRITICAL,HIGH)
  --fail                      Exit code 1 if vulnerabilities found
  --format  <table|json|sarif> Output format (default: table)
  --report-dir <path>         Output directory for reports (default: ./trivy-reports)
  --include-unfixed           Include vulnerabilities without available fixes
  -h, --help                  Show this help

EXAMPLES:
  $0 --image nginx:latest --fail
  $0 --fs ./src --severity CRITICAL --format sarif
  $0 --image myapp:v1.2.3 --format json --report-dir /tmp/reports

EOF
  exit 0
}

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}❌ Error: '$1' is not installed or not in PATH${NC}"
    echo -e "   Install with: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
    exit 1
  fi
}

print_header() {
  echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}  🔍 Trivy DevSecOps Vulnerability Scanner          ${NC}"
  echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════${NC}\n"
}

print_summary() {
  local exit_code=$1
  echo -e "\n${BOLD}────── Scan Summary ──────${NC}"
  echo -e "  Target:   ${BOLD}${SCAN_TARGET}${NC}"
  echo -e "  Type:     ${BOLD}${SCAN_TYPE}${NC}"
  echo -e "  Severity: ${BOLD}${SEVERITY}${NC}"
  echo -e "  Report:   ${BOLD}${REPORT_DIR}/${NC}"

  if [[ $exit_code -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}✅ SCAN PASSED — No vulnerabilities found at ${SEVERITY} level${NC}\n"
  else
    echo -e "\n${RED}${BOLD}❌ SCAN FAILED — Vulnerabilities detected at ${SEVERITY} level${NC}"
    echo -e "${YELLOW}   Review the report in ${REPORT_DIR}/ for remediation details${NC}\n"
  fi
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)     SCAN_TYPE="image"; SCAN_TARGET="$2"; shift 2 ;;
    --fs)        SCAN_TYPE="fs"; SCAN_TARGET="$2"; shift 2 ;;
    --severity)  SEVERITY="$2"; shift 2 ;;
    --fail)      FAIL_ON_VULN=true; shift ;;
    --format)    OUTPUT_FORMAT="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --include-unfixed) IGNORE_UNFIXED=false; shift ;;
    -h|--help)   usage ;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; usage ;;
  esac
done

# ── Validate ──────────────────────────────────────────────────────────────────
if [[ -z "$SCAN_TARGET" ]]; then
  echo -e "${RED}❌ Error: Scan target is required. Use --image or --fs${NC}"
  usage
fi

check_dependency trivy
check_dependency jq

# ── Setup ─────────────────────────────────────────────────────────────────────
print_header
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${REPORT_DIR}/trivy-${SCAN_TYPE}-${TIMESTAMP}.${OUTPUT_FORMAT}"

# ── Build Trivy Args ──────────────────────────────────────────────────────────
TRIVY_ARGS=(
  "--severity" "$SEVERITY"
  "--format" "$OUTPUT_FORMAT"
  "--output" "$REPORT_FILE"
  "--exit-code" "$([ "$FAIL_ON_VULN" = true ] && echo 1 || echo 0)"
)

if [[ "$IGNORE_UNFIXED" == "true" ]]; then
  TRIVY_ARGS+=("--ignore-unfixed")
fi

if [[ -f ".trivyignore" ]]; then
  echo -e "${YELLOW}⚠️  Using .trivyignore file for known false-positive suppressions${NC}"
  TRIVY_ARGS+=("--ignorefile" ".trivyignore")
fi

# ── Execute Scan ──────────────────────────────────────────────────────────────
echo -e "🔍 Scanning ${BOLD}${SCAN_TYPE}${NC}: ${YELLOW}${SCAN_TARGET}${NC}"
echo -e "📊 Severity filter: ${BOLD}${SEVERITY}${NC}"
echo -e "📁 Report output:   ${BOLD}${REPORT_FILE}${NC}\n"

SCAN_EXIT_CODE=0

if [[ "$SCAN_TYPE" == "image" ]]; then
  trivy image "${TRIVY_ARGS[@]}" \
    --vuln-type "os,library" \
    "$SCAN_TARGET" || SCAN_EXIT_CODE=$?
elif [[ "$SCAN_TYPE" == "fs" ]]; then
  trivy fs "${TRIVY_ARGS[@]}" \
    --scanners "vuln,secret,misconfig" \
    "$SCAN_TARGET" || SCAN_EXIT_CODE=$?
fi

# ── Also run in table format for console output if JSON/SARIF was selected ───
if [[ "$OUTPUT_FORMAT" != "table" ]]; then
  echo -e "\n${BOLD}── Console Summary ──${NC}"
  if [[ "$SCAN_TYPE" == "image" ]]; then
    trivy image --severity "$SEVERITY" --ignore-unfixed --vuln-type "os,library" "$SCAN_TARGET" 2>/dev/null || true
  else
    trivy fs --severity "$SEVERITY" --scanners "vuln,secret,misconfig" "$SCAN_TARGET" 2>/dev/null || true
  fi
fi

print_summary $SCAN_EXIT_CODE

# ── SARIF Upload Hint ─────────────────────────────────────────────────────────
if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
  echo -e "${BLUE}💡 SARIF report saved. Upload to GitHub Security tab with:${NC}"
  echo -e "   github/codeql-action/upload-sarif with sarif_file: ${REPORT_FILE}\n"
fi

exit $SCAN_EXIT_CODE
