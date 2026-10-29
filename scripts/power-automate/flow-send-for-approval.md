# Flow: Send for approval

Gives authors a "Send for approval" button on a file in a process library (Area A, Area B). One flow, used by both libraries (scope it to both, or clone per library if approvers' notification needs diverge).

**Trigger**: *For a selected file* (SharePoint). Trigger on "modified" is deliberately avoided — it loops against the content-approval status changes this flow itself makes.

**Run as**: a dedicated service/flow account (e.g. `svc-isopoc-flows@scanmetals...`), not a named employee, so the flow isn't broken by staff turnover and so approval actions are attributable to "the system" rather than one person's identity.

## Steps

1. **Get file properties** (SharePoint)
   - Site Address: the site; Library Name: the triggering library; Id: `triggerBody()?['ItemId']` (from the "for a selected file" trigger).

2. **Set content approval status** (SharePoint) → `Submit`
   - Moves the item from Draft to Pending.

3. **Start and wait for an approval** (Approvals connector)
   - Approval type: *First to respond* (or *Everyone must approve* if the customer wants more than one approver per document type — confirm in the pilot acceptance step).
   - Assigned to: `outputs('Get_file_properties')?['body/Approver/Email']` (the `ZApprover` person field, email claim).
   - Title: `concat('Approve: ', outputs('Get_file_properties')?['body/{FilenameWithExtension}'])`.

4. **Condition**: `outcome` equals `Approve`

### If yes (approved)

   a. **Update file properties** (SharePoint) — do this *before* the final approve step below, because updating metadata on an already-approved item resets its approval status back to Pending:
      - `ZDocStatus` = `Approved`
      - `ZEffectiveDate` = `utcNow()`
      - `ZNextReview` = `addToTime(utcNow(), int(outputs('Get_file_properties')?['body/ZReviewInterval/Value']), 'Month')`

   b. **Get file properties** (SharePoint) again — refresh the ETag, since step (a) changed it.

   c. **Set content approval status** (SharePoint) → `Approve`
      - Comment: the approver's comments from step 3's output (`body('Start_and_wait_for_an_approval')?['responses'][0]['comments']`).
      - Use the **ETag from step (b)**, not from step 1 — an approve call with a stale ETag fails or silently reverts.

### If no (rejected)

   a. **Set content approval status** (SharePoint) → `Reject`
      - Comment: the approver's rejection comments.

   b. **Send an email / Teams message** to the author (`ZDocOwner`) with the rejection comments and a link back to the item.

## Notes

- The **Approver** permission level (required for `Set content approval status`) must already be granted to the `SP-ISOPOC-<Area>-Approvers` group on the library — `Provision-ISOPocSite.ps1` does this.
- If the customer later wants multi-stage approval (e.g. author's manager, then QA), add a second "Start and wait for an approval" step between 3 and 4, assigned to the second approver, before updating metadata.
