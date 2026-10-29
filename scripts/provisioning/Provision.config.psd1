@{
    # Tenant / app-only connection — filled in by Register-ISOPocAppRegistration.ps1,
    # or set by hand if the app registration already exists.
    TenantId              = ''
    ClientId              = ''
    CertificateThumbprint = ''

    # Target site
    SiteUrl   = 'https://<tenant>.sharepoint.com/sites/UKISOPoC'
    SiteTitle = 'UK ISO PoC'

    # Pilot process areas — placeholders, rename before go-live.
    # Each becomes one document library plus three Entra security groups
    # (<Area>-Authors, <Area>-Approvers, plus the shared Readers/Admins groups below).
    ProcessAreas = @('Area A', 'Area B')

    ObsoleteLibraryName = 'Obsolete'

    # Entra security group object IDs (GUIDs). Populate after creating the groups
    # (see docs/architecture.md §7) — one Authors/Approvers pair per process area,
    # plus one shared Readers and one shared Admins group.
    SecurityGroups = @{
        Readers = ''   # SP-ISOPOC-Readers
        Admins  = ''   # SP-ISOPOC-Admins
        Areas   = @{
            'Area A' = @{ Authors = ''; Approvers = '' }   # SP-ISOPOC-AreaA-Authors / -Approvers
            'Area B' = @{ Authors = ''; Approvers = '' }   # SP-ISOPOC-AreaB-Authors / -Approvers
        }
    }

    # Versioning / approval settings (see docs/architecture.md §2)
    MajorVersionLimit = 50
    MinorVersionLimit = 10

    # Document control site column group name
    FieldGroup = 'Document control'
}
