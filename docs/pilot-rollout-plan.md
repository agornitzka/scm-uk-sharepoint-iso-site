# Pilot rollout plan

## Build order

1. **App registration** — run `Register-ISOPocAppRegistration.ps1`, get admin consent (see `app-registration.md`).
2. **Site, columns, content type, libraries** — run `Provision-ISOPocSite.ps1`.
3. **Permissions and security groups** — create the four Entra security groups per area (if not already created by step 2's script) and confirm membership with the customer.
4. **Word/document templates** — out of scope for this pass; add Document ID/version/owner/effective date via Quick Parts → Document Property fields if/when requested.
5. **Approval flow** — build in Power Automate from `scripts/power-automate/flow-send-for-approval.md`.
6. **Review reminder flow** — build from `scripts/power-automate/flow-review-reminder.md`.
7. **Obsolete flow** — build from `scripts/power-automate/flow-mark-obsolete.md`.
8. **Test run** — one author + one approver per area (see checklist below) before the customer goes live.

## Open items to agree with the customer before switching on automation

- Real names for "Area A" and "Area B" (and whether exactly two areas, or more, are in the actual pilot).
- The real document field list — is the set in `field-dictionary.md` complete, or does Scanmetals need additional fields (e.g. a regulatory reference number, a language field)?
- Review intervals per area/document type (6/12/24/36 months — currently a placeholder choice list).
- Who are the actual Document owners and Approvers per area, and do approvers need "First to respond" or "Everyone must approve" semantics?
- Who is the QA manager that overdue reviews escalate to?
- Which account will run the Power Automate flows (should be a dedicated service account, not a named employee's personal account).
- Confirm current M365 licensing (E3/Business assumed here) — if the tenant has or will get E5/Purview, the retention-label step can be added to the obsolete flow later.

## Acceptance checklist (test run)

- [ ] Author can upload a new document into their area library and it lands as Draft (`0.1`), invisible to Readers.
- [ ] Author can click "Send for approval"; the Approver receives an approval request.
- [ ] Approver approving the file results in: Document status = Approved, Effective date and Next review date populated correctly, version becomes `1.0`, and the file is now visible to Readers.
- [ ] Approver rejecting the file results in: Document status stays non-Approved, author is notified with comments, no metadata is incorrectly stamped.
- [ ] A test document with `Next review date` inside the next 30 days triggers the Monday reminder email/Teams message to its owner.
- [ ] A test document with an overdue `Next review date` triggers the escalation to the QA manager.
- [ ] Running "Mark as obsolete" on an approved document moves it (not copies it) into the Obsolete library, preserves its version history, and sets Obsolete date/reason.
- [ ] Readers cannot see or edit items in the Obsolete library (or only QA can, per the agreed model).
- [ ] A user outside the `SP-ISOPOC-*` groups for an area cannot open that area's library at all.
- [ ] Document IDs (`ZEN-ISOPOC-00xx`) survive the move to Obsolete.

Only after this checklist passes for both pilot areas should the customer be shown the pilot for go/no-go on wider rollout.
