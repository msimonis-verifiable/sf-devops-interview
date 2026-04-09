#!/bin/bash
#
# Validates .github/workflows/deploy-production.yml for known issues.
# Called by the validate-deploy-workflow CI check on pull requests.
#
# Each check prints PASS or FAIL. The script exits non-zero if any check fails.

WORKFLOW=".github/workflows/deploy-production.yml"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "Validating $WORKFLOW"
echo "========================================"

# -------------------------------------------------------
# 1. No legacy tarball CLI install
# -------------------------------------------------------
echo ""
echo "Check 1: Salesforce CLI installation method"
if grep -q "wget.*sfdx.*tar" "$WORKFLOW" 2>/dev/null; then
    fail "Still using legacy tarball download for Salesforce CLI. Use 'npm install -g @salesforce/cli', a setup action, or the salesforce/cli Docker container."
else
    pass "No legacy tarball CLI install found."
fi

# -------------------------------------------------------
# 2. No outdated GitHub Actions
# -------------------------------------------------------
echo ""
echo "Check 2: GitHub Actions versions"
OUTDATED=0
if grep -q "actions/checkout@v[12]" "$WORKFLOW" 2>/dev/null; then
    fail "actions/checkout is outdated. Use v4."
    OUTDATED=1
fi
if grep -q "actions/setup-node@v[123]" "$WORKFLOW" 2>/dev/null; then
    fail "actions/setup-node is outdated. Use v4."
    OUTDATED=1
fi
if [ $OUTDATED -eq 0 ]; then
    pass "GitHub Actions are up to date."
fi

# -------------------------------------------------------
# 3. No EOL Node.js version
# -------------------------------------------------------
echo ""
echo "Check 3: Node.js version"
if grep -q "node-version: 16" "$WORKFLOW" 2>/dev/null; then
    fail "Node.js 16 is EOL. Use 18 or 20."
elif grep -q "node-version: 14" "$WORKFLOW" 2>/dev/null; then
    fail "Node.js 14 is EOL. Use 18 or 20."
else
    pass "Node.js version is current."
fi

# -------------------------------------------------------
# 4. No secrets leaked to logs (cat, echo with secrets)
# -------------------------------------------------------
echo ""
echo "Check 4: Secret handling"
SECRET_ISSUES=0

# Check for cat/echo that could dump the metadata file with secrets
if grep -A 20 "Set Connected App Secrets" "$WORKFLOW" | grep -qE 'cat (\$|"|\./)'; then
    fail "Found 'cat' command in secret injection step. This leaks secrets to workflow logs."
    SECRET_ISSUES=1
fi

# Check that secrets are passed via env vars, not direct interpolation in run commands
# (We look for the env: block in the secrets step as a positive signal)
if grep -B 2 -A 10 "Set Connected App Secrets" "$WORKFLOW" | grep -q "env:"; then
    pass "Secrets are passed via environment variables."
else
    # Only flag if they still have direct ${{ secrets.X }} in the run block
    if grep -A 10 "Set Connected App Secrets" "$WORKFLOW" | grep "run:" -A 8 | grep -q 'secrets\.'; then
        fail "Secrets are interpolated directly into the shell command. Use env: block instead."
        SECRET_ISSUES=1
    fi
fi

if [ $SECRET_ISSUES -eq 0 ]; then
    pass "No secret leakage patterns found."
fi

# -------------------------------------------------------
# 5. Decrypted key cleanup
# -------------------------------------------------------
echo ""
echo "Check 5: Sensitive file cleanup"
if grep -q "rm.*server\.key" "$WORKFLOW" 2>/dev/null; then
    # Check it runs on failure too
    if grep -B 3 "rm.*server\.key" "$WORKFLOW" | grep -q "always()"; then
        pass "Decrypted key is cleaned up (with always() condition)."
    else
        fail "Key cleanup exists but doesn't use 'if: always()'. It won't run on failure."
    fi
else
    fail "Decrypted server.key is never cleaned up. Add a cleanup step with 'if: always()'."
fi

# -------------------------------------------------------
# 6. Deploy commands have --wait
# -------------------------------------------------------
echo ""
echo "Check 6: Deploy --wait flag"
DEPLOY_LINES=$(grep "sf project deploy start" "$WORKFLOW" 2>/dev/null)
DEPLOY_COUNT=$(echo "$DEPLOY_LINES" | wc -l | tr -d ' ')
WAIT_COUNT=$(echo "$DEPLOY_LINES" | grep -c "\-\-wait" || true)

if [ "$DEPLOY_COUNT" -gt 0 ] && [ "$WAIT_COUNT" -eq "$DEPLOY_COUNT" ]; then
    pass "All deploy commands have --wait."
else
    fail "One or more 'sf project deploy start' commands are missing --wait. Deploys without --wait return immediately and report false success."
fi

# -------------------------------------------------------
# 7. No NoTestRun for production
# -------------------------------------------------------
echo ""
echo "Check 7: Test level"
if grep "deploy start" "$WORKFLOW" | grep -v "destructive" | grep -q "NoTestRun"; then
    fail "Main deploy uses --test-level NoTestRun. Production deployments require tests. Use RunLocalTests."
else
    pass "Deploy does not use NoTestRun for the main deployment."
fi

# -------------------------------------------------------
# 8. Slack notification has conditional execution
# -------------------------------------------------------
echo ""
echo "Check 8: Slack notification conditions"
# Look for an if: condition near the Slack step
if grep -B 2 "slackapi/slack-github-action" "$WORKFLOW" | grep -q "if:"; then
    pass "Slack notification has a conditional (if:)."
elif grep -c "slackapi/slack-github-action" "$WORKFLOW" | grep -q "^2$"; then
    # Two Slack steps probably means success + failure split
    pass "Multiple Slack notification steps found (likely success/failure split)."
elif grep -c "Notify Slack" "$WORKFLOW" | grep -q "^[2-9]"; then
    pass "Multiple notification steps found."
else
    # Check if it's in a separate job with needs/if
    if grep -B 10 "slackapi/slack-github-action" "$WORKFLOW" | grep -q "if:"; then
        pass "Slack notification has a conditional."
    else
        fail "Slack notification runs unconditionally. A failed deploy will send a success message. Add 'if: success()' or split into success/failure steps."
    fi
fi

# -------------------------------------------------------
# 9. No namespace stripping for production
# -------------------------------------------------------
echo ""
echo "Check 9: Namespace handling"
if grep -q 'sed.*credcheck__' "$WORKFLOW" 2>/dev/null; then
    fail "Workflow strips the credcheck__ namespace. This is correct for staging (no namespace) but WRONG for the packaging org where the namespace is expected. Remove this step for production deployments."
else
    pass "No namespace stripping found."
fi

# -------------------------------------------------------
# 10. No @deprecated commenting for production
# -------------------------------------------------------
echo ""
echo "Check 10: @deprecated handling"
if grep -q 'sed.*@deprecated' "$WORKFLOW" 2>/dev/null; then
    fail "@deprecated annotations are being commented out. This is needed for non-packaging orgs but should NOT be done for the packaging org. Remove this step for production."
else
    pass "No @deprecated commenting found."
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "========================================"
if [ $FAILURES -eq 0 ]; then
    echo "ALL CHECKS PASSED"
    exit 0
else
    echo "$FAILURES CHECK(S) FAILED"
    echo ""
    echo "Fix the issues above in .github/workflows/deploy-production.yml and push again."
    exit 1
fi
