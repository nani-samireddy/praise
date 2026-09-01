import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { buildSubmission, handleRequest } from '../src/worker.js';

describe('Praise support worker', () => {
  it('builds a song request submission safely', () => {
    const submission = buildSubmission(
      {
        kind: 'song_request',
        title: ' New Song ',
        lyricsOrSource: '@team https://example.test/song',
      },
      new Date('2026-09-01T10:20:30Z'),
    );

    assert.equal(submission.kind, 'song_request');
    assert.equal(submission.title, '[Song request] New Song');
    assert.equal(submission.fields[3][1], '@​team https://example.test/song');
  });

  it('rejects incomplete requests before calling Discord', async () => {
    const request = new Request('https://support.example.test/v1/issues', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind: 'problem_report', summary: 'Crash' }),
    });

    const response = await handleRequest(request, {});

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { message: 'description is required.' });
  });

  it('posts to Discord and returns a tracking link', async () => {
    const calls = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, init) => {
      calls.push({ url: String(url), init });
      return Response.json(
        {
          id: '1199999999999999999',
          channel_id: '222',
          guild_id: '111',
        },
        { status: 200 },
      );
    };

    try {
      const request = new Request('https://support.example.test/v1/issues', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '203.0.113.9' },
        body: JSON.stringify({
          kind: 'song_correction',
          songTitle: 'పాట',
          songId: 'csv-0001',
          correction: 'Fix line',
        }),
      });
      const response = await handleRequest(request, {
        DISCORD_WEBHOOK_URL:
          'https://discord.com/api/webhooks/123/token',
      });

      assert.equal(response.status, 201);
      assert.equal(calls.length, 1);
      assert.deepEqual(await response.json(), {
        number: 999999999,
        url: 'https://discord.com/channels/111/222/1199999999999999999',
      });
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('uses KV rate limiting when configured', async () => {
    const kv = {
      value: '3',
      async get() {
        return this.value;
      },
      async put() {
        throw new Error('put should not run after limit is reached');
      },
    };
    const request = new Request('https://support.example.test/v1/issues', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '203.0.113.9' },
      body: JSON.stringify({ kind: 'problem_report', summary: 'Crash', description: 'Details' }),
    });

    const response = await handleRequest(request, {
      RATE_LIMIT: kv,
      RATE_LIMIT_PER_HOUR: '3',
      DISCORD_WEBHOOK_URL: 'https://discord.com/api/webhooks/123/token',
    });

    assert.equal(response.status, 429);
  });

  it('rejects catalogue deploy without the AppSheet token', async () => {
    const request = new Request('https://support.example.test/v1/catalog/deploy', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ source: 'appsheet' }),
    });

    const response = await handleRequest(request, {
      APPSHEET_DEPLOY_TOKEN: 'deploy-secret',
      GITHUB_REPOSITORY: 'nani-samireddy/praise',
      GITHUB_DISPATCH_TOKEN: 'github-secret',
    });

    assert.equal(response.status, 401);
  });

  it('queues a catalogue deploy through GitHub repository dispatch', async () => {
    const calls = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, init) => {
      calls.push({ url: String(url), init });
      return new Response(null, { status: 204 });
    };

    try {
      const request = new Request('https://support.example.test/v1/catalog/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer deploy-secret',
        },
        body: JSON.stringify({
          source: 'appsheet',
          catalogue_version: '12',
          sheet_csv_url: 'https://docs.google.com/spreadsheets/d/example/export?format=csv',
        }),
      });

      const response = await handleRequest(request, {
        APPSHEET_DEPLOY_TOKEN: 'deploy-secret',
        GITHUB_REPOSITORY: 'nani-samireddy/praise',
        GITHUB_DISPATCH_TOKEN: 'github-secret',
      });

      assert.equal(response.status, 202);
      assert.deepEqual(await response.json(), {
        status: 'queued',
        eventType: 'catalog_deploy',
      });
      assert.equal(
        calls[0].url,
        'https://api.github.com/repos/nani-samireddy/praise/dispatches',
      );
      assert.equal(calls[0].init.headers.Authorization, 'Bearer github-secret');
      assert.deepEqual(JSON.parse(calls[0].init.body), {
        event_type: 'catalog_deploy',
        client_payload: {
          source: 'appsheet',
          catalogue_version: '12',
          sheet_csv_url: 'https://docs.google.com/spreadsheets/d/example/export?format=csv',
        },
      });
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('rejects non-HTTPS sheet URLs in catalogue deploy requests', async () => {
    const request = new Request('https://support.example.test/v1/catalog/deploy', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Praise-Deploy-Token': 'deploy-secret',
      },
      body: JSON.stringify({ sheet_csv_url: 'http://example.test/songs.csv' }),
    });

    const response = await handleRequest(request, {
      APPSHEET_DEPLOY_TOKEN: 'deploy-secret',
      GITHUB_REPOSITORY: 'nani-samireddy/praise',
      GITHUB_DISPATCH_TOKEN: 'github-secret',
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), {
      message: 'sheet_csv_url must use HTTPS.',
    });
  });
});
