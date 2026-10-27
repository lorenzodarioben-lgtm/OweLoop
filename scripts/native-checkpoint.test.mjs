import {test} from 'node:test';
import assert from 'node:assert/strict';
import {waitForCheckpoint} from './native-checkpoint.mjs';

test('withheld marker times out without exposing private logs', async () => {
  await assert.rejects(waitForCheckpoint(() => 'private payload', 'draft', 'WAIT:draft',
    {timeoutMs: 15, pollMs: 1}), {message: 'Native checkpoint timed out: draft'});
});
test('rejects sanitized failure and accepts only the expected checkpoint', async () => {
  await assert.rejects(waitForCheckpoint(() => 'private\nOWELOOP_PROBE:FAIL:draft:StateError',
    'draft', 'WAIT:draft'), {message: 'Native probe rejected phase draft: OWELOOP_PROBE:FAIL:draft:StateError'});
  let polls = 0;
  await waitForCheckpoint(() => ++polls === 1 ? 'OWELOOP_PROBE:WAIT:before' : 'OWELOOP_PROBE:WAIT:draft',
    'draft', 'WAIT:draft', {timeoutMs: 100, pollMs: 1});
  assert.equal(polls, 2);
});
