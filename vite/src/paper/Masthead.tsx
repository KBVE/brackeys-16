import { runStateName } from '../godot/state';
import { useBoot, useLoading, useProgress, useRun } from '../state/gameStore';
import { masthead } from '../content/content';
import s from './paper.module.css';

export function Masthead() {
  const run = useRun();
  const loading = useLoading();
  const boot = useBoot();
  const bootProgress = useProgress();
  const printing = loading && loading.status !== 'ready' && loading.status !== 'failed';

  return (
    <header className={s.masthead}>
      <div className={s.mastRule} />
      <h1 className={s.mastTitle}>{masthead.title}</h1>
      <div className={s.mastMeta}>
        <span>{masthead.issue}</span>
        <span>{masthead.dateline}</span>
        <span data-testid="presses">
          {boot === 'loading'
            ? `Presses: inking ${bootProgress}%`
            : printing
              ? `Presses: setting ${Math.round(loading.progress * 100)}%`
              : `Presses: ${runStateName(run)}`}
        </span>
        <span>{masthead.price}</span>
      </div>
      <div className={s.mastRule} />
    </header>
  );
}
