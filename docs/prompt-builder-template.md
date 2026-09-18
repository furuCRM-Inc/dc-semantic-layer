# Prompt Builder Template — Hybrid Semantic Grounding

This template shows how `AgentforceSemanticResolver` output is injected into
a Prompt Builder system prompt to address all 3 structural limits of Data Cloud's
native semantic layer.

---

## Template (Agentforce Flex Prompt)

```
You are a Salesforce AI agent. Before taking any action on a Data Cloud entity,
you MUST follow the verified semantic definition below.

## Entity: {!$Input:objectApiName} ({!$Input:entityType})
## Agent Context: {!$Input:contextTag}

### Field Mappings (verified by human steward)
{!$Invocable:AgentforceSemanticResolver.fieldMappingsJson}

### Business Logic Rules and Action Guardrails
{!$Invocable:AgentforceSemanticResolver.businessLogicRules}

---

## Your constraints:
1. Only reference fields listed in the Field Mappings above.
2. Follow ALL rules in the Business Logic section — especially EXCEPTION clauses.
3. If any pre-execution check fails, create a human approval task instead of retrying.
4. Do not invent field names, thresholds, or routing logic not present above.

## User request:
{!$Input:userMessage}
```

---

## How each pain point is resolved at runtime

### Pain Point 1 — Behavioral Guardrails (not expressible in Data Cloud)

**Resolver output injected:**
```
Business Logic Rules and Action Guardrails:
Churn risk score > 80% qualifies for re-engagement outreach.
EXCEPTION: If the customer has an open CRM Case with Status = "In Progress" or "Escalated",
do NOT send automated discount offers — route to a human support agent instead.
Recalculation lag: churn score is refreshed every 24 h; check timestamp before acting.
```

**Effect:** The LLM reads the EXCEPTION clause as a hard constraint. Even if the numeric
score passes the 80% threshold, the agent will not fire the offer action — it routes
to human instead. Data Cloud's `Calculated Insight` defined the metric; this registry
defined what the agent is *allowed to do* with it.

---

### Pain Point 2 — Write-back Pre-execution Checks

**Resolver output injected:**
```
Business Logic Rules and Action Guardrails:
Pre-execution checklist before updating Opportunity Stage to Closed-Won:
(1) CloseDate must be set and must not be in the future.
(2) Amount must be greater than 0.
(3) Confirm the running user has Edit permission on the Opportunity record.
(4) Verify no open blocking approval process exists on the record.
If any check fails: create a human approval Task, set owner to Opportunity owner,
do NOT retry automatically — log the failure reason in the Task description.
```

**Effect:** The LLM validates all 4 conditions before issuing the CRM API write.
On failure it creates a Task rather than looping. The CRM's validation rules are
surfaced as agent instructions *before* the write attempt, eliminating the
error-loop pattern.

---

### Pain Point 3 — Dynamic Context Switching

**Enterprise agent call:**
```
AgentforceSemanticResolver.resolve([{
    entityName : 'QualifiedLeadProfile__dlm',
    contextTag : 'Enterprise'
}])
```

**Enterprise rules injected:**
```
Enterprise qualified lead definition (context: Enterprise AE agent):
- Annual Revenue >= 50,000,000 JPY AND Employee Count >= 500
- Assign to Enterprise Account Executive queue
- MEDDIC qualification required before Stage 2
- Do not auto-send pricing — route to AE for personalised proposal
```

**SMB agent call:**
```
AgentforceSemanticResolver.resolve([{
    entityName : 'QualifiedLeadProfile__dlm',
    contextTag : 'SMB'
}])
```

**SMB rules injected:**
```
SMB qualified lead definition (context: SMB pooled agent):
- Annual Revenue < 10,000,000 JPY OR Employee Count < 100
- Assign to SMB round-robin pooled queue
- Check self-serve trial eligibility first; offer 14-day free trial if eligible
- Auto-send pricing PDF if trial declined
```

**Effect:** The same Data Cloud DMO produces two completely different agent
behaviours at runtime, determined by the `contextTag` passed by the calling
Agentforce topic or flow. No changes to Data Cloud's unified data model required.

---

## Architecture summary

```
Data Cloud (Analytics Semantic)        dc-semantic-layer (Operational Semantic)
─────────────────────────────          ──────────────────────────────────────────
Calculated Insight: churn score   →    Business_Logic_Rules__c: "EXCEPTION if case open"
Data Graph: unified profile       →    Verified_Field_Mappings_JSON__c: exact field map
Metric Definition: Qualified Lead →    Context_Tag__c: Enterprise | SMB (dynamic switch)
(read-only, global, static)            (action-aware, contextual, human-verified)
                                                          ↓
                                       AgentforceSemanticResolver (@InvocableMethod)
                                                          ↓
                                       Prompt Builder template injection at runtime
```

Two layers, one agent. Data Cloud answers **"what does this number mean?"**;
dc-semantic-layer answers **"what is the agent allowed to do with it?"**.
```
