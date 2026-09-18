# dc-semantic-layer

> **Hybrid Semantic Layer for Agentforce — covering DLO and DMO with Human-in-the-Loop**
> Agentforce + Data Cloud · Salesforce DX · API v66.0

---

## What it does

`dc-semantic-layer` provides a **Hybrid Semantic Layer** that covers both:
- **DLO (Data Lake Object)** — raw ingested data needing mapping to a business model
- **DMO (Data Model Object)** — unified profile entities (Individual, Sales Order, …) needing actionable guardrails

The AI proposes semantic mappings; a human steward reviews, overrides (JSON or **natural language**), and approves before the definition reaches Agentforce at runtime.

```
Data Cloud DLO
      │
      ▼
DataCloudDiscoveryService          ← samples rows + schema via REST
      │
      ▼
AgentforceSemanticInferenceAction  ← @InvocableMethod → Prompt Builder
      │
      ▼
Semantic_Proposal__c               ← AI draft, status = Draft
      │
      ▼
semanticStewardWorkspace (LWC)     ← HITL: Approve / Reject / Override
      │
      ▼
Semantic_Registry__c               ← verified, status = Active
      │
      ▼
AgentforceSemanticResolver         ← @InvocableMethod → injects mappings at runtime
```

---

## Why this exists — the 3 structural limits of Data Cloud semantics

Data Cloud has Calculated Insights, Data Graphs, Tableau Semantics, and Metric Definitions.
They are excellent for analytics. But when you deploy autonomous Agentforce agents into
real business processes, you hit three hard walls:

| # | Limit | Example gap |
|---|---|---|
| 1 | **Static, read-only definitions** | Data Cloud can define "churn risk > 80%". It cannot express "but do NOT send a discount offer if the customer has an active CRM claim" |
| 2 | **No write-back guardrails** | Agent correctly identifies Opportunity as Closed-Won. CRM's validation rules reject the write. Agent loops. Data Cloud has no concept of pre-execution constraints. |
| 3 | **No stateful context switching** | "Qualified Lead" means ARR ≥ ¥50M for Enterprise agents, ARR < ¥10M for SMB agents. Data Cloud's global Metric Definition cannot serve both. |

**dc-semantic-layer** adds the operational semantic layer on top of Data Cloud's analytic
layer — storing action guardrails, write-back preconditions, and context-aware definitions
as human-verified records in `Semantic_Registry__c`, injected into Prompt Builder at
runtime via `AgentforceSemanticResolver`.

→ See [`docs/prompt-builder-template.md`](docs/prompt-builder-template.md) for the full template and per-pain-point resolution.

---

## Token efficiency

Grounding Agentforce with raw DLO schema is expensive. This project integrates with
[dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) to compress
context before it reaches the LLM.

| Payload                        | Chars  | Est. tokens | vs raw schema |
|-------------------------------|--------|-------------|---------------|
| Raw DLO schema (full)         | ~6,400 | ~1,600      | baseline      |
| Tier-1 summary index          | ~180   | ~45         | **-97%**      |
| Tier-2 field mappings (YAML)  | ~960   | ~240        | **-85%**      |

Use `AgentforceSemanticResolver` to inject only verified Tier-2 mappings at runtime,
and `dc-agentforce-proxy`'s `DataCloudContextCompressor` to truncate safely for both
English and Japanese payloads.

---

## Project structure

```
force-app/main/default/
├── classes/
│   ├── DataCloudDiscoveryService.cls          # DLO sampler + schema fetcher
│   ├── AgentforceSemanticInferenceAction.cls  # Invocable: infer mappings
│   ├── SemanticStewardController.cls          # AuraEnabled: LWC backend
│   ├── AgentforceSemanticResolver.cls         # Invocable: resolve at runtime
│   └── *Test.cls (×4)
├── lwc/
│   └── semanticStewardWorkspace/              # HITL review UI
├── objects/
│   ├── Semantic_Proposal__c/                  # AI draft proposals
│   └── Semantic_Registry__c/                  # Human-verified registry
└── namedCredentials/
    └── DataCloud_Named_Credential             # OAuth → Data Cloud tenant
```

---

## Pain point samples

Seed the 3 scenarios above as live `Semantic_Registry__c` records:

```bash
# 1. Deploy the package
sf project deploy start --source-dir force-app --target-org <alias>

# 2. Seed registry with 3 pain point examples (churn guardrail, opp write-back, Enterprise/SMB)
sf apex run --file scripts/apex/seedPainPointSamples.apex --target-org <alias>

# 3. Verify all resolve correctly
sf apex run --file scripts/apex/verifyPainPointSamples.apex --target-org <alias>
```

Expected verify output:
```
PAIN POINT 1: Action Guardrails
  PASS: PP1 found=true
  PASS: PP1 guardrail contains EXCEPTION
  PASS: PP1 guardrail routes to human agent
PAIN POINT 2: Write-back Guardrails
  PASS: PP2 check Edit permission
  PASS: PP2 no auto-retry rule
PAIN POINT 3a: Enterprise Context
  PASS: PP3-E requires MEDDIC
PAIN POINT 3b: SMB Context
  PASS: PP3-S self-serve trial
ISOLATION: Enterprise context must not leak SMB rules
  PASS: Enterprise rules do not contain SMB content
RESULT: 18 passed, 0 failed
```

---

## Quick start

### 1. Named Credential

Go to **Setup > Named Credentials** and configure `DataCloud_Named_Credential`:

| Field     | Value                                          |
|-----------|------------------------------------------------|
| Label     | DataCloud Named Credential                     |
| Name      | DataCloud_Named_Credential                     |
| URL       | `https://<your-tenant>.salesforce.com`         |
| Auth      | OAuth 2.0 (Connected App with Data Cloud scope)|

### 2. Deploy

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

### 3. Register in Agentforce

- **Infer action**: Add `AgentforceSemanticInferenceAction.infer` as an Agentforce Action in Prompt Builder
- **Resolve action**: Add `AgentforceSemanticResolver.resolve` as a second action to inject verified mappings

### 4. Add LWC to an App Page

Drag **Semantic Steward Workspace** onto any Lightning App Page via the App Builder.

---

## Custom objects

### `Semantic_Proposal__c` — AI drafts

| Field                    | Type          | Notes                         |
|--------------------------|---------------|-------------------------------|
| DLO_Name__c              | Text(255)     | Source DLO or DMO API name    |
| Entity_Type__c           | Picklist      | **DLO** / **DMO**             |
| Suggested_DMO__c         | Text(255)     | AI-inferred target DMO        |
| Confidence_Score__c      | Number(3,2)   | 0.00–1.00                     |
| Proposed_Mappings_JSON__c| LongTextArea  | Raw JSON field map            |
| Sample_Data_Payload__c   | LongTextArea  | Up to 5 sample rows           |
| Status__c                | Picklist      | Draft / Approved / Rejected   |

### `Semantic_Registry__c` — verified mappings

| Field                          | Type          | Notes                                           |
|-------------------------------|---------------|-------------------------------------------------|
| Entity_Name__c                 | Text(255)     | DLO or DMO API name                             |
| Entity_Type__c                 | Picklist      | **DLO** / **DMO**                               |
| Target_DMO__c                  | Text(255)     | Verified DMO target                             |
| Verified_Field_Mappings_JSON__c| LongTextArea  | Human-approved JSON map                         |
| Business_Logic_Rules__c        | LongTextArea  | **Natural language notes** from the steward     |
| Status__c                      | Picklist      | Active / Deprecated                             |
| Verified_By__c                 | Lookup(User)  | Who approved it                                 |

---

## Tests

```bash
sf apex run test --test-level RunLocalTests --target-org <alias> --result-format human
```

Expected: **24 tests, 0 failures**

| Class                                | Tests | Covers                                             |
|--------------------------------------|-------|----------------------------------------------------|
| DataCloudDiscoveryServiceTest        | 8     | DLO + DMO callouts, error handling, aliases        |
| AgentforceSemanticInferenceActionTest| 5     | DLO + DMO inference, defaults, error path          |
| SemanticStewardControllerTest        | 5     | Approve (DLO+DMO), natural language notes, reject  |
| AgentforceSemanticResolverTest       | 8     | Pain Point 1/2/3, context isolation, batch resolve |

---

## Related

- [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) — token compression middleware for Data Cloud + Agentforce, with Japanese language support (bigram matching, full-width normalization, sentence-boundary truncation)
