#!/bin/bash
#
# Validates .github/workflows/deploy-production.yml
# Called by the validate-deploy-workflow CI check on pull requests.

WORKFLOW=".github/workflows/deploy-production.yml"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "Validating $WORKFLOW"
echo "========================================"

# 1
echo ""
echo "Check 1: CLI installation"
if grep -q "wget.*sfdx.*tar" "$WORKFLOW" 2>/dev/null; then
    fail "CLI installation method"
else
    pass "CLI installation"
fi

# 2
echo ""
echo "Check 2: Action versions"
OUTDATED=0
if grep -q "actions/checkout@v[12]" "$WORKFLOW" 2>/dev/null; then
    fail "checkout action version"
    OUTDATED=1
fi
if grep -q "actions/setup-node@v[123]" "$WORKFLOW" 2>/dev/null; then
    fail "setup-node action version"
    OUTDATED=1
fi
if [ $OUTDATED -eq 0 ]; then
    pass "Action versions"
fi

# 3
echo ""
echo "Check 3: Node.js version"
if grep -qE "node-version: (14|16)" "$WORKFLOW" 2>/dev/null; then
    fail "Node.js version"
else
    pass "Node.js version"
fi

# 4
echo ""
echo "Check 4: Secret handling"
SECRET_ISSUES=0
if grep -A 20 "Set Connected App Secrets" "$WORKFLOW" | grep -qE 'cat (\$|"|\./)'; then
    fail "Secret leakage in logs"
    SECRET_ISSUES=1
fi
if grep -B 2 -A 10 "Set Connected App Secrets" "$WORKFLOW" | grep -q "env:"; then
    :
else
    if grep -A 10 "Set Connected App Secrets" "$WORKFLOW" | grep "run:" -A 8 | grep -q 'secrets\.'; then
        fail "Secret injection method"
        SECRET_ISSUES=1
    fi
fi
if [ $SECRET_ISSUES -eq 0 ]; then
    pass "Secret handling"
fi

# 5
echo ""
echo "Check 5: Sensitive file cleanup"
if grep -q "rm.*server\.key" "$WORKFLOW" 2>/dev/null; then
    if grep -B 3 "rm.*server\.key" "$WORKFLOW" | grep -q "always()"; then
        pass "Sensitive file cleanup"
    else
        fail "Cleanup runs conditionally"
    fi
else
    fail "Sensitive file cleanup"
fi

# 6
echo ""
echo "Check 6: Deploy reliability"
DEPLOY_LINES=$(grep "sf project deploy start" "$WORKFLOW" 2>/dev/null)
DEPLOY_COUNT=$(echo "$DEPLOY_LINES" | wc -l | tr -d ' ')
WAIT_COUNT=$(echo "$DEPLOY_LINES" | grep -c "\-\-wait" || true)
if [ "$DEPLOY_COUNT" -gt 0 ] && [ "$WAIT_COUNT" -eq "$DEPLOY_COUNT" ]; then
    pass "Deploy reliability"
else
    fail "Deploy reliability"
fi

# 7
echo ""
echo "Check 7: Test execution"
if grep "deploy start" "$WORKFLOW" | grep -v "destructive" | grep -q "NoTestRun"; then
    fail "Test execution"
else
    pass "Test execution"
fi

# 8
echo ""
echo "Check 8: Notification conditions"
if grep -B 2 "slackapi/slack-github-action" "$WORKFLOW" | grep -q "if:"; then
    pass "Notification conditions"
elif [ "$(grep -c "slackapi/slack-github-action" "$WORKFLOW")" -ge 2 ]; then
    pass "Notification conditions"
elif [ "$(grep -c "Notify Slack" "$WORKFLOW")" -ge 2 ]; then
    pass "Notification conditions"
elif grep -B 10 "slackapi/slack-github-action" "$WORKFLOW" | grep -q "if:"; then
    pass "Notification conditions"
else
    fail "Notification conditions"
fi

# 9
echo ""
echo "Check 9: Namespace handling"
if grep -q 'sed.*credcheck__' "$WORKFLOW" 2>/dev/null; then
    fail "Namespace handling"
else
    pass "Namespace handling"
fi

# 10
echo ""
echo "Check 10: Annotation handling"
if grep -q 'sed.*@deprecated' "$WORKFLOW" 2>/dev/null; then
    fail "Annotation handling"
else
    pass "Annotation handling"
fi

# Summary
echo ""
echo "========================================"
if [ $FAILURES -eq 0 ]; then
    echo "ALL CHECKS PASSED"
    exit 0
else
    echo "$FAILURES CHECK(S) FAILED"
    exit 1
fi
