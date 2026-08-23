import { create } from 'zustand';
import { useShallow } from 'zustand/react/shallow';
import { installGodotBridge } from '../godot/bridge';
import type { GodotToJs, JsToGodot } from '../godot/events';
import { RunState, PlayerFlags, hasAny } from '../godot/state';

export type BootPhase = 'idle' | 'loading' | 'running' | 'failed';

interface GameStore {
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

bridge.on('godot:ready', () => set({ bridgeReady: true }));
bridge.on('game:state', ({ run, flags }) => set({ run, flags }));
bridge.on('player:state', (player) => set({ player }));

export const boot = {
  start: () => set({ boot: 'loading', progress: 0, bootError: null }),
  progress: (progress: number) => set({ progress }),
  running: () => set({ boot: 'running' }),
  fail: (bootError: string) => set({ boot: 'failed', bootError }),
};

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

export const useDebugState = () =>
  useGameStore(useShallow((s) => ({ run: s.run, flags: s.flags })));
