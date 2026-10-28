#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# checkov-scan.sh — Enterprise Checkov IaC Policy Scanner
#
# Usage:
#   ./checkov-scan.sh --dir ./                   # Scan current directory
#   ./checkov-scan.sh --dir ./infra --framework terraform
#   ./checkov-scan.sh --dir . --fail-on HIGH
#
# Dependencies: checkov (pip install checkov), python3
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

# ── Defaults ──────────────────────────────────────────────────────────────────
SCAN_DIR="."
FRAMEWORK="terraform"        # terraform, bicep, arm, kubernetes, dockerfile, all
CHECKS="CKV_AZURE_*"         # CIS Azure checks by default
FAIL_SEVERITY="HIGH"          # CRITICAL, HIGH, MEDIUM, LOW, NONE
OUTPUT_FORMAT="cli"           # cli, json, junitxml, sarif
REPORT_DIR="./checkov-reports"
SOFT_FAIL=false
COMPACT=true
DOWNLOAD_EXTERNAL=false

# ── Functions ─────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${BOLD}Checkov Enterprise IaC Security Scanner${NC}

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --dir        <path>          Directory to scan (default: .)
  --framework  <fw>            Framework: terraform|bicep|arm|kubernetes|dockerfile|all
  --checks     <pattern>       Check IDs to include (default: CKV_AZURE_*)
  --fail-on    <severity>      Fail on: CRITICAL|HIGH|MEDIUM|LOW|NONE (default: HIGH)
  --format     <fmt>           Output: cli|json|junitxml|sarif (default: cli)
  --report-dir <path>          Output directory (default: ./checkov-reports)
  --soft-fail                  Don't fail pipeline on policy violations
  --verbose                    Verbose output (disable --compact)
  --download-ext               Download & scan external modules
  -h, --help                   Show this help

EXAMPLES:
  # Scan Terraform with CIS Azure and fail on HIGH+
  $0 --dir ./infra --framework terraform --fail-on HIGH

  # Scan all IaC in directory, output SARIF for GitHub Security
  $0 --dir . --framework all --format sarif --report-dir ./reports

  # Soft-fail scan for visibility without blocking
  $0 --dir . --soft-fail --format junitxml

EOF
  exit 0
}

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}❌ Error: '$1' not found. Install with: pip install checkov${NC}"
    exit 1
  fi
}

print_header() {
  echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}  🛡️ Checkov Enterprise IaC Policy Scanner              ${NC}"
  echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════${NC}"
  echo -e "  Framework:    ${BOLD}${FRAMEWORK}${NC}"
  echo -e "  Checks:       ${BOLD}${CHECKS}${NC}"
  echo -e "  Fail Level:   ${BOLD}${FAIL_SEVERITY}${NC}"
  echo -e "  Directory:    ${BOLD}${SCAN_DIR}${NC}\n"
}

# ── Argument Parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)         SCAN_DIR="$2"; shift 2 ;;
    --framework)   FRAMEWORK="$2"; shift 2 ;;
    --checks)      CHECKS="$2"; shift 2 ;;
    --fail-on)     FAIL_SEVERITY="$2"; shift 2 ;;
    --format)      OUTPUT_FORMAT="$2"; shift 2 ;;
    --report-dir)  REPORT_DIR="$2"; shift 2 ;;
    --soft-fail)   SOFT_FAIL=true; shift ;;
    --verbose)     COMPACT=false; shift ;;
    --download-ext) DOWNLOAD_EXTERNAL=true; shift ;;
    -h|--help)     usage ;;
    *) echo -e "${RED}Unknown arg: $1${NC}"; usage ;;
  esac
done

# ── Setup ─────────────────────────────────────────────────────────────────────
check_dependency checkov
print_header
mkdir -p "$REPORT_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXT_MAP=( ["cli"]="txt" ["json"]="json" ["junitxml"]="xml" ["sarif"]="sarif" )
REPORT_EXT="${EXT_MAP[$OUTPUT_FORMAT]:-txt}"
REPORT_FILE="${REPORT_DIR}/checkov-${FRAMEWORK}-${TIMESTAMP}.${REPORT_EXT}"

# ── Build Checkov Command ─────────────────────────────────────────────────────
CMD=(checkov
  "--directory" "$SCAN_DIR"
  "--framework" "$FRAMEWORK"
  "--output" "$OUTPUT_FORMAT"
  "--output-file-path" "$REPORT_DIR"
)

# Only add check filter if not scanning ALL
if [[ "$FRAMEWORK" != "all" && "$CHECKS" != "*" ]]; then
  CMD+=("--check" "$CHECKS")
fi

[[ "$COMPACT" == "true" ]] && CMD+=("--compact")
[[ "$SOFT_FAIL" == "true" ]] && CMD+=("--soft-fail")
[[ "$DOWNLOAD_EXTERNAL" == "false" ]] && CMD+=("--no-download")

# Map severity to Checkov's severity filter
case "$FAIL_SEVERITY" in
  CRITICAL) CMD+=("--check" "SEVERITY:CRITICAL") ;;
  HIGH)     CMD+=("--check" "SEVERITY:CRITICAL,HIGH") ;;
  MEDIUM)   CMD+=("--check" "SEVERITY:CRITICAL,HIGH,MEDIUM") ;;
  LOW)      ;; # Include all severities
  NONE)     CMD+=("--soft-fail") ;;
esac

# ── Execute ───────────────────────────────────────────────────────────────────
echo -e "⏳ Running Checkov scan...\n"
SCAN_EXIT_CODE=0
"${CMD[@]}" || SCAN_EXIT_CODE=$?

# ── Result ────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}── Checkov Scan Result ──────${NC}"
echo -e "  Report saved: ${BOLD}${REPORT_DIR}/${NC}"

if [[ $SCAN_EXIT_CODE -eq 0 ]]; then
  echo -e "\n${GREEN}${BOLD}✅ SCAN PASSED — All CIS policy checks passed${NC}\n"
elif [[ "$SOFT_FAIL" == "true" ]]; then
  echo -e "\n${YELLOW}${BOLD}⚠️  VIOLATIONS FOUND (soft-fail mode — pipeline continues)${NC}\n"
  SCAN_EXIT_CODE=0
else
  echo -e "\n${RED}${BOLD}❌ POLICY VIOLATIONS — Fix HIGH/CRITICAL findings before merging${NC}"
  echo -e "${YELLOW}   Review: ${REPORT_DIR}/ for detailed remediation steps${NC}\n"
fi

# ── SARIF Hint ────────────────────────────────────────────────────────────────
if [[ "$OUTPUT_FORMAT" == "sarif" ]]; then
  echo -e "${BLUE}💡 Upload SARIF to GitHub Security tab for inline PR annotations${NC}\n"
fi

exit $SCAN_EXIT_CODE
