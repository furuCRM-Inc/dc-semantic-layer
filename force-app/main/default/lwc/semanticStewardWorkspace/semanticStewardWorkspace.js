import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDraftProposals from '@salesforce/apex/SemanticStewardController.getDraftProposals';
import approveProposal  from '@salesforce/apex/SemanticStewardController.approveProposal';
import rejectProposal   from '@salesforce/apex/SemanticStewardController.rejectProposal';

export default class SemanticStewardWorkspace extends LightningElement {
    @track proposals    = [];
    @track isLoading    = false;
    @track errorMessage = '';

    _wiredResult;
    // keyed by proposalId → { mappingOverride, naturalLanguageNotes }
    _edits = {};

    @wire(getDraftProposals)
    wiredProposals(result) {
        this._wiredResult = result;
        if (result.data) {
            this.proposals = result.data.map(p => ({
                ...p,
                confidencePct: p.Confidence_Score__c != null
                    ? Math.round(p.Confidence_Score__c * 100) + '%'
                    : 'N/A'
            }));
            this.errorMessage = '';
        } else if (result.error) {
            this.errorMessage = result.error.body?.message ?? 'Failed to load proposals.';
        }
    }

    get hasProposals() { return this.proposals.length > 0; }
    get isEmpty()      { return !this.isLoading && this.proposals.length === 0 && !this.errorMessage; }
    get hasError()     { return Boolean(this.errorMessage); }
    get proposalCount(){ return this.proposals.length; }

    handleFieldChange(event) {
        const proposalId = event.target.dataset.id;
        const field      = event.target.dataset.field;
        if (!this._edits[proposalId]) this._edits[proposalId] = {};
        this._edits[proposalId][field] = event.detail.value;
    }

    async handleApprove(event) {
        const proposalId = event.target.dataset.id;
        const edits      = this._edits[proposalId] ?? {};
        this.isLoading   = true;
        try {
            await approveProposal({
                proposalId,
                verifiedMappingsJson  : edits.mappingOverride      ?? null,
                naturalLanguageNotes  : edits.naturalLanguageNotes ?? null
            });
            this._dispatchToast('Approved', 'Proposal approved and added to Semantic Registry.', 'success');
            delete this._edits[proposalId];
            await refreshApex(this._wiredResult);
        } catch (err) {
            this._dispatchToast('Error', err.body?.message ?? 'Approval failed.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleReject(event) {
        const proposalId = event.target.dataset.id;
        this.isLoading   = true;
        try {
            await rejectProposal({ proposalId, rejectionReason: '' });
            this._dispatchToast('Rejected', 'Proposal has been rejected.', 'warning');
            await refreshApex(this._wiredResult);
        } catch (err) {
            this._dispatchToast('Error', err.body?.message ?? 'Rejection failed.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    _dispatchToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
