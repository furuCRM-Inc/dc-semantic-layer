/**
 * Anonymous Apex — verify all 3 pain point scenarios resolve correctly.
 * Run: sf apex run --file scripts/apex/verifyPainPointSamples.apex --target-org <alias>
 */

Integer passed = 0;
Integer failed = 0;

// ── helper ───────────────────────────────────────────────────────────────────
void assertContains(String label, String haystack, String needle) {
    if (haystack != null && haystack.contains(needle)) {
        System.debug('  PASS: ' + label);
        passed++;
    } else {
        System.debug('  FAIL: ' + label + ' — expected to contain: ' + needle);
        System.debug('        actual: ' + (haystack == null ? 'null' : haystack.left(200)));
        failed++;
    }
}

void assertEqual(String label, Object expected, Object actual) {
    if (expected == actual || (expected != null && expected.equals(actual))) {
        System.debug('  PASS: ' + label);
        passed++;
    } else {
        System.debug('  FAIL: ' + label + ' — expected=' + expected + ' actual=' + actual);
        failed++;
    }
}

// ── Pain Point 1: behavioral guardrail on churn DMO ─────────────────────────
System.debug('=== PAIN POINT 1: Action Guardrails ===');
List<AgentforceSemanticResolver.ResolveRequest> p1req =
    new List<AgentforceSemanticResolver.ResolveRequest>();
AgentforceSemanticResolver.ResolveRequest r1 = new AgentforceSemanticResolver.ResolveRequest();
r1.entityName = 'ChurnRiskProfile__dlm';
r1.entityType = 'DMO';
p1req.add(r1);

List<AgentforceSemanticResolver.ResolveResult> p1 = AgentforceSemanticResolver.resolve(p1req);
assertEqual('PP1 found=true', true, p1[0].found);
assertEqual('PP1 entityType=DMO', 'DMO', p1[0].entityType);
assertEqual('PP1 targetDmo=Individual__dlm', 'Individual__dlm', p1[0].targetDmo);
assertContains('PP1 guardrail contains EXCEPTION',   p1[0].businessLogicRules, 'EXCEPTION');
assertContains('PP1 guardrail routes to human agent', p1[0].businessLogicRules, 'human support agent');
assertContains('PP1 mapping has ChurnScore field',    p1[0].fieldMappingsJson,  'churnRiskScore');

// ── Pain Point 2: write-back pre-execution constraints ───────────────────────
System.debug('=== PAIN POINT 2: Write-back Guardrails ===');
List<AgentforceSemanticResolver.ResolveRequest> p2req =
    new List<AgentforceSemanticResolver.ResolveRequest>();
AgentforceSemanticResolver.ResolveRequest r2 = new AgentforceSemanticResolver.ResolveRequest();
r2.entityName = 'OpportunitySignalDLO__dlm';
r2.entityType = 'DLO';
p2req.add(r2);

List<AgentforceSemanticResolver.ResolveResult> p2 = AgentforceSemanticResolver.resolve(p2req);
assertEqual('PP2 found=true',   true,  p2[0].found);
assertEqual('PP2 entityType=DLO', 'DLO', p2[0].entityType);
assertContains('PP2 check CloseDate',       p2[0].businessLogicRules, 'CloseDate');
assertContains('PP2 check Edit permission', p2[0].businessLogicRules, 'Edit permission');
assertContains('PP2 no auto-retry rule',    p2[0].businessLogicRules, 'do NOT retry');
assertContains('PP2 mapping has StageName', p2[0].fieldMappingsJson,  'StageName');

// ── Pain Point 3a: Enterprise context ────────────────────────────────────────
System.debug('=== PAIN POINT 3a: Enterprise Context ===');
List<AgentforceSemanticResolver.ResolveRequest> p3ereq =
    new List<AgentforceSemanticResolver.ResolveRequest>();
AgentforceSemanticResolver.ResolveRequest re = new AgentforceSemanticResolver.ResolveRequest();
re.entityName  = 'QualifiedLeadProfile__dlm';
re.contextTag  = 'Enterprise';
p3ereq.add(re);

List<AgentforceSemanticResolver.ResolveResult> p3e = AgentforceSemanticResolver.resolve(p3ereq);
assertEqual('PP3-E found=true',          true,         p3e[0].found);
assertEqual('PP3-E contextTag=Enterprise', 'Enterprise', p3e[0].contextTag);
assertContains('PP3-E ARR threshold 50M',  p3e[0].businessLogicRules, '50,000,000');
assertContains('PP3-E requires MEDDIC',    p3e[0].businessLogicRules, 'MEDDIC');

// ── Pain Point 3b: SMB context ───────────────────────────────────────────────
System.debug('=== PAIN POINT 3b: SMB Context ===');
List<AgentforceSemanticResolver.ResolveRequest> p3sreq =
    new List<AgentforceSemanticResolver.ResolveRequest>();
AgentforceSemanticResolver.ResolveRequest rs = new AgentforceSemanticResolver.ResolveRequest();
rs.entityName  = 'QualifiedLeadProfile__dlm';
rs.contextTag  = 'SMB';
p3sreq.add(rs);

List<AgentforceSemanticResolver.ResolveResult> p3s = AgentforceSemanticResolver.resolve(p3sreq);
assertEqual('PP3-S found=true',       true,  p3s[0].found);
assertEqual('PP3-S contextTag=SMB',   'SMB', p3s[0].contextTag);
assertContains('PP3-S ARR threshold 10M', p3s[0].businessLogicRules, '10,000,000');
assertContains('PP3-S self-serve trial',  p3s[0].businessLogicRules, 'Self-serve');

// ── Isolation: Enterprise context does NOT return SMB rules ──────────────────
System.debug('=== ISOLATION: Enterprise context must not leak SMB rules ===');
assertContains('Isolation: Enterprise has MEDDIC, not self-serve',
    p3e[0].businessLogicRules, 'MEDDIC');
Boolean isolation = !p3e[0].businessLogicRules.contains('Self-serve');
if (isolation) {
    System.debug('  PASS: Enterprise rules do not contain SMB content');
    passed++;
} else {
    System.debug('  FAIL: Enterprise rules leaked SMB content');
    failed++;
}

// ── Summary ──────────────────────────────────────────────────────────────────
System.debug('');
System.debug('════════════════════════════════════════');
System.debug('RESULT: ' + passed + ' passed, ' + failed + ' failed');
System.debug('════════════════════════════════════════');
if (failed > 0) {
    throw new IllegalStateException('Verification failed: ' + failed + ' check(s) did not pass');
}
