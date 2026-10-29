# Flow: Review reminder

Weekly scheduled flow that nudges document owners ahead of their review date, and escalates genuinely overdue documents. Not built on SharePoint's built-in "Rules"/alerts, because those are per-user or change-triggered rather than a scheduled sweep over a filtered set.

**Trigger**: *Recurrence* — weekly, e.g. every Monday 07:00 (customer's local time zone).

**Run as**: the same dedicated service/flow account as the approval flow.

## Steps (repeat the block below once per process library — Area A, Area B)

1. **Get files (properties only)** (SharePoint), Library Name = the area library.
   - Filter Query (OData):
     `DocumentStatus eq 'Approved' and NextReviewDate le '@{addDays(utcNow(), 30)}'`
   - (Internal names: `ZDocStatus eq 'Approved' and ZNextReview le '@{addDays(utcNow(),30)}'` — use the actual internal column names as they appear in the Get files OData filter, which may require `substringof`/date-formatting depending on the connector version; verify against the live library's field names when building this.)

2. **Apply to each** file in the results:

   a. **Condition**: `ZNextReview` le `utcNow()` → **overdue** branch, else → **upcoming** branch.

   - **Upcoming branch**: send an email/Teams message to `ZDocOwner` — "Document '<name>' is due for review by <ZNextReview>" with a link to the item.
   - **Overdue branch**: send an email/Teams message to `ZDocOwner` **and** to the QA manager (a fixed address or a config value, not hardcoded per-flow-run) — "Document '<name>' is OVERDUE for review (was due <ZNextReview>)" with a link.

## Notes

- Keep the 30-day lead time and the escalation threshold as flow variables set at the top of the flow, not hardcoded inline, so they can be tuned per the pilot without editing every action.
- If volumes grow, consider batching the notification into a single digest email per owner instead of one email per document — out of scope for the pilot, but worth flagging to the customer once real document counts are known.
- The QA manager's address is one of the "open items to agree with the customer" in `docs/pilot-rollout-plan.md`.
