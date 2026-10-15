#!/bin/bash
# Check staged content without printing any matched secret values.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

secret_pattern='-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----|gh[pousr]_[[:alnum:]_]{20,}|github_pat_[[:alnum:]_]{20,}|AKIA[0-9A-Z]{16}|[[:alnum:]+/=_-]{64,}|[[:alnum:]_-]{20,}\.[[:alnum:]_-]{20,}\.[[:alnum:]_-]{10,}'
failed=0
count=0

while IFS= read -r -d '' staged_path; do
    count=$((count + 1))
    case "$staged_path" in
        .gitignore|README.md|.githooks/pre-commit|scripts/check-staged-secrets.sh|BinancePositionWidget/*.swift|BinancePositionWidget.xcodeproj/project.pbxproj)
            ;;
        *)
            printf 'Blocked: file outside the source upload allowlist: %s\n' "$staged_path" >&2
            failed=1
            continue
            ;;
    esac

    # Read from the index so partially staged changes are checked accurately.
    # Do not use grep -q: consuming the complete input avoids SIGPIPE hiding a match.
    if git show ":$staged_path" | LC_ALL=C grep -E -e "$secret_pattern" > /dev/null; then
        printf 'Blocked: possible credential in staged file: %s (value withheld)\n' "$staged_path" >&2
        failed=1
    fi
done < <(git diff --cached --name-only --diff-filter=ACM -z)

if [ "$failed" -ne 0 ]; then
    printf 'Commit cancelled. Review and unstage sensitive or non-source files.\n' >&2
    exit 1
fi

printf 'Staged source check passed: %s files.\n' "$count"
