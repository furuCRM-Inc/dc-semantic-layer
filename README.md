# dc-semantic-layer

> **Data Cloud Native AI Semantic Layer with Human-in-the-Loop**
> Agentforce + Data Cloud · Salesforce DX · API v66.0

---

## What it does

`dc-semantic-layer` closes the gap between raw Data Cloud DLOs and Agentforce-ready business context. The AI proposes semantic mappings; a human steward reviews them before they reach production.

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
| DLO_Name__c              | Text(255)     | Source DLO API name           |
| Suggested_DMO__c         | Text(255)     | AI-inferred target DMO        |
| Confidence_Score__c      | Number(3,2)   | 0.00–1.00                     |
| Proposed_Mappings_JSON__c| LongTextArea  | Raw JSON field map            |
| Sample_Data_Payload__c   | LongTextArea  | Up to 5 sample rows           |
| Status__c                | Picklist      | Draft / Approved / Rejected   |

### `Semantic_Registry__c` — verified mappings

| Field                          | Type          | Notes                     |
|-------------------------------|---------------|---------------------------|
| Entity_Name__c                 | Text(255)     | DLO API name              |
| Target_DMO__c                  | Text(255)     | Verified DMO target       |
| Verified_Field_Mappings_JSON__c| LongTextArea  | Human-approved JSON map   |
| Business_Logic_Rules__c        | LongTextArea  | Free-form logic notes     |
| Status__c                      | Picklist      | Active / Deprecated       |
| Verified_By__c                 | Lookup(User)  | Who approved it           |

---

## Tests

```bash
sf apex run test --test-level RunLocalTests --target-org <alias> --result-format human
```

Expected: **18 tests, 0 failures**

| Class                                | Tests |
|--------------------------------------|-------|
| DataCloudDiscoveryServiceTest        | 5     |
| AgentforceSemanticInferenceActionTest| 4     |
| SemanticStewardControllerTest        | 5     |
| AgentforceSemanticResolverTest       | 4     |

---

## Related

- [dc-agentforce-proxy](https://github.com/furuCRM-Inc/dc-agentforce-proxy) — token compression middleware for Data Cloud + Agentforce, with Japanese language support (bigram matching, full-width normalization, sentence-boundary truncation)
