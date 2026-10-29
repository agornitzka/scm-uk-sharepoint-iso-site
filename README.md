# UK ISO PoC — SharePoint Controlled Documents Pilot

Design and provisioning kit for a SharePoint Online pilot of a controlled-documents / QMS setup for Scanmetals, covering two UK process areas ("Area A" and "Area B" placeholders — rename before go-live).

This repo contains:

- **`docs/`** — the architecture, field dictionary, app-registration, and pilot rollout plan.
- **`scripts/provisioning/`** — PnP PowerShell scripts that build the Entra app registration and then the SharePoint site itself.
- **`scripts/power-automate/`** — step-by-step specs for the three Power Automate flows (approval, review reminder, obsolete archive), to be rebuilt by hand in Power Automate (these are designs, not importable flow packages).

## Prerequisites

- **PnP.PowerShell** module (`Install-Module PnP.PowerShell -Scope CurrentUser`).
- An Entra account with rights to **create app registrations** (Application Administrator, Cloud Application Administrator, or Global Administrator) to run step 1.
- An Entra account with rights to **grant admin consent** on the app's API permissions (Global Administrator or Privileged Role Administrator), unless the account running step 1 already holds that role.
- A SharePoint **Online admin** or site collection admin account to approve the app's access to the target site (or a SharePoint Administrator role to run `Grant-PnPAzureADAppSitePermission` / set the site-scoped app permission policy).
- Power Automate: a per-user or per-flow plan if the approval flow's "Start and wait for an approval" / HTTP actions require premium connectors in your tenant (check your license — standard SharePoint/Approvals connectors are usually included, but verify).

## Run order

1. **`scripts/provisioning/Register-ISOPocAppRegistration.ps1`** — run **once**. Creates the Entra app registration, generates a self-signed certificate, and assigns the Microsoft Graph application permissions (see `docs/app-registration.md`). Writes the resulting Application (client) ID, tenant ID, and certificate thumbprint into `Provision.config.psd1`.
   - Admin consent is **always a manual step** afterward — a Global/Privileged Role Administrator must grant it in the Entra admin center (steps in `docs/app-registration.md`). Provisioning will fail until this is done.
2. **`scripts/provisioning/Provision-ISOPocSite.ps1`** — run after consent is granted. Connects app-only (certificate, no interactive login) and provisions the site: columns, content type, libraries, versioning/approval settings, permissions, and views.
3. Build the three Power Automate flows by hand using the specs in `scripts/power-automate/`.
4. Follow `docs/pilot-rollout-plan.md` for the agreed build/test sequence and the acceptance checklist before the customer goes live.

## Scope notes

- Licensing assumed: **E3 / Business**. The obsolete-archive retention-label (record-lock) step is intentionally **not** included — see `docs/architecture.md` §6 and `docs/pilot-rollout-plan.md` for the E5 upgrade path.
- "Area A" / "Area B" are placeholders throughout config and docs. Replace with the real UK process area names once agreed with the customer (`Provision.config.psd1` is the single place to change them for the provisioning script).
- Nothing in this repo has been run against a live tenant from this session — these are deliverables for Zentura/Scanmetals to execute.
