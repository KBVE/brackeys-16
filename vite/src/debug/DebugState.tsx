import { runStateName, describePlayerFlags } from '../godot/state';
import {
  useBoot,
  useProgress,
  useBootError,
  useBridgeReady,
  useRun,
  useFlags,
  usePlayer,
} from '../state/gameStore';
import { Row } from './Row';
import s from './debug.module.css';

export function DebugState() {
  const boot = useBoot();
  const progress = useProgress();
  const error = useBootError();
  const bridgeReady = useBridgeReady();
  const run = useRun();
  const flags = useFlags();
  const player = usePlayer();

  return (
    <section className={s.grid}>
      <Row label="boot" value={boot === 'loading' ? `loading ${progress}%` : boot} />
      <Row label="bridge" value={bridgeReady ? 'ready' : 'waiting'} />
      <Row label="run" value={`${runStateName(run)} (${run})`} />
      <Row label="flags" value={`${describePlayerFlags(flags)} (0x${flags.toString(16)})`} />
      <Row label="player" value={player ? `hp ${player.health}/${player.max_health}` : 'none'} />
      {error && <Row label="error" value={error} />}
    </section>
  );
}
