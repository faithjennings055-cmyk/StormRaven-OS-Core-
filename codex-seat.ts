import type { CreateModelRuntimeOptions } from '@earendil-works/pi-coding-agent';

type CredentialStore = NonNullable<CreateModelRuntimeOptions['credentials']>;
type Credential = NonNullable<Awaited<ReturnType<CredentialStore['read']>>>;

/**
 * Bearer the harness sends for a ChatGPT/Codex seat (bring-your-own
 * subscription). The transparent proxy matches this exact string and swaps in
 * the workspace's real seat token (transparent-proxy/src/middleware/stamp-seat.ts).
 * pi-ai's codex provider decodes the account id out of the token before any
 * request, so it is JWT-shaped with a placeholder account id. This harness keeps
 * zero @createinc dependencies, so the value is a copy: apps/anyone/llm's
 * codex-seat-sentinel contract test pins it equal to
 * SUBSCRIPTION_PROVIDERS.openai.sentinel.
 */
const CODEX_SEAT_SENTINEL =
  'sentinel-subscription-openai.eyJodHRwczovL2FwaS5vcGVuYWkuY29tL2F1dGgiOnsiY2hhdGdwdF9hY2NvdW50X2lkIjoicGxhY2Vob2xkZXIifX0.sentinel';

const CODEX_PROVIDER = 'openai-codex';

/** A model spec that runs on a ChatGPT seat (pi-server's `openai-codex-responses` api). */
export function isCodexSeatModel(model: { api: string } | null | undefined) {
  return model?.api === 'openai-codex-responses';
}

/**
 * pi's codex provider is OAuth-only, so a runtime API key is not enough: the
 * sentinel enters as an OAuth entry in a credential store that lives only in
 * memory for this session. Nothing is written to the sandbox, and the
 * far-future expiry keeps pi from ever trying to refresh it.
 */
export function codexSeatCredentials(): CredentialStore {
  const entries = new Map<string, Credential>([
    [
      CODEX_PROVIDER,
      {
        type: 'oauth',
        access: CODEX_SEAT_SENTINEL,
        refresh: 'placeholder',
        expires: 4102444800000,
        accountId: 'placeholder',
      },
    ],
  ]);
  return {
    async read(providerId) {
      return entries.get(providerId);
    },
    async list() {
      return [...entries].map(([providerId, credential]) => ({
        providerId,
        type: credential.type,
      }));
    },
    async modify(providerId, fn) {
      const next = await fn(entries.get(providerId));
      if (next !== undefined) entries.set(providerId, next);
      return entries.get(providerId);
    },
    async delete(providerId) {
      entries.delete(providerId);
    },
  };
}
