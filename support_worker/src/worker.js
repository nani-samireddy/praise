const MAX_REQUEST_BYTES = 16_384;
const DEFAULT_RATE_LIMIT_PER_HOUR = 3;
const RATE_LIMIT_TTL_SECONDS = 3600;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env = {}) {
  const url = new URL(request.url);

  if (request.method === 'OPTIONS') {
    return emptyResponse(204);
  }

  if (request.method === 'GET' && url.pathname === '/health') {
    return jsonResponse({ status: 'ok' });
  }

  if (request.method !== 'POST' || url.pathname !== '/v1/issues') {
    return jsonResponse({ message: 'Not found.' }, 404);
  }

  try {
    await enforceRateLimit(request, env);
    const payload = await readJsonPayload(request);
    const submission = buildSubmission(payload);
    const discord = await postDiscordSubmission(submission, env);
    const number = messageNumber(discord.id, submission.id);
    const trackingUrl =
      discord.url || env.PUBLIC_TRACKING_URL || 'https://discord.com';
    return jsonResponse({ number, url: trackingUrl }, 201);
  } catch (error) {
    if (error instanceof SubmissionError) {
      return jsonResponse({ message: error.message }, error.status);
    }
    return jsonResponse({ message: 'Could not submit right now. Try again later.' }, 500);
  }
}

export class SubmissionError extends Error {
  constructor(message, status = 400) {
    super(message);
    this.name = 'SubmissionError';
    this.status = status;
  }
}

export function buildSubmission(payload, now = new Date()) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new SubmissionError('The request body must be a JSON object.');
  }

  const kind = required(payload, 'kind', 40);
  const id = submissionId(now);

  if (kind === 'song_request') {
    const title = required(payload, 'title', 180);
    return {
      id,
      kind,
      title: `[Song request] ${title}`,
      color: 0xf2b705,
      fields: [
        ['Title', title],
        ['English title', optional(payload, 'englishTitle', 180)],
        ['Author or source', optional(payload, 'author', 240)],
        ['Lyrics or source link', required(payload, 'lyricsOrSource', 6000)],
        ['Additional notes', optional(payload, 'notes', 2000)],
      ],
    };
  }

  if (kind === 'problem_report') {
    const summary = required(payload, 'summary', 180);
    return {
      id,
      kind,
      title: `[Report] ${summary}`,
      color: 0xd95040,
      fields: [
        ['Summary', summary],
        ['What happened?', required(payload, 'description', 4000)],
        ['Steps to reproduce', optional(payload, 'steps', 2500)],
        ['Device details', optional(payload, 'deviceDetails', 500)],
      ],
    };
  }

  if (kind === 'song_correction') {
    const songTitle = required(payload, 'songTitle', 180);
    return {
      id,
      kind,
      title: `[Song correction] ${songTitle}`,
      color: 0x4f8fda,
      fields: [
        ['Song title', songTitle],
        ['English title', optional(payload, 'songEnglishTitle', 180)],
        ['Catalogue ID', required(payload, 'songId', 180)],
        ['What should be corrected?', required(payload, 'correction', 4000)],
        [
          'Suggested correction or source',
          optional(payload, 'suggestedCorrectionOrSource', 4000),
        ],
      ],
    };
  }

  throw new SubmissionError('Unsupported feedback type.');
}

async function readJsonPayload(request) {
  const contentLength = Number(request.headers.get('Content-Length') || '0');
  if (contentLength > MAX_REQUEST_BYTES) {
    throw new SubmissionError('The request is too large.');
  }

  const text = await request.text();
  if (!text || text.length > MAX_REQUEST_BYTES) {
    throw new SubmissionError('The request is empty or too large.');
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new SubmissionError('Invalid JSON.');
  }
}

async function enforceRateLimit(request, env) {
  const limit = Number(env.RATE_LIMIT_PER_HOUR || DEFAULT_RATE_LIMIT_PER_HOUR);
  if (!Number.isFinite(limit) || limit <= 0) return;

  const key = clientKey(request);
  if (!env.RATE_LIMIT) return;

  const current = Number((await env.RATE_LIMIT.get(key)) || '0');
  if (current >= limit) {
    throw new SubmissionError('Too many submissions. Try again later.', 429);
  }
  await env.RATE_LIMIT.put(key, String(current + 1), {
    expirationTtl: RATE_LIMIT_TTL_SECONDS,
  });
}

async function postDiscordSubmission(submission, env) {
  const webhookUrl = env.DISCORD_WEBHOOK_URL;
  if (!webhookUrl || !String(webhookUrl).startsWith('https://discord.com/api/webhooks/')) {
    throw new SubmissionError('The support service is not configured.', 503);
  }

  const url = new URL(webhookUrl);
  url.searchParams.set('wait', 'true');
  if (env.DISCORD_THREAD_ID) {
    url.searchParams.set('thread_id', env.DISCORD_THREAD_ID);
  }

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(discordPayload(submission)),
  });

  if (!response.ok) {
    if (response.status === 429) {
      throw new SubmissionError('The support service is temporarily rate limited.', 503);
    }
    throw new SubmissionError('Could not submit right now. Try again later.', 502);
  }

  const message = await response.json();
  const guildId = textValue(message.guild_id);
  const channelId = textValue(message.channel_id);
  const messageId = textValue(message.id);
  return {
    id: messageId,
    url:
      guildId && channelId && messageId
        ? `https://discord.com/channels/${guildId}/${channelId}/${messageId}`
        : null,
  };
}

function discordPayload(submission) {
  return {
    username: 'Praise Support',
    allowed_mentions: { parse: [] },
    embeds: [
      {
        title: submission.title,
        color: submission.color,
        timestamp: new Date().toISOString(),
        footer: { text: `Praise submission ${submission.id}` },
        fields: submission.fields
          .filter(([, value]) => value)
          .map(([name, value]) => ({
            name,
            value: truncateForDiscord(value),
            inline: false,
          })),
      },
    ],
  };
}

function required(payload, key, maximum) {
  const value = optional(payload, key, maximum);
  if (value === null) throw new SubmissionError(`${key} is required.`);
  return value;
}

function optional(payload, key, maximum) {
  const raw = payload[key];
  if (raw === null || raw === undefined) return null;
  if (typeof raw !== 'string') throw new SubmissionError(`${key} must be text.`);
  const normalized = raw.trim();
  if (!normalized) return null;
  if (normalized.length > maximum) throw new SubmissionError(`${key} is too long.`);
  return normalized.replaceAll('@', '@\u200b');
}

function truncateForDiscord(value) {
  return value.length <= 1024 ? value : `${value.slice(0, 1017)}…`;
}

function submissionId(now) {
  const compact = now.toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  const random = Math.floor(Math.random() * 9000) + 1000;
  return `${compact}-${random}`;
}

function messageNumber(messageId, fallbackId) {
  if (messageId && /^\d+$/.test(messageId)) {
    return Number(messageId.slice(-9));
  }
  return Number(fallbackId.replace(/\D/g, '').slice(-9));
}

function clientKey(request) {
  const forwarded = request.headers.get('CF-Connecting-IP')
    || request.headers.get('X-Forwarded-For')
    || 'unknown';
  return `support:${forwarded.split(',', 1)[0].trim()}`;
}

function textValue(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function emptyResponse(status) {
  return new Response(null, { status, headers: corsHeaders });
}
