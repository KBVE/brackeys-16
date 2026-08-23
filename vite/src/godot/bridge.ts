import type { GodotToJs, JsToGodot, GodotEvent, GodotCommand } from './events';

/**
 * JS half of the Godot bridge.
 *
 * React installs `window.__godotBridge` BEFORE the engine boots, because the
 * GDScript autoload looks it up in `_ready()`. Godot then:
 *   - calls `emit(event, payloadJson)` to push events out
 *   - calls `setHandler(cb)` to register its GDScript callback
 *
 * Godot's `create_callback` hands the GDScript side a single Array of the JS
 * arguments, so `handler` must be invoked with cmd and json as TWO positional
 * arguments - not one packed object.
 */

type Handler = (cmd: string, payloadJson: string) => void;
type Listener<E extends GodotEvent> = (payload: GodotToJs[E]) => void;

export interface GodotEngine {
  startGame(override: Record<string, unknown>): Promise<void>;
  requestQuit?(): void;
}

interface EngineCtor {
  new (config: Record<string, unknown>): GodotEngine;
  getMissingFeatures?(config?: Record<string, unknown>): string[];
  isCrossOriginIsolated?(): boolean;
}

declare global {
  interface Window {
    __godotBridge?: GodotBridge;
    Engine?: EngineCtor;
  }
}

export interface GodotBridge {
  ready: boolean;
  /** Called by Godot. */
  emit(event: string, payloadJson: string): void;
  /** Called by Godot. */
  setHandler(cb: Handler): void;
  /** Called by React. Queues until the GDScript handler registers. */
  send<C extends GodotCommand>(cmd: C, payload?: JsToGodot[C]): void;
  on<E extends GodotEvent>(event: E, fn: Listener<E>): () => void;
  once<E extends GodotEvent>(event: E, fn: Listener<E>): () => void;
}

export function installGodotBridge(): GodotBridge {
  if (window.__godotBridge) return window.__godotBridge;

  const listeners = new Map<string, Set<(payload: unknown) => void>>();
  const queued: Array<[string, unknown]> = [];
  let handler: Handler | null = null;

  const drain = () => {
    if (!handler) return;
    while (queued.length) {
      const [cmd, payload] = queued.shift()!;
      handler(cmd, JSON.stringify(payload ?? {}));
    }
  };

  const bridge: GodotBridge = {
    ready: false,

    emit(event, payloadJson) {
      let payload: unknown = null;
      try {
        payload = payloadJson ? JSON.parse(payloadJson) : null;
      } catch {
        payload = payloadJson; // not JSON - hand it over raw rather than drop it
      }
      if (event === 'godot:ready') bridge.ready = true;
      listeners.get(event)?.forEach((fn) => fn(payload));
    },

    setHandler(cb) {
      handler = cb;
      drain();
    },

    send(cmd, payload) {
      if (!handler) {
        queued.push([cmd, payload]);
        return;
      }
      handler(cmd, JSON.stringify(payload ?? {}));
    },

    on(event, fn) {
      let set = listeners.get(event);
      if (!set) {
        set = new Set();
        listeners.set(event, set);
      }
      const wrapped = fn as (payload: unknown) => void;
      set.add(wrapped);
      return () => {
        set.delete(wrapped);
      };
    },

    once(event, fn) {
      const off = bridge.on(event, (payload) => {
        off();
        fn(payload);
      });
      return off;
    },
  };

  window.__godotBridge = bridge;
  return bridge;
}
