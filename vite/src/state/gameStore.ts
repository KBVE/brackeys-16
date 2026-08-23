import { create } from 'zustand';
import { useShallow } from 'zustand/react/shallow';
import { installGodotBridge } from '../godot/bridge';
import type { GodotToJs, JsToGodot } from '../godot/events';
import { RunState, PlayerFlags, hasAny } from '../godot/state';

interface GameStore {
  ready: boolean;
  run: number;
  flags: number;
  player: GodotToJs['player:state'] | null;
  send<C extends keyof JsToGodot>(cmd: C, payload: JsToGodot[C]): void;
}

const bridge = installGodotBridge();

export const useGameStore = create<GameStore>()(() => ({
  ready: bridge.ready,
  run: RunState.BOOTING,
  flags: 0,
  player: null,
  send: (cmd, payload) => bridge.send(cmd, payload),
}));

const set = useGameStore.setState;

bridge.on('godot:ready', () => set({ ready: true }));
bridge.on('game:state', ({ run, flags }) => set({ run, flags }));
bridge.on('player:state', (player) => set({ player }));

export const useReady = () => useGameStore((s) => s.ready);
export const useRun = () => useGameStore((s) => s.run);
export const usePlayer = () => useGameStore((s) => s.player);
export const useSend = () => useGameStore((s) => s.send);

export const usePaused = () => useGameStore((s) => s.run === RunState.PAUSED);

export const usePlaying = () =>
  useGameStore((s) => s.run === RunState.PLAYING || s.run === RunState.PAUSED);

export const useFlag = (flag: number) => useGameStore((s) => hasAny(s.flags, flag));

export const useInvulnerable = () => useFlag(PlayerFlags.INVULNERABLE);

export const useDebugState = () =>
  useGameStore(useShallow((s) => ({ run: s.run, flags: s.flags })));
