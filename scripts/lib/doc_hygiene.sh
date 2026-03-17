# shellcheck shell=bash
#
# doc_hygiene.sh — documentation quality checks for pre-commit
#
# Public API:
#   _doc_hygiene_check [file...]   — check staged files (or supplied file list)
#
# Exit codes: 0 = pass, 1 = violations found

_doc_hygiene_check() {
   local files=("$@")
   local status=0

   # If no files supplied, derive from git staged set
   if [[ ${#files[@]} -eq 0 ]]; then
      local staged
      staged="$(git diff --cached --name-only --diff-filter=ACM -- '*.md' '*.yaml' '*.yml' 2>/dev/null || true)"
      [[ -z "$staged" ]] && return 0
      IFS=$'\n' read -r -d '' -a files <<<"$staged" || true
   fi

   local file
   for file in "${files[@]}"; do
      [[ -f "$file" ]] || continue

      # ------------------------------------------------------------------
      # Check 1: placeholder GitHub org URLs (github.com/user/)
      # ------------------------------------------------------------------
      local placeholder_hits
      placeholder_hits="$(grep -nE -- 'github\.com/user/' -- "$file" 2>/dev/null || true)"
      if [[ -n "$placeholder_hits" ]]; then
         _warn "doc-hygiene: placeholder URL 'github.com/user/' in ${file}:"
         while IFS= read -r hit; do
            _warn "  ${hit}"
         done <<<"$placeholder_hits"
         status=1
      fi

      # ------------------------------------------------------------------
      # Check 2: bare http:// links in markdown (should be https://)
      # Portable boundary: match http:// not preceded by alphanumeric or colon
      # ------------------------------------------------------------------
      if [[ "$file" == *.md ]]; then
         local http_hits
         http_hits="$(grep -nE -- '(^|[^[:alnum:]_:])http://[^)[:space:]]+' -- "$file" 2>/dev/null || true)"
         if [[ -n "$http_hits" ]]; then
            _warn "doc-hygiene: bare http:// link (use https://) in ${file}:"
            while IFS= read -r hit; do
               _warn "  ${hit}"
            done <<<"$http_hits"
            status=1
         fi
      fi

      # ------------------------------------------------------------------
      # Check 3: hardcoded private IPs in YAML (non-blocking warning)
      # Covers RFC1918: 10.x.x.x, 172.16-31.x.x, 192.168.x.x
      # Portable boundary: require non-digit before/after the IP
      # ------------------------------------------------------------------
      if [[ "$file" == *.yaml || "$file" == *.yml ]]; then
         local ip_hits
         ip_hits="$(grep -nE -- \
            '(^|[^0-9])(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+)([^0-9]|$)' \
            -- "$file" 2>/dev/null || true)"
         if [[ -n "$ip_hits" ]]; then
            _warn "doc-hygiene: hardcoded private IP in ${file} (consider using DNS name):"
            while IFS= read -r hit; do
               _warn "  ${hit}"
            done <<<"$ip_hits"
            # Non-blocking — warn only, do not set status=1
         fi
      fi
   done

   return "$status"
}
