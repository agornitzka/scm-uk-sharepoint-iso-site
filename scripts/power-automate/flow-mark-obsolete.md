# Flow: Mark as obsolete

Retires an approved document into the shared Obsolete library, preserving its version history and audit trail.

**Trigger**: *For a selected file* (SharePoint), available on the process libraries (Area A, Area B). Optionally gate it behind its own lightweight approval step (e.g. QA sign-off) if the customer wants obsoletion itself to be a controlled action — recommended for a pilot, since retiring the wrong document is hard to notice until someone goes looking for it.

**Run as**: the same dedicated service/flow account as the other flows.

## Steps

1. **Get file properties** (SharePoint).

2. *(Optional)* **Start and wait for an approval** — QA sign-off that this document should be retired. Skip for the pilot if the customer wants a simpler flow; add later if obsoletions need their own audit trail.

3. **Update file properties** (SharePoint):
   - `ZDocStatus` = `Obsolete`
   - `ZObsoleteDate` = `utcNow()`
   - `ZObsoleteReason` = a value collected via the approval step's response, or a simple input the author/QA provides when starting the flow (e.g. a Power Automate "ask in flow" input if triggered manually, or a fixed reason field passed from the selected-file trigger's custom properties).

4. **Move file** (SharePoint) → destination: the **Obsolete** library.
   - A *move* (not copy) is required — it's the only operation that preserves version history and the Document ID across the library boundary. Confirm the destination path exists before running in production.

5. *(Optional)* **Send an email/Teams message** to the Document owner confirming the document has been retired, with a link to its new location in Obsolete.

## Notes

- The Obsolete library has **no content approval** enabled (see `docs/architecture.md` §6) — items land there already carrying their final `Approved`→`Obsolete` status history from their version log.
- **Out of scope for this pilot**: applying a Purview retention label to lock the document as an immutable record, since Scanmetals is on E3/Business, not E5. If the tenant is later upgraded, add an **Apply a label** (or **Set a retention label**, depending on the available connector) step after step 4, pointed at a label scoped to the Obsolete library.
- Permissions on the Obsolete library (read-only for most users, or QA-only) are set once at provisioning time by `Provision-ISOPocSite.ps1` — this flow doesn't need to touch permissions per-document.
