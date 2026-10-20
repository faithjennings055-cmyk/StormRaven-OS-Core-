/**
 * Example custom tool. Copy this file (without the leading `_`) to add your
 * own — drop a `.ts` in this directory, default-export a ToolDefinition
 * (or an array of them), push.
 *
 * The leading underscore tells the loader to SKIP this file.
 */
import { defineTool } from '@earendil-works/pi-coding-agent';
import { Type } from 'typebox';

// defineTool infers the parameter type from the TypeBox schema, so `params`
// below is typed without a cast.
const greet = defineTool({
  name: 'greet',
  label: 'Greet',
  description: 'Say hi to someone by name.',
  parameters: Type.Object({
    name: Type.String({ description: 'Person to greet' }),
  }),
  async execute(_toolCallId, params) {
    return {
      content: [{ type: 'text', text: `Hello, ${params.name}!` }],
      details: {},
    };
  },
});

export default greet;
