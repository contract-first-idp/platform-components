const YAML = require('yaml');
const path = require('node:path');
const {repositoryRoot} = require('./helpers/paths');
const {render} = require('./helpers/manifests');

test('Developer Hub verifies Kubernetes TLS using its mounted cluster CA', () => {
  const resources = render(repositoryRoot, 'components/developer-hub');
  const backstage = resources.find(item => item.kind === 'Backstage');
  const config = resources.find(item => item.kind === 'ConfigMap' &&
    item.metadata.name === 'app-config-rhdh');
  const appConfig = YAML.parse(config.data['app-config-rhdh.yaml']);
  const cluster = appConfig.kubernetes.clusterLocatorMethods[0].clusters[0];
  const files = backstage.spec.application.extraFiles;
  const ca = files.configMaps.find(item => item.name === 'kube-root-ca.crt');
  expect(ca.key).toBe('ca.crt');
  expect(cluster.caFile).toBe(path.posix.join(files.mountPath, ca.key));
  expect(cluster.skipTLSVerify).toBe(false);
  expect(backstage.spec.application.extraEnvs.envs).toContainEqual({
    name: 'NODE_EXTRA_CA_CERTS',
    value: cluster.caFile,
  });
  expect(backstage.spec.application.extraEnvs.envs || []).not.toContainEqual(
    expect.objectContaining({name: 'NODE_TLS_REJECT_UNAUTHORIZED', value: '0'}));
});
