# UK ISO PoC — Architecture

Pilot of a controlled-documents / QMS setup in SharePoint Online for Scanmetals, covering two UK process areas before wider rollout. Built entirely on standard SharePoint Online + Power Automate (Microsoft 365 Business/E3), except the obsolete-archive record-lock option, which needs Purview retention labels (E5) and is out of scope for this pilot.

## 1. Site and library structure

One dedicated site, **"UK ISO PoC"**. Each pilot process area gets its own document library; one shared **Obsolete** library holds retired documents from all areas.

```
UK ISO PoC (site)
├── Area A (document library)       ← process area 1 (placeholder name)
├── Area B (document library)       ← process area 2 (placeholder name)
└── Obsolete (document library)     ← shared, read-only for most users
```

Separate libraries per process area keep permissions and approvers simple — a single library split into folders gets messy once approvers differ between areas, and folder/item-level permissions don't scale or audit well.

## 2. Versioning and approval

Set on **every process library** (Area A, Area B — not Obsolete) under Library Settings → Versioning:

| Setting | Value |
|---|---|
| Require content approval | **Yes** — readers only ever see approved (major) versions |
| Versioning | Create major and minor (draft) versions — drafts are 0.1, 0.2…; approved publish becomes 1.0, 2.0 |
| Draft item security | Only users who can approve items (and the author) — hides drafts from readers |
| Major version limit | 50 |
| Minor version limit | 10 |
| Require check-out | No (optional for the pilot — strict control vs. co-authoring friction; skip unless the customer insists) |

## 3. Document metadata

**Site columns** (group: "Document control") and a **"Controlled Document" content type** (parent: Document), set as the default content type on every process library. See `field-dictionary.md` for the full column spec.

The **Document ID Service** site collection feature is enabled so every document gets a permanent ID (e.g. `ZEN-ISOPOC-0001`) that survives moves — important since the obsolete flow moves files between libraries.

## 4. Approval flow

Power Automate flow, **"For a selected file"** trigger (gives authors a "Send for approval" button in the library — a flow triggered on "modified" tends to loop against content approval).

```
Author clicks "Send for approval"
        │
        ▼
1. Get file properties
        │
        ▼
2. Set content approval status → Submit (Pending)
        │
        ▼
3. Start and wait for an approval (assigned to the Approver column)
        │
   ┌────┴────┐
   ▼         ▼
Approved   Rejected
   │         │
   ▼         ▼
4a. Update file properties:         4b. Set content approval
    Status = Approved                   status → Reject
    Effective date = utcNow()           (with approver comments)
    Next review date =                      │
      addToTime(utcNow(), <interval>,       ▼
      'Month')                         Notify author
   │
   ▼
4c. Get file properties (fresh ETag)
   │
   ▼
4d. Set content approval status → Approve
    (approver comments + fresh ETag)
```

**Ordering matters**: updating metadata on an already-approved item resets it to Pending, so every field update (4a) happens *before* the final Approve (4d), using an ETag refreshed just before the approve call. Run the flow under a service account, not a personal user, so it survives staff changes.

## 5. Review reminders

A **scheduled flow** (Recurrence — e.g. every Monday), one pass per process library:

1. **Get files (properties only)**, filtered with an OData query:
   `DocumentStatus eq 'Approved' and NextReviewDate le '@{addDays(utcNow(),30)}'`
2. For each result, email/Teams-message the Document owner with a link.
3. A second filter run for genuinely overdue items (`NextReviewDate le utcNow()`) escalates to the QA manager.

Built-in SharePoint "Rules"/"Set a reminder" don't fit — they're per-user or change-triggered, not scheduled across a filtered set. A scheduled flow is the reliable approach.

## 6. Obsolete archive

A second flow, **"Mark as obsolete"** (For a selected file trigger, optionally gated behind its own approval):

1. Update Status = Obsolete, set obsolete date and reason.
2. **Move** the file to the Obsolete library (a move preserves version history; a copy does not).
3. The Obsolete library is read-only for most users, or restricted to QA only, via its own permission break.

**Out of scope for this pilot**: applying a Purview retention label to lock the document as an immutable record. That needs E5/Purview; Scanmetals is on E3/Business. If the tenant is later upgraded, add a step after (2) that applies the retention label — everything else in this design is unaffected.

## 7. Permissions by security group

Entra security groups, one set per pilot area plus two tenant-wide groups:

| Group | Permission level | Scope |
|---|---|---|
| `SP-ISOPOC-<Area>-Authors` | Contribute (or Edit) | per area library |
| `SP-ISOPOC-<Area>-Approvers` | **Approve** (required for content approval) | per area library |
| `SP-ISOPOC-Readers` | Read | all libraries (or "all employees") |
| `SP-ISOPOC-Admins` | Full Control | site |

Permission inheritance is broken **at the library level only** — never at folder or item level, since that doesn't scale and makes auditing painful. Default inherited SharePoint groups are removed from each library after the custom groups are applied.

## 8. Authentication for provisioning

Provisioning runs **app-only**, via a dedicated Entra app registration (`Zentura-ISOPoC-Provisioning`) authenticated with a self-signed certificate — no interactive/delegated login, so the script is repeatable and doesn't depend on any one person's session. See `app-registration.md` for the exact Graph application permissions and the admin-consent step required before the site-provisioning script can connect.

## Suggested pilot order

Site, columns, content type, libraries → permissions and security groups → approval flow → review reminder flow → obsolete flow → test run with one author and one approver per area, before the customer goes live. See `pilot-rollout-plan.md` for the detailed checklist. This sequence also gives a natural point to agree the real field list, approvers, and review intervals with the customer before anything is automated.
