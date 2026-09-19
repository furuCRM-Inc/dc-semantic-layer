# dc-semantic-layer

> **The operational semantic layer Data Cloud is missing.**
> Agentforce reads the numbers. This package tells it what to *do* with them.

---

## The problem

Salesforce Data Cloud has Calculated Insights, Data Graphs, Tableau Semantics, and Metric Definitions. They are excellent for analytics. But when you put an autonomous Agentforce agent into a real business process, you hit three hard walls — every time.

### Wall 1 — Definitions are read-only. Agents need guardrails.

Data Cloud can define: *"churn risk score > 80%"*

What it cannot define: *"but do NOT send a discount offer if the customer has an open support case"*

The analytic layer answers **what the number means**. It has no concept of **what the agent is allowed to do with it**.

### Wall 2 — No write-back preconditions.

An agent correctly identifies an Opportunity as Closed-Won from Data Cloud signals.
It calls the CRM API. The CRM's validation rule rejects the write.
The agent retries. Loops. Pages someone at 3am.

Data Cloud's semantic layer has no concept of **pre-execution constraints** — the checklist that must pass before a write is safe.

### Wall 3 — One metric definition, many agent contexts.

"Qualified Lead" in Data Cloud is a single global Metric Definition.
An Enterprise agent needs ARR ≥ ¥50M and a MEDDIC scorecard.
An SMB agent needs ARR < ¥10M and a self-serve trial check.

The static data model cannot serve both agents from the same entity at runtime.

---

## The solution

```
Data Cloud (Analytic Semantic)          dc-semantic-layer (Operational Semantic)
──────────────────────────────          ─────────────────────────────────────────
Calculated Insight: churn score    →    Business_Logic_Rules__c:
                                          "EXCEPTION: if CRM case is open,
                                           route to human — no auto-discount"

Metric Definition: Qualified Lead  →    Context_Tag__c = Enterprise
                                          "ARR ≥ ¥50M, MEDDIC required"
                                        Context_Tag__c = SMB
                                          "ARR < ¥10M, self-serve trial first"

Data Graph: Opportunity signal     →    Pre-execution checklist:
                                          "Verify CloseDate, Amount > 0,
                                           Edit permission, no open approval.
                                           On failure → create Task, no retry."

(read-only · global · static)           (action-aware · contextual · human-verified)
                                                         ↓
                                         AgentforceSemanticResolver
                                         (@InvocableMethod → Prompt Builder)
```

**Two layers. One agent. Data Cloud answers "what?" — dc-semantic-layer answers "how?" and "when?"**

---

## Architecture

```
Data Cloud DLO / DMO
        │
        ▼
DataCloudDiscoveryService          ← samples rows + schema via REST API v66
        │
        ▼
AgentforceSemanticInferenceAction  ← @InvocableMethod → Prompt Builder (grounding)
        │
        ▼
Semantic_Proposal__c               ← AI draft  [Status: Draft]
        │
        ▼
semanticStewardWorkspace (LWC)     ← Human-in-the-Loop: Approve / Reject / Override
                                     • JSON mapping override
                                     • Natural language business logic notes
        │
        ▼
Semantic_Registry__c               ← Verified entry  [Status: Active]
                                     • Entity_Type__c  (DLO | DMO)
                                     • Context_Tag__c  (Enterprise | SMB | JP | ...)
                                     • Business_Logic_Rules__c  (plain text guardrails)
        │
        ▼
AgentforceSemanticResolver         ← @InvocableMethod → runtime injection into Prompt Builder
```

---

## What's deployed

| Layer | Component | Purpose |
|---|---|---|
| Data | `DataCloudDiscoveryService` | Sample DLO/DMO rows + fetch schema via Data Cloud REST |
| Action | `AgentforceSemanticInferenceAction` | Grounding JSON → Prompt Builder |
| HITL | `SemanticStewardController` | AuraEnabled: getDrafts / approve (with NL notes) / reject |
| Action | `AgentforceSemanticResolver` | Context-aware runtime mapping injection |
| LWC | `semanticStewardWorkspace` | Review UI with JSON override + natural language notes field |
| Object | `Semantic_Proposal__c` | AI drafts (Draft → Approved / Rejected) |
| Object | `Semantic_Registry__c` | Human-verified registry (Active / Deprecated) |
| PermSet | `Semantic_Layer_Admin` | FLS for all custom fields on both objects |

---

## Verified on Dev02 — 3 pain points, 22 checks

```
=== PAIN POINT 1: Action Guardrails ===
  PASS: PP1 found=true
  PASS: PP1 entityType=DMO
  PASS: PP1 guardrail contains EXCEPTION
  PASS: PP1 guardrail routes to human agent
  PASS: PP1 mapping has ChurnScore field

=== PAIN POINT 2: Write-back Guardrails ===
  PASS: PP2 check CloseDate
  PASS: PP2 check Edit permission
  PASS: PP2 no auto-retry rule
  PASS: PP2 mapping has StageName

=== PAIN POINT 3a: Enterprise Context ===
  PASS: PP3-E contextTag=Enterprise
  PASS: PP3-E ARR threshold 50M
  PASS: PP3-E requires MEDDIC

=== PAIN POINT 3b: SMB Context ===
  PASS: PP3-S contextTag=SMB
  PASS: PP3-S ARR threshold 10M
  PASS: PP3-S self-serve trial

=== ISOLATION: Enterprise context must not leak SMB rules ===
  PASS: Enterprise rules do not contain SMB content

RESULT: 22 passed, 0 failed
```

---

## Token efficiency

Grounding Agentforce with raw DLO/DMO schema is expensive.
Combine this package with [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) to compress context before it hits the LLM.

| Payload | Chars | Est. tokens | Reduction |
|---|---|---|---|
| Raw DLO schema (full) | ~6,400 | ~1,600 | baseline |
| Tier-2 verified mappings (YAML) | ~960 | ~240 | **-85%** |
| Tier-1 summary index | ~180 | ~45 | **-97%** |

`dc-agentforce-proxy` also adds Japanese language support: bigram keyword matching, full-width normalization, sentence-boundary truncation.

---

## Quick start

### 1. Deploy

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

### 2. Assign the Permission Set

```bash
sf org assign permset --name Semantic_Layer_Admin --target-org <alias>
```

### 3. Seed the 3 pain point examples (optional)

```bash
sf apex run --file scripts/apex/seedPainPointSamples.apex --target-org <alias>
sf apex run --file scripts/apex/verifyPainPointSamples.apex --target-org <alias>
```

Expected: `RESULT: 22 passed, 0 failed`

### 4. Configure the Named Credential

Setup > Named Credentials > `DataCloud_Named_Credential`

| Field | Value |
|---|---|
| URL | `https://<your-tenant>.salesforce.com` |
| Auth | OAuth 2.0 (Connected App with Data Cloud scope) |

### 5. Register Agentforce Actions

In Agentforce Agent Builder, add two Actions:

| Action | Method | When to call |
|---|---|---|
| **Infer Semantic Mapping** | `AgentforceSemanticInferenceAction.infer` | When grounding with a new DLO/DMO |
| **Resolve Semantic Mapping** | `AgentforceSemanticResolver.resolve` | At runtime, before every action on a Data Cloud entity |

### 6. Add the LWC to an App Page

Drag **Semantic Steward Workspace** onto any Lightning App Page via App Builder.

---

## Custom objects

### `Semantic_Proposal__c` — AI drafts

| Field | Type | Notes |
|---|---|---|
| `DLO_Name__c` | Text(255) | Source DLO or DMO API name |
| `Entity_Type__c` | Picklist | **DLO** / **DMO** |
| `Suggested_DMO__c` | Text(255) | AI-inferred target DMO |
| `Confidence_Score__c` | Number(3,2) | 0.00–1.00 |
| `Proposed_Mappings_JSON__c` | LongTextArea | Raw JSON field map |
| `Sample_Data_Payload__c` | LongTextArea | Up to 5 sample rows |
| `Status__c` | Picklist | Draft / Approved / Rejected |

### `Semantic_Registry__c` — verified definitions

| Field | Type | Notes |
|---|---|---|
| `Entity_Name__c` | Text(255) | DLO or DMO API name |
| `Entity_Type__c` | Picklist | **DLO** / **DMO** |
| `Context_Tag__c` | Text(100) | Agent context: `Enterprise`, `SMB`, `JP`, … |
| `Target_DMO__c` | Text(255) | Verified DMO target |
| `Verified_Field_Mappings_JSON__c` | LongTextArea | Human-approved JSON map |
| `Business_Logic_Rules__c` | LongTextArea | **Natural language guardrails** — injected into Prompt Builder at runtime |
| `Status__c` | Picklist | Active / Deprecated |
| `Verified_By__c` | Lookup(User) | Who approved it |

The same `Entity_Name__c` can have multiple Active entries with different `Context_Tag__c` values. `AgentforceSemanticResolver` picks the exact-match tag, falls back to the untagged global entry.

---

## Prompt Builder integration

See [`docs/prompt-builder-template.md`](docs/prompt-builder-template.md) for the full template.

The key injection pattern:

```
### Business Logic Rules and Action Guardrails
{!$Invocable:AgentforceSemanticResolver.businessLogicRules}
```

The LLM reads `businessLogicRules` as hard constraints — EXCEPTION clauses, pre-execution checklists, routing rules. It does not invent logic that isn't there.

---

## Tests

```bash
sf apex run test --test-level RunLocalTests --target-org <alias> --result-format human --wait 10
```

| Class | Tests | Covers |
|---|---|---|
| `DataCloudDiscoveryServiceTest` | 8 | DLO + DMO callouts, error paths, backwards-compat aliases |
| `AgentforceSemanticInferenceActionTest` | 5 | DLO + DMO inference, type default, cap at 5, error path |
| `SemanticStewardControllerTest` | 6 | Approve DLO, approve DMO, NL notes, fallback mapping, reject, exclude non-draft |
| `AgentforceSemanticResolverTest` | 8 | Pain Point 1/2/3, context isolation, type filter, batch resolve |
| **Total** | **27** | |

---

## Related

- [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) — token compression middleware for Data Cloud + Agentforce (EN + JA). Use alongside this package to compress `Verified_Field_Mappings_JSON__c` and `Business_Logic_Rules__c` before they hit the LLM context window.
