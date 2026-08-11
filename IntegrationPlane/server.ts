import { server, tool, z } from '@noodleseed/one';

const Provider = z.enum([
  'openai', 'anthropic', 'google-ai', 'xai', 'google', 'github', 'linear',
  'cursor', 'replit', 'figma', 'vercel', 'netlify', 'supabase', 'convex',
  'lovable', 'appdeploy', 'n8n', 'other'
]);

const Capability = z.enum([
  'chat', 'reason', 'code', 'search', 'files', 'repo', 'issues', 'pull-requests',
  'project-management', 'design', 'deploy', 'database', 'automation', 'oauth', 'custom-api'
]);

type Connector = {
  id: string;
  provider: z.infer<typeof Provider>;
  capabilities: z.infer<typeof Capability>[];
  transport: 'api' | 'mcp' | 'oauth' | 'webhook' | 'custom';
  credential: 'managed' | 'oauth' | 'none';
  enabled: boolean;
};

const connectors: Connector[] = [
  { id: 'ai.openai', provider: 'openai', capabilities: ['chat', 'reason', 'code'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'ai.anthropic', provider: 'anthropic', capabilities: ['chat', 'reason', 'code'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'ai.google', provider: 'google-ai', capabilities: ['chat', 'reason', 'code'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'ai.xai', provider: 'xai', capabilities: ['chat', 'reason', 'code'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'dev.github', provider: 'github', capabilities: ['repo', 'issues', 'pull-requests', 'files'], transport: 'oauth', credential: 'oauth', enabled: true },
  { id: 'dev.linear', provider: 'linear', capabilities: ['issues', 'project-management'], transport: 'oauth', credential: 'oauth', enabled: true },
  { id: 'dev.google', provider: 'google', capabilities: ['files', 'oauth'], transport: 'oauth', credential: 'oauth', enabled: true },
  { id: 'build.cursor', provider: 'cursor', capabilities: ['code'], transport: 'mcp', credential: 'managed', enabled: true },
  { id: 'build.replit', provider: 'replit', capabilities: ['code', 'deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.figma', provider: 'figma', capabilities: ['design', 'files'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.vercel', provider: 'vercel', capabilities: ['deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.netlify', provider: 'netlify', capabilities: ['deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.supabase', provider: 'supabase', capabilities: ['database', 'deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.convex', provider: 'convex', capabilities: ['database', 'deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.lovable', provider: 'lovable', capabilities: ['code', 'deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.appdeploy', provider: 'appdeploy', capabilities: ['code', 'deploy'], transport: 'api', credential: 'managed', enabled: true },
  { id: 'build.n8n', provider: 'n8n', capabilities: ['automation'], transport: 'api', credential: 'managed', enabled: true },
];

export default server('quicksilver-integration-plane', {
  title: 'Quicksilver Integration Plane',
  version: '0.1.0',
}, [
  tool('integration_catalog', {
    description: 'Return the current connector registry and the capabilities exposed by each connector.',
    output: z.object({ connectors: z.array(z.object({
      id: z.string(),
      provider: Provider,
      capabilities: z.array(Capability),
      transport: z.string(),
      credential: z.string(),
      enabled: z.boolean(),
    })) }),
    fulfil: () => ({ connectors }),
  }),

  tool('integration_route', {
    description: 'Select the best available connector(s) for a requested capability. Prefer the primary provider, then configured secondary providers, then a generic fallback.',
    input: z.object({
      capability: Capability,
      preferred: z.array(Provider).optional(),
      exclude: z.array(Provider).optional(),
      requireOAuth: z.boolean().optional(),
    }),
    output: z.object({
      capability: Capability,
      route: z.array(z.object({ connectorId: z.string(), provider: Provider, reason: z.string() })),
      requiresApproval: z.boolean(),
    }),
    fulfil: ({ capability, preferred = [], exclude = [], requireOAuth = false }) => {
      const eligible = connectors.filter(c =>
        c.enabled &&
        c.capabilities.includes(capability) &&
        !exclude.includes(c.provider) &&
        (!requireOAuth || c.credential === 'oauth')
      );

      const ranked = [...eligible].sort((a, b) => {
        const ai = preferred.indexOf(a.provider);
        const bi = preferred.indexOf(b.provider);
        return (ai < 0 ? 999 : ai) - (bi < 0 ? 999 : bi);
      });

      return {
        capability,
        route: ranked.slice(0, 3).map((c, index) => ({
          connectorId: c.id,
          provider: c.provider,
          reason: index === 0 ? 'primary route' : 'secondary/fallback route',
        })),
        requiresApproval: ['deploy', 'files', 'repo', 'pull-requests'].includes(capability),
      };
    },
  }),

  tool('integration_plan', {
    description: 'Build an execution plan spanning multiple systems without exposing credentials. The plan is deterministic and suitable for Quicksilver orchestration.',
    input: z.object({
      objective: z.string(),
      capabilities: z.array(Capability),
      preferredProviders: z.array(Provider).optional(),
    }),
    output: z.object({
      objective: z.string(),
      steps: z.array(z.object({
        order: z.number(),
        capability: Capability,
        connectorId: z.string(),
        provider: Provider,
        approvalRequired: z.boolean(),
      })),
    }),
    fulfil: ({ objective, capabilities, preferredProviders = [] }) => {
      const steps = capabilities.map((capability, index) => {
        const candidates = connectors
          .filter(c => c.enabled && c.capabilities.includes(capability))
          .sort((a, b) => preferredProviders.indexOf(a.provider) - preferredProviders.indexOf(b.provider));
        const selected = candidates[0];
        return {
          order: index + 1,
          capability,
          connectorId: selected?.id ?? 'fallback.unconfigured',
          provider: selected?.provider ?? 'other',
          approvalRequired: ['deploy', 'files', 'repo', 'pull-requests'].includes(capability),
        };
      });
      return { objective, steps };
    },
  }),

  tool('integration_health', {
    description: 'Return a credential-safe health snapshot of the integration plane. It never returns tokens, headers, or secret values.',
    output: z.object({
      status: z.literal('ready'),
      connectorCount: z.number(),
      enabledCount: z.number(),
      secretPolicy: z.literal('managed-only'),
      architecture: z.literal('Noodle Seed MCP gateway'),
    }),
    fulfil: () => ({
      status: 'ready' as const,
      connectorCount: connectors.length,
      enabledCount: connectors.filter(c => c.enabled).length,
      secretPolicy: 'managed-only' as const,
      architecture: 'Noodle Seed MCP gateway' as const,
    }),
  }),
]);
