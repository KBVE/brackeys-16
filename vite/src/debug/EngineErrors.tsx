import { useEngineLog } from '../state/gameStore';
import s from './debug.module.css';

export function EngineErrors() {
  const engineLog = useEngineLog();
  if (engineLog.length === 0) return null;

  return (
    <>
      <div className={s.sectionHead}>
        engine errors <span>{engineLog.length}</span>
      </div>
      <ol className={`${s.list} ${s.errors}`} data-testid="engine-errors">
        {engineLog.map((line, i) => (
          <li key={`${i}-${line.slice(0, 24)}`}>
            <span>{line}</span>
          </li>
        ))}
      </ol>
    </>
  );
}
