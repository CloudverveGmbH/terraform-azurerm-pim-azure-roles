# pim-azure-role [![CI](https://github.com/CloudverveGmbH/terraform-azurerm-pim-azure-role/actions/workflows/ci.yml/badge.svg)](https://github.com/CloudverveGmbH/terraform-azurerm-pim-azure-role/actions/workflows/ci.yml)

A reusable Terraform module that implements just-in-time access to Azure RBAC
roles using Microsoft Entra Privileged Identity Management (PIM).

## Concept

The module creates two Entra ID security groups per role:

```
pim-<slug>-eligible   ← members are added here (normal group membership)
        │
        │  PIM eligibility schedule
        ▼
pim-<slug>            ← holds the Azure RBAC role assignment(s)
        │
        │  azurerm_role_assignment
        ▼
  Azure Resource (e.g. AKS cluster, subscription, resource group)
```

**Why two groups?**
Separating _who can activate_ from _who is currently active_ keeps the privileged
group clean: it only contains users who have explicitly activated for a limited time
window. Adding or removing people from the eligible group is a plain Entra group
operation — no `terraform apply` needed per joiner/leaver.

**Group naming** is derived automatically from `group_display_name`:
- `"AKS Cluster Admin"` → groups `pim-aks-cluster-admin` and `pim-aks-cluster-admin-eligible`

**Approver type inference:** passing an `object_id` without a `type` field causes the
module to look up the Entra directory object and set `groupMembers` for groups or
`singleUser` for users automatically.

**Circular-dependency pattern:** when a resource references `group_id` before it exists
(e.g. AKS `admin_group_object_ids`), set `role_assignments = []` and create the
`azurerm_role_assignment` externally after the cluster is provisioned.

## Requirements

| Requirement | Details |
|---|---|
| Terraform | >= 1.9 |
| hashicorp/azuread | >= 3.0 |
| hashicorp/azurerm | >= 4.0 |
| hashicorp/time | >= 0.10 |
| Entra licence | Microsoft Entra ID P2 or Entra ID Governance |
| Terraform principal permissions | `Privileged Role Administrator` or `Group Administrator` + role assignment write on target scope |

### Microsoft Graph API permissions (Application, not Delegated)

The Terraform SPN requires the following **Application** permissions on the Microsoft Graph API:

| Permission | Reason |
|---|---|
| `Application.ReadWrite.OwnedBy` | Update owned app registrations (e.g. adding group owners) |
| `Group.Create` | Create the Eligible and Privileged security groups |
| `Group.Read.All` | Read existing groups to detect duplicates and resolve members |
| `RoleManagement.ReadWrite.Directory` | Manage PIM eligibility schedules and role management policies |
| `User.ReadBasic.All` | Resolve user objects for approver type inference |

## Usage

### Minimal – self-activation, no approval

```hcl
module "aks_admin_pim" {
  source  = "CloudverveGmbH/pim-azure-role/azurerm"
  version = "~> 0.1"

  group_display_name = "AKS Cluster Admin"

  members = [
    { object_id = data.azuread_user.alice.object_id, display_name = "Alice" },
  ]

  role_assignments = [{
    scope                = azurerm_kubernetes_cluster.aks.id
    role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
    name                 = "aks-cluster-admin"
  }]
}
```

### With approval by a specific user

```hcl
module "subscription_owner_pim" {
  source  = "CloudverveGmbH/pim-azure-role/azurerm"
  version = "~> 0.1"

  group_display_name          = "Subscription Owner"
  maximum_activation_duration = "PT4H"

  members = [
    { object_id = data.azuread_user.bob.object_id, display_name = "Bob" },
  ]

  # type is inferred automatically – no need to specify "singleUser"
  approvers = [
    { object_id = data.azuread_user.alice.object_id },
  ]

  role_assignments = [{
    scope                = "/subscriptions/${var.subscription_id}"
    role_definition_name = "Owner"
    name                 = "subscription-owner"
  }]
}
```

### With approval by a group

```hcl
approvers = [
  { object_id = azuread_group.managers.object_id }  # type "groupMembers" inferred automatically
]
```

### Circular-dependency pattern (e.g. AKS)

When a resource must reference the group before the cluster exists:

```hcl
module "aks_admin_pim" {
  source             = "CloudverveGmbH/pim-azure-role/azurerm"
  version            = "~> 0.1"
  group_display_name = "AKS Cluster Admin"
  members            = [{ object_id = data.azuread_user.alice.object_id, display_name = "Alice" }]
  role_assignments   = []   # ← leave empty here
}

resource "azurerm_kubernetes_cluster" "aks" {
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [module.aks_admin_pim.group_id]
  }
}

# Create the assignment after the cluster exists
resource "azurerm_role_assignment" "aks_admin_pim" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = module.aks_admin_pim.group_id
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `group_display_name` | `string` | — | Base name; groups `pim-<slug>` and `pim-<slug>-eligible` are created |
| `group_owners` | `list(string)` | `[]` | Additional owner object IDs (Terraform SPN is always added) |
| `members` | `list(object)` | `[]` | Initial members of the Eligible group (`object_id`, optional `display_name`) |
| `approvers` | `list(object)` | `[]` | PIM approvers (`object_id`, optional `type`); when set, approval is required on activation |
| `require_justification` | `bool` | `true` | Require a business justification on activation (independent of approval) |
| `maximum_activation_duration` | `string` | `"PT8H"` | ISO 8601 duration (e.g. `"PT1H"`, `"PT8H"`, `"P1D"`) |
| `eligibility_years` | `number` | `1` | Validity of the eligibility schedule in years |
| `role_assignments` | `list(object)` | `[]` | Azure RBAC assignments on the Privileged group (`scope`, `role_definition_name`, optional `name`) |

## Outputs

| Name | Description |
|---|---|
| `eligible_group_id` | Object ID of the Eligible group |
| `eligible_group_name` | Display name of the Eligible group (`pim-<slug>-eligible`) |
| `privileged_group_id` | Object ID of the Privileged group |
| `privileged_group_name` | Display name of the Privileged group (`pim-<slug>`) |
| `group_id` | Alias for `privileged_group_id` (backward-compatible) |
| `principal_id` | Alias for `privileged_group_id` |
| `role_assignment_ids` | Map of Azure RBAC role assignment IDs, keyed by assignment name |
| `resolved_approvers` | Approvers with their resolved PIM type after auto-inference |

---

# pim-azure-role (Deutsch)

Wiederverwendbares Terraform-Modul für Just-in-Time-Zugriff auf Azure-RBAC-Rollen
mit Microsoft Entra Privileged Identity Management (PIM).

## Konzept

Das Modul erstellt pro Rolle zwei Entra-ID-Sicherheitsgruppen:

```
pim-<slug>-eligible   ← Mitglieder werden hier eingetragen (normale Gruppenmitgliedschaft)
        │
        │  PIM-Eligibility-Schedule
        ▼
pim-<slug>            ← hält die Azure-RBAC-Rollenzuweisung(en)
        │
        │  azurerm_role_assignment
        ▼
  Azure-Ressource (z. B. AKS-Cluster, Subscription, Resource Group)
```

**Warum zwei Gruppen?**
Die Trennung von _wer aktivieren darf_ und _wer gerade aktiv ist_ hält die
privilegierte Gruppe sauber: Sie enthält nur User, die sich explizit für ein
begrenztes Zeitfenster aktiviert haben. Personen in der Eligible-Gruppe hinzuzufügen
oder zu entfernen ist eine einfache Entra-Gruppenoperation — kein `terraform apply`
pro Neueinsteiger oder Ausscheider erforderlich.

**Gruppennamensgebung** wird automatisch aus `group_display_name` abgeleitet:
- `"AKS Cluster Admin"` → Gruppen `pim-aks-cluster-admin` und `pim-aks-cluster-admin-eligible`

**Approver-Typ-Inferenz:** Wird ein `object_id` ohne `type` übergeben, schaut das Modul
das Entra-Directory-Objekt nach und setzt automatisch `groupMembers` für Gruppen bzw.
`singleUser` für Einzelpersonen.

**Circular-Dependency-Pattern:** Wenn eine Ressource `group_id` benötigt, bevor sie
selbst existiert (z. B. AKS `admin_group_object_ids`), `role_assignments = []` setzen
und die `azurerm_role_assignment` extern nach dem Cluster anlegen.

## Voraussetzungen

| Anforderung | Details |
|---|---|
| Terraform | >= 1.9 |
| hashicorp/azuread | >= 3.0 |
| hashicorp/azurerm | >= 4.0 |
| hashicorp/time | >= 0.10 |
| Entra-Lizenz | Microsoft Entra ID P2 oder Entra ID Governance |
| Terraform-Principal-Rechte | `Privileged Role Administrator` oder `Group Administrator` + Rollenzuweisungsrechte auf dem Ziel-Scope |

### Microsoft Graph API-Berechtigungen (Application, nicht Delegated)

Der Terraform-SPN benötigt folgende **Application**-Berechtigungen auf der Microsoft Graph API:

| Berechtigung | Grund |
|---|---|
| `Application.ReadWrite.OwnedBy` | Eigene App-Registrierungen aktualisieren (z. B. Gruppenbesitzer hinzufügen) |
| `Group.Create` | Eligible- und Privileged-Sicherheitsgruppen erstellen |
| `Group.Read.All` | Vorhandene Gruppen lesen (Duplikaterkennung, Member-Auflösung) |
| `RoleManagement.ReadWrite.Directory` | PIM-Eligibility-Schedules und Rollenmanagement-Richtlinien verwalten |
| `User.ReadBasic.All` | User-Objekte für die automatische Approver-Typ-Erkennung auflösen |

## Verwendung

### Minimal – Selbstaktivierung, keine Genehmigung

```hcl
module "aks_admin_pim" {
  source  = "CloudverveGmbH/pim-azure-role/azurerm"
  version = "~> 0.1"

  group_display_name = "AKS Cluster Admin"

  members = [
    { object_id = data.azuread_user.alice.object_id, display_name = "Alice" },
  ]

  role_assignments = [{
    scope                = azurerm_kubernetes_cluster.aks.id
    role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
    name                 = "aks-cluster-admin"
  }]
}
```

### Mit Genehmigung durch eine Person

```hcl
approvers = [
  { object_id = data.azuread_user.alice.object_id }  # Typ wird automatisch als "singleUser" erkannt
]
```

### Mit Genehmigung durch eine Gruppe

```hcl
approvers = [
  { object_id = azuread_group.managers.object_id }  # Typ wird automatisch als "groupMembers" erkannt
]
```

## Eingabevariablen

| Name | Typ | Standard | Beschreibung |
|---|---|---|---|
| `group_display_name` | `string` | — | Basisname; Gruppen `pim-<slug>` und `pim-<slug>-eligible` werden erstellt |
| `group_owners` | `list(string)` | `[]` | Zusätzliche Owner-Object-IDs (Terraform-SPN wird immer ergänzt) |
| `members` | `list(object)` | `[]` | Initiale Mitglieder der Eligible-Gruppe (`object_id`, optionaler `display_name`) |
| `approvers` | `list(object)` | `[]` | PIM-Genehmiger (`object_id`, optionaler `type`); wenn gesetzt, ist Genehmigung bei Aktivierung Pflicht |
| `require_justification` | `bool` | `true` | Begründung bei Aktivierung erforderlich (unabhängig von Genehmigung) |
| `maximum_activation_duration` | `string` | `"PT8H"` | ISO-8601-Dauer (z. B. `"PT1H"`, `"PT8H"`, `"P1D"`) |
| `eligibility_years` | `number` | `1` | Gültigkeit des Eligibility-Schedules in Jahren |
| `role_assignments` | `list(object)` | `[]` | Azure-RBAC-Zuweisungen auf der Privileged-Gruppe (`scope`, `role_definition_name`, optionaler `name`) |

## Ausgaben

| Name | Beschreibung |
|---|---|
| `eligible_group_id` | Object-ID der Eligible-Gruppe |
| `eligible_group_name` | Anzeigename der Eligible-Gruppe (`pim-<slug>-eligible`) |
| `privileged_group_id` | Object-ID der Privileged-Gruppe |
| `privileged_group_name` | Anzeigename der Privileged-Gruppe (`pim-<slug>`) |
| `group_id` | Alias für `privileged_group_id` (abwärtskompatibel) |
| `principal_id` | Alias für `privileged_group_id` |
| `role_assignment_ids` | Map der Azure-RBAC-Rollenzuweisungs-IDs, keyed nach Zuweisungsname |
| `resolved_approvers` | Genehmiger mit aufgelöstem PIM-Typ nach Auto-Inferenz |

## Beitragen

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für den PR-, Changelog- und Release-Prozess.