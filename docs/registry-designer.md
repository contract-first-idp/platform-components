# Registry Designer authoring

The existing Apicurio Registry 3 UI includes Designer when
`spec.app.features.versionMutabilityEnabled: true`. The installed Registry Operator CRD
supports this field. It enables content edits for DRAFT versions only, not finalized
versions. This platform does not enable `resourceDeleteEnabled`.

Open the existing Registry UI (the `spec.ui.ingress.host` on the deployed
`ApicurioRegistry3`), sign in through the existing platform Keycloak, and use Designer
with an authorized developer or administrator account. Create an AsyncAPI draft in a
separate authoring group rather than editing pipeline-owned contracts. Save iterative
changes as drafts. Version compatibility must be checked against the deployed editor;
being able to store an AsyncAPI document does not prove visual-editor support.

Git remains authoritative. Export/download the authored document, review it in the
appropriate API repository, and use the existing validation and publication pipeline.
Do not finalize Designer drafts into the governed release lifecycle or add automatic
publication from drafts. This change adds no publication automation or role changes.

## Removing the standalone installation

The standalone designer and operator manifests have been removed. Targets that added
them to their ApplicationSet must also remove those entries.
Because it uses `applicationsSync: create-update` and `preserveResourcesOnDeletion: true`,
existing installations require explicit cleanup after the root reconciles. Verify the
legacy namespace contains only the retired designer before deleting anything. Remove
the two obsolete Argo Applications without cascading deletion; delete the standalone
custom resource while its operator is still running, then remove its Subscription,
installed CSV, and dedicated namespace. Remove its cluster-scoped CRD and any remaining
operator-owned RBAC only after confirming no other instances or installations use them.
Do not change the ApplicationSet deletion policy or remove Apicurio Registry resources.

Reference: [Operator feature configuration](https://www.apicur.io/registry/docs/apicurio-registry/3.1.x/getting-started/assembly-operator-config-reference.html).

## Live verification and AsyncAPI compatibility (2026-10-20)

Verified with Operator `apicurio-registry-3.v3.2.6-r2` and Registry
`3.2.6.redhat-00001`, using normal HTTPS certificate validation and the existing
Keycloak user. Open the configured Registry UI at `/dashboard`,
then **Drafts → Create draft**. Choose an authoring group, draft ID/version, and
**AsyncAPI**. The wizard offers a blank AsyncAPI **2.6** template or a local-file
upload. Create the draft, edit it, then save. The embedded **Source** editor has
its own Save control; use the outer Registry **Save** to persist the draft.

| Check | Observed result |
|---|---|
| AsyncAPI 2.6 | Uploaded through the draft wizard, rendered the channel correctly, edited the title in Source, saved, and confirmed persisted content through the authenticated API. |
| AsyncAPI 3.1.0 storage | Uploaded through the same wizard and stored as `ASYNCAPI`, state `DRAFT`. |
| AsyncAPI 3.1.0 source edit | Replacing the entire Source document and saving a title edit preserved every field semantically, including server host/protocol, channel address/messages, operation action/channel/message references, and payload schema. |
| AsyncAPI 3.1.0 visual editing/reopening | **Not supported reliably in this deployed editor.** Both initial open and reopening the saved draft showed “No API Title”, no channels/messages, and Source containing only `asyncapi: 2.0.0`. Operations and the 3.1 model were not represented. “Issues(0)” did not detect the failure. |

Do **not** use this Designer for governed AsyncAPI 3.1 authoring or save its empty
fallback model. The successful source-only save is not evidence of full 3.1 support.
Continue authoring 3.1 in Git with the existing validation tools and publication pipeline.
An editor upgrade and repeat compatibility testing are outstanding; this change does not
upgrade Registry or change existing contracts to 2.x. Additional 3.1 features beyond the
probe above were not tested and are not claimed supported.

Two isolated verification artifacts remain in group `designer-verification`:
`asyncapi-26-authoring` and `asyncapi-31-authoring`, both version `draft-1` in DRAFT
state. Neither was finalized or published into a governed group. They are retained as
reproduction fixtures; unrestricted deletion was not enabled to remove them.

All 10 pre-existing published versions retained their content and state. An identical-content
PUT against a finalized version returned HTTP 409: “Requested artifact version is not in
DRAFT state. Update disallowed.” Authenticated Registry API access and anonymous system
information access both worked. A before/after comparison of the live Registry spec showed
only the intended feature addition; authentication, database configuration, ingress, UI
configuration, and API endpoints remained unchanged.

All 43 repository tests passed, including rendering every remaining ApplicationSet entry.
All 33 remaining Argo Applications reconciled Synced/Healthy; Registry backend, UI, and
PostgreSQL pods were Ready. The retired applications, custom resource, operator subscription,
CSV, namespace, CRD, operator-owned cluster RBAC, and empty OLM Operator tracking object were
explicitly removed. The shared ApplicationSet deletion policy was preserved.
