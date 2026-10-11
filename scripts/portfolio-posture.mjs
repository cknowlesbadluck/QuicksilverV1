// portfolio-posture.mjs — pure fail-closed classifier for cross-plane posture.
// No I/O, no secrets. Classifier tests are not production proof.

/**
 * Classify a readiness body (or probe result) into a posture.
 * @param {object} body - parsed JSON from /ready or /health
 * @param {object} meta - { httpCode, service, timedOut }
 * @returns {string} one of: owner_gate | deploy_lag | alias_absent | device_not_recorded | cold_start | ready | unknown
 */
export function classifyPosture(body = {}, meta = {}) {
  const { httpCode = 0, service = '', timedOut = false } = meta;

  if (timedOut || httpCode === 0) return 'cold_start';

  if (httpCode === 404) return 'alias_absent';

  if (!body || typeof body !== 'object') return 'unknown';

  // Resonance owner gate
  if (service.includes('resonance') || body.service === 'resonance-nexus') {
    if (body.status === 'not_ready' && Array.isArray(body.missingRequired) && body.missingRequired.includes('SUPABASE_SERVICE_ROLE_KEY')) {
      return 'owner_gate';
    }
    if (body.status === 'not_ready' && !body.contractRevision) return 'deploy_lag';
  }

  // Conduit ready
  if (body.status === 'ready' && body.contractRevision && body.persistence === 'postgres') {
    return 'ready';
  }

  // Device fence (Quicksilver gateway)
  if (body.deviceAcceptance === 'not_recorded' || body.acceptanceGate === 'CHR-55') {
    return 'device_not_recorded';
  }

  if (body.status === 'ready') return 'ready';

  return 'unknown';
}

// Simple self-test (node scripts/portfolio-posture.mjs)
if (import.meta.url === `file://${process.argv[1]}`) {
  const cases = [
    [{ status: 'not_ready', missingRequired: ['SUPABASE_SERVICE_ROLE_KEY'] }, { service: 'resonance' }, 'owner_gate'],
    [{ status: 'ready', contractRevision: 'x', persistence: 'postgres' }, {}, 'ready'],
    [{ deviceAcceptance: 'not_recorded' }, {}, 'device_not_recorded'],
    [{}, { httpCode: 0, timedOut: true }, 'cold_start'],
    [{}, { httpCode: 404 }, 'alias_absent'],
  ];
  let passed = 0;
  for (const [b, m, expected] of cases) {
    const got = classifyPosture(b, m);
    if (got === expected) passed++;
    else console.error('FAIL', expected, got);
  }
  console.log(`${passed}/${cases.length} posture cases passed`);
  if (passed !== cases.length) process.exit(1);
}
