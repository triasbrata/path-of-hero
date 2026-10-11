// Where the probes write their shots and read their saves (docs/testing.md "Probes"): POH_PROBE_ROOT, given as
// `--dart-define=POH_PROBE_ROOT=<folder>`, else a folder in the system's temp.
const probeRoot = String.fromEnvironment('POH_PROBE_ROOT', defaultValue: '/tmp/poh-probes');
