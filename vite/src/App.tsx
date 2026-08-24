import { GodotGame } from './godot/GodotGame';
import { DebugPanel } from './debug/DebugPanel';
import {
  useBridgeReady,
  usePlaying,
  usePaused,
  usePlayer,
  useSend,
  useInvulnerable,
} from './state/gameStore';

function Hud() {
  const player = usePlayer();
  const paused = usePaused();
  const invulnerable = useInvulnerable();
  const send = useSend();

  return (
    <div className="hud">
      {player && (
        <span className={invulnerable ? 'hud-invuln' : undefined}>
          HP {player.health} / {player.max_health}
        </span>
      )}
      <button onClick={() => send('ui:pause', { paused: !paused })}>
        {paused ? 'Resume' : 'Pause'}
      </button>
    </div>
  );
}

export default function App() {
  const ready = useBridgeReady();
  const playing = usePlaying();

  return (
    <div className="app">
      <GodotGame />
      <div className="ui-layer">
        {ready && playing && <Hud />}
        <DebugPanel />
      </div>
    </div>
  );
}
