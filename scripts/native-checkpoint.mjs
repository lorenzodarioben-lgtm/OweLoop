import assert from 'node:assert/strict';

// Shared bounded marker protocol; never include raw app logs in an error.
export async function waitForCheckpoint(readLog, phase, expected, {
  timeoutMs = 90000, pollMs = 1000,
} = {}) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const log = readLog();
    const failure = log.match(/OWELOOP_PROBE:FAIL:[A-Za-z0-9_:]+/);
    assert.ok(!failure, `Native probe rejected phase ${phase}: ${failure?.[0] || ''}`);
    if (log.includes(`OWELOOP_PROBE:${expected}`)) return;
    await new Promise(resolve => setTimeout(resolve, pollMs));
  }
  throw Error(`Native checkpoint timed out: ${phase}`);
}
