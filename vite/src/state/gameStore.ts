import { create } from 'zustand';
import { installGodotBridge } from '../godot/bridge';
import type { GodotEvent, GodotToJs, JsToGodot } from '../godot/events';
import { RunState, PlayerFlags, hasAny } from '../godot/state';

export type BootPhase = 'idle' | 'loading' | 'running' | 'failed';

export interface TracedEvent {
  seq: number;
  at: number;
  event: string;
  payload: unknown;
}

const TRACE_LIMIT = 60;
const TRACE_FLUSH_MS = 250;
const LOG_LIMIT = 40;

interface GameStore {
  debugOpen: boolean;
  trace: TracedEvent[];
  engineLog: string[];
  boot: BootPhase;
  progress: number;
  bootError: string | null;
  bridgeReady: boolean;
  run: number;
  flags: number;
  player: GodotToJs['player:state'] | null;
  send<C extends keyof JsToGodot>(cmd: C, payload: JsToGodot[C]): void;
}

const bridge = installGodotBridge();

export const useGameStore = create<GameStore>()(() => ({
  debugOpen: false,
  trace: [],
  engineLog: [],
  boot: 'idle',
  progress: 0,
  bootError: null,
  bridgeReady: bridge.ready,
  run: RunState.BOOTING,
  flags: 0,
  player: null,
  send: (cmd, payload) => bridge.send(cmd, payload),
}));

const set = useGameStore.setState;

let seq = 0;
let pending: TracedEvent[] = [];

function trace(event: string, payload: unknown): void {
  seq += 1;
  pending = [{ seq, at: Date.now(), event, payload }, ...pending].slice(0, TRACE_LIMIT);
}

function flushTrace(): void {
  if (pending.length === 0 || !useGameStore.getState().debugOpen) return;
  const drained = pending;
  pending = [];
  set({ trace: [...drained, ...useGameStore.getState().trace].slice(0, TRACE_LIMIT) });
}

setInterval(flushTrace, TRACE_FLUSH_MS);

function tracked<E extends GodotEvent>(event: E, fn?: (payload: GodotToJs[E]) => void): void {
  bridge.on(event, (payload) => {
    trace(event, payload);
    fn?.(payload);
  });
}

tracked('godot:ready', () => set({ bridgeReady: true }));
tracked('scene:changed');
tracked('game:state', ({ run, flags }) => set({ run, flags }));
tracked('player:state', (player) => set({ player }));
tracked('game:score');
tracked('game:run_over');

export const toggleDebug = () => {
  const debugOpen = !useGameStore.getState().debugOpen;
  set({ debugOpen });
  if (debugOpen) flushTrace();
};

export const clearTrace = () => {
  pending = [];
  set({ trace: [], engineLog: [] });
};

export const logEngine = (line: string) =>
  set({ engineLog: [line, ...useGameStore.getState().engineLog].slice(0, LOG_LIMIT) });

export const boot = {
  start: () => set({ boot: 'loading', progress: 0, bootError: null }),
  progress: (progress: number) => set({ progress }),
  running: () => set({ boot: 'running' }),
  fail: (bootError: string) => set({ boot: 'failed', bootError }),
};

export const useDebugOpen = () => useGameStore((s) => s.debugOpen);
export const useTrace = () => useGameStore((s) => s.trace);
export const useEngineLog = () => useGameStore((s) => s.engineLog);
export const useRun = () => useGameStore((s) => s.run);
export const useFlags = () => useGameStore((s) => s.flags);
export const useBoot = () => useGameStore((s) => s.boot);
export const useProgress = () => useGameStore((s) => s.progress);
export const useBootError = () => useGameStore((s) => s.bootError);
export const useBridgeReady = () => useGameStore((s) => s.bridgeReady);
export const usePlayer = () => useGameStore((s) => s.player);
export const useSend = () => useGameStore((s) => s.send);

export const usePaused = () => useGameStore((s) => s.run === RunState.PAUSED);

export const usePlaying = () =>
  useGameStore((s) => s.run === RunState.PLAYING || s.run === RunState.PAUSED);

export const useFlag = (flag: number) => useGameStore((s) => hasAny(s.flags, flag));

export const useInvulnerable = () => useFlag(PlayerFlags.INVULNERABLE);
