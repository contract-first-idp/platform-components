# Validation

[Back to the repository overview](../README.md)

Run `make test` from the repository root. Its direct equivalent is `npm ci --prefix test` followed
by `npm test --prefix test`. All Node and Jest tooling is scoped under `test/`; the repository
itself is not an npm package. The suite checks shell syntax and the
platform target contract, exercises the workshop helper in a temporary repository with mocked
cluster discovery, and renders the GitOps operator, GitOps instance, inventory paths, and
repository-root Kustomizations with normal load restrictions.

Release-policy tests are intentionally excluded from the fast suite. `make release-check` runs
the fast suite, focused release tests, release-candidate validation, and the root render check.

The suite supports both the pristine upstream distribution, where root `catalog-info.yaml` has not
been generated, and a configured workshop fork where that file is committed. When present, the
root catalog is validated as the platform-target contract.

ApplicationSet expansion remains a live-controller verification because local validation does not
reimplement the OpenShift GitOps controller.

## Installation validation

These checks are optional after the workshop guide hands reconciliation to Argo CD. The generated
`catalog-info.yaml` remains the expected public state; compare live URLs with the descriptor rather
than deriving new expected values from cluster metadata.

Confirm that the ApplicationSet and its selected Applications exist, and that External Secrets are
converging:

```bash
oc get applicationsets.argoproj.io -n openshift-gitops
oc get applications.argoproj.io -n openshift-gitops
oc get externalsecrets.external-secrets.io -A
```

ApplicationSet expansion requires the live OpenShift GitOps controller, so it is intentionally not
part of local repository validation.

### Verify operands and public endpoints

`Synced` and `Healthy` Applications are necessary but are not sufficient evidence that the
platform is usable. Some operator-managed custom resources have no detailed Argo CD health
assessment. Inspect their workloads and status as well:

```bash
oc rollout status deployment/backstage-backstage -n developer-hub --timeout=10m
oc get deployments,statefulsets -n quay
oc get deployments,statefulsets -n apicurio
oc get deployments -n microcks
oc get deployments -n hawtio
oc get checluster devspaces -n openshift-devspaces \
  -o jsonpath='{.status.chePhase}{" "}{.status.cheURL}{"\n"}'
oc get keycloak cf-idp-keycloak -n cf-idp-keycloak \
  -o jsonpath='{.status.conditions}{"\n"}'
oc get keycloakrealmimport platform-realm -n cf-idp-keycloak \
  -o jsonpath='{.status.conditions}{"\n"}'
oc get jobs -n quay
```

Confirm desired replicas are available, Dev Spaces is `Active`, Keycloak is `Ready`, the realm
import is `Done`, and both `quay-initialize` and `quay-activate` completed successfully. All
ExternalSecrets must report `Ready=True`; their existence alone does not prove delivery.

Probe the URLs declared in `catalog-info.yaml` using normal TLS verification. Check Developer Hub,
Dev Spaces, Microcks, and the registry UI; check `<keycloak-url>/realms/platform/.well-known/openid-configuration`,
`<schema-registry-api-url>/system/info`, and `<quay-url>/health/instance`. For Hawtio, use
`https://<spec.platform.services.hawtio.host>` and compare it with the live Route hostname. Follow
expected authentication redirects. A healthy Deployment at a different hostname does not satisfy
the public target contract.

For example, after setting `SERVICE_URL` to an endpoint from the descriptor:

```bash
curl --fail --show-error --silent --location --output /dev/null "$SERVICE_URL"
```

Do not substitute `--insecure` for resolving a failed trust check. For environments with a private
router CA, supply the approved CA bundle with `--cacert`.

## GitHub App integrations

Developer Hub receives GitHub App installation credentials for platform automation. Confirm that
its ExternalSecret is ready, that the resulting Secret has the expected keys, and that the rollout
is available:

```bash
oc get externalsecret rhdh-secrets -n developer-hub
oc get secret rhdh-secrets -n developer-hub \
  -o go-template='{{range $key, $_ := .data}}{{printf "%s\\n" $key}}{{end}}'
oc rollout status deployment/backstage-backstage -n developer-hub --timeout=10m
```

The in-cluster integration also depends on the mounted Kubernetes CA:

```bash
oc exec deployment/backstage-backstage -n developer-hub -c backstage-backend -- \
  test -r /opt/app-root/src/kubernetes-ca/ca.crt
```

Sign in to Developer Hub through Keycloak using the configured demo-user credentials. Validate the
GitHub App path by confirming catalog discovery or running a golden path; GitHub is not the human
Developer Hub sign-in provider.

Confirm the platform target appears in the catalog and Software Templates originate from the
repository and immutable revision selected by `spec.platform.dependencies.softwareTemplates`.
An OIDC token issued directly by Keycloak does not by itself verify Developer Hub's sign-in
resolver: complete the portal login and confirm the expected catalog user identity. Also test
Kubernetes connectivity from the portal with its configured service-account token and mounted CA,
without logging the token.

Dev Spaces receives only the GitHub App client credentials for per-user authorization. Confirm its
ExternalSecret and Secret, then inspect the live URL:

```bash
oc get externalsecret github-oauth-config -n openshift-devspaces
oc get secret github-oauth-config -n openshift-devspaces \
  -o go-template='{{range $key, $_ := .data}}{{printf "%s\\n" $key}}{{end}}'
oc get checluster devspaces -n openshift-devspaces \
  -o jsonpath='{.status.cheURL}{"\n"}'
```

Compare that URL with `spec.platform.services.devSpaces.url` in `catalog-info.yaml`; the registered
callback must match `spec.platform.services.devSpaces.githubCallbackUrl`. Start a workspace from an
App-visible repository and confirm clone, pull, and push authorization without a personal access
token or a separate GitHub OAuth App.

## After Domain admission

Domain publisher identity is created during admission, so a platform-only installation cannot
validate it. After admitting a Domain, inspect both `<domain>-apicurio` and `<domain>-microcks`
clients and their Secret projections:

```bash
oc get keycloakoidcclients -n cf-idp-keycloak \
  -o custom-columns='NAME:.metadata.name,CONDITIONS:.status.conditions'
oc get externalsecrets -n cf-idp-keycloak
oc get externalsecrets -n <system-build-namespace>
```

The clients must have no `HasErrors=True` condition, and the build namespace's `apicurio-client`
and `microcks-client` ExternalSecrets must be Ready. Verify client-credentials authentication and
the expected publisher roles against the configured realm without printing credentials or tokens.
Successful secret projection alone does not prove Keycloak accepted the client. Check that runtime
namespaces do not receive these publisher credentials.

For Developer Hub startup failures involving migrations, see
[migration recovery](operations.md#developer-hub-initial-migration-recovery).
