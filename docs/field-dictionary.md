# Field dictionary — "Document control" site columns & "Controlled Document" content type

All columns live in the **"Document control"** site column group. The **"Controlled Document"** content type inherits from the built-in **Document** content type and carries every column below; it is set as the default content type on each process library.

| Display name | Internal name | Type | Choices / notes |
|---|---|---|---|
| Process area | `ZProcessArea` | Choice | "Area A", "Area B" (placeholders — update to real area names before go-live) |
| Document owner | `ZDocOwner` | Person | Single value |
| Approver | `ZApprover` | Person | Single value; used as the assignee in the approval flow |
| Document status | `ZDocStatus` | Choice | Draft / In review / Approved / Obsolete |
| Effective date | `ZEffectiveDate` | Date and Time | Date only; set by the approval flow on Approve |
| Review interval (months) | `ZReviewInterval` | Choice (number-backed) | e.g. 6, 12, 24, 36 — drives Next review date |
| Next review date | `ZNextReview` | Date and Time | Date only; set by the approval flow as `Effective date + Review interval` |
| Change description | `ZChangeDescription` | Multiple lines of text | Plain text, author-entered summary of what changed in this version |
| Obsolete date | `ZObsoleteDate` | Date and Time | Date only; set by the "Mark as obsolete" flow |
| Obsolete reason | `ZObsoleteReason` | Single line of text | Set by the "Mark as obsolete" flow or its approver |

Plus the built-in **Document ID** (from the Document ID Service feature) — not a custom column, but shown by default in libraries once the site collection feature is enabled.

## Content type

- **Name**: Controlled Document
- **Parent**: Document
- **Group**: Document control
- **Fields attached** (in display order): Process area, Document owner, Approver, Document status, Effective date, Review interval (months), Next review date, Change description, Obsolete date, Obsolete reason.
- Set as the **default content type** on Area A, Area B, and Obsolete libraries, with content types enabled on each library.

## Default view

Each process library gets a default view that:

- Filters out `Document status = Obsolete` (those files should already have moved to the Obsolete library, but this is a safety net).
- Shows columns: Document ID, Title, Document status, Version, Document owner, Approver, Effective date, Next review date.

The Obsolete library gets its own default view showing: Document ID, Title, Process area, Obsolete date, Obsolete reason, Document owner.
