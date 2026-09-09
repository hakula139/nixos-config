import { execFile } from 'node:child_process';

const marker = 'completenessGate';

export const CompletenessPlugin = async ({ client }) => {
  const sessions = new Map();
  const stateFor = (id) => {
    if (!sessions.has(id)) {
      sessions.set(id, { epoch: 0, checking: false, continued: false, checked: null });
    }
    return sessions.get(id);
  };

  const judge = (transcript) =>
    new Promise((resolve) => {
      const child = execFile('@command@', [], { timeout: Number('@timeout@') }, (error, stdout) => {
        if (error) return resolve({});
        try {
          resolve(JSON.parse(stdout));
        } catch {
          resolve({});
        }
      });
      child.stdin.on('error', () => {});
      child.stdin.end(JSON.stringify({ transcript }));
    });

  return {
    'chat.message': async ({ sessionID }, { parts }) => {
      const state = stateFor(sessionID);
      state.epoch++;
      if (!parts.some((part) => part.metadata?.[marker])) {
        sessions.delete(sessionID);
      }
    },
    'event': async ({ event }) => {
      if (event.type === 'session.deleted') {
        const id = event.properties.info.id;
        const state = sessions.get(id);
        if (state) state.epoch++;
        sessions.delete(id);
        return;
      }
      const id = event.properties?.sessionID;
      if (!id) return;
      const state = stateFor(id);
      if (
        event.type === 'session.error' ||
        (event.type === 'session.status' && event.properties.status.type !== 'idle')
      ) {
        state.epoch++;
        return;
      }
      if (event.type !== 'session.idle' || state.checking || state.continued) return;
      state.checking = true;
      const epoch = state.epoch;
      try {
        const [{ data: messages }, { data: session }] = await Promise.all([
          client.session.messages({ path: { id } }),
          client.session.get({ path: { id } }),
        ]);
        // A child session's idle event cannot delay delivery of its result to its parent.
        if (!session || session.parentID) return;
        const last = messages?.at(-1)?.info;
        if (
          last?.role !== 'assistant' ||
          !last.time.completed ||
          last.error ||
          last.finish !== 'stop' ||
          state.checked === last.id
        )
          return;
        state.checked = last.id;
        const result = await judge(messages);
        if (
          result.decision !== 'block' ||
          typeof result.reason !== 'string' ||
          !result.reason.trim()
        )
          return;

        // The user may have started or cancelled work while the judge was running.
        const [{ data: current }, { data: status }] = await Promise.all([
          client.session.messages({ path: { id } }),
          client.session.status(),
        ]);
        if (
          state.epoch !== epoch ||
          current?.at(-1)?.info.id !== last.id ||
          !status ||
          (status[id] && status[id].type !== 'idle')
        )
          return;
        state.continued = true;
        await client.session.prompt({
          path: { id },
          body: {
            agent: last.agent,
            model: { providerID: last.providerID, modelID: last.modelID },
            parts: [
              { type: 'text', text: result.reason, synthetic: true, metadata: { [marker]: true } },
            ],
          },
        });
      } catch {
        // Judge and session API failures must leave the user's session usable.
      } finally {
        state.checking = false;
      }
    },
  };
};
