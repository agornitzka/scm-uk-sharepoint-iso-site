# App registration for provisioning

Site provisioning (`Provision-ISOPocSite.ps1`) runs **unattended, app-only** rather than under anyone's personal interactive session, so the setup is repeatable (same script can later provision Area C, D… without depending on one person's delegated token) and leaves a clear audit trail (actions show up under the app's identity, not a mix of personal accounts).

## Why application permissions, not delegated

Delegated permissions only work while a signed-in user is present (interactive or refresh-token flow). Certificate-based app-only auth has no signed-in user, so the app registration needs **Application** permissions, consented once by a tenant admin, rather than Delegated permissions that are consented per-user.

## Required Microsoft Graph application permissions

| Permission | Type | Why |
|---|---|---|
| `Sites.FullControl.All` | Application | Create/modify the site, libraries, content types, versioning settings, and break/assign permissions. SharePoint app-only provisioning needs full control, not just read/write, because it manages permissions and site structure, not just list items. |
| `Group.Read.All` | Application | Resolve the `SP-ISOPOC-*` Entra security groups by name to object IDs so the script can assign them as library principals. (Only needed if the provisioning script looks groups up by display name rather than being given object IDs directly in `Provision.config.psd1`.) |

Both are **Application** (not Delegated) permission type when added in the Entra app registration's "API permissions" blade.

> If the tenant restricts `Sites.FullControl.All` to specific sites via the SharePoint application access policy (`Set-SPOApplicationAccessPolicy` / the newer site-scoped app permissions), you can instead scope the app to only the "UK ISO PoC" site rather than every site in the tenant. This is the safer production option once the pilot is proven — see `pilot-rollout-plan.md`.

## Admin consent

Application permissions require **admin consent** — a one-time grant by a **Global Administrator** or **Privileged Role Administrator**. The `Register-PnPEntraIDApp` cmdlet (aliased as `Register-PnPAzureADApp`) does **not** have a dedicated switch to grant consent automatically — it only creates the app registration, certificate, and requested permissions. Consent is always a manual step:

1. In the Entra admin center, go to **Identity → Applications → App registrations**, find `Zentura-ISOPoC-Provisioning`.
2. Open **API permissions** and confirm `Sites.FullControl.All` and `Group.Read.All` (Application) are listed.
3. Click **Grant admin consent for \<tenant\>** and confirm.

Provisioning will fail with a 401/403 until this step is done, even though the app registration and certificate already exist.

## Certificate

`Register-ISOPocAppRegistration.ps1` calls `Register-PnPEntraIDApp` (alias `Register-PnPAzureADApp`), which generates a self-signed certificate and exports:

- `ISOPoC-Provisioning.pfx` — private key, password-protected (`-CertificatePassword`), used to connect.
- `ISOPoC-Provisioning.cer` — public key, uploaded to the app registration automatically by the cmdlet.

Both are written to the path given by `-OutPath`, which the script points at a local `secrets/` folder excluded by `.gitignore` — **never commit these files**. Validity defaults to the cmdlet's own default (`-ValidYears`, capped at 30; the script pins it to 2 years for the pilot). Store the `.pfx` password and the certificate thumbprint securely (e.g. a password manager); on Windows, `-Store CurrentUser` also imports the certificate into the local certificate store so `Connect-PnPOnline -Thumbprint` can use it without reopening the `.pfx`.

## Rotation

Before the certificate's `-ValidYears` validity expires, generate a **new** certificate and attach it to the **existing** app registration rather than creating a second app (re-running `Register-PnPEntraIDApp` with the same `-ApplicationName` creates a separate app object, which would need its own consent). The exact cmdlet for adding a certificate to an existing registration depends on the installed PnP PowerShell version — check `Get-Command -Module PnP.PowerShell -Noun *EntraIDApp*,*AzureCertificate*` for what's available, or add the new `.cer` manually under **Certificates & secrets** on the existing app registration in the Entra portal, then update the thumbprint in `Provision.config.psd1`.
