import { GodotGame } from './godot/GodotGame';
import { runStateName, describePlayerFlags } from './godot/state';
import {
  useReady,
  usePlaying,
  usePaused,
  usePlayer,
  useSend,
  useInvulnerable,
  useDebugState,
} from './state/gameStore';

const DEBUG = import.meta.env.DEV;

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

function DebugState() {
  const { run, flags } = useDebugState();
  return (
    <div className="hud hud-debug">
      {runStateName(run)} · {describePlayerFlags(flags)}
    </div>
  );
}

export default function App() {
  const ready = useReady();
  const playing = usePlaying();

  return (
    <div className="app">
      <GodotGame />
      <div className="ui-layer">
        {ready && playing && <Hud />}
        {DEBUG && ready && <DebugState />}
      </div>
    </div>
  );
}
