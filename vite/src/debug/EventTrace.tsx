import { memo } from 'react';
import { useTrace, type TracedEvent } from '../state/gameStore';
import s from './debug.module.css';

const TraceRow = memo(function TraceRow({ entry }: { entry: TracedEvent }) {
  return (
    <li data-testid="trace-item">
      <code data-testid="trace-event">{entry.event}</code>
      <span>{JSON.stringify(entry.payload)}</span>
    </li>
  );
});

export function EventTrace() {
  const trace = useTrace();

  return (
    <>
      <div className={s.sectionHead}>
        events <span data-testid="trace-count">{trace.length}</span>
      </div>
      <ol className={s.list}>
        {trace.map((entry) => (
          <TraceRow key={entry.seq} entry={entry} />
        ))}
        {trace.length === 0 && (
          <li className={s.empty} data-testid="trace-empty">
            nothing yet
          </li>
        )}
      </ol>
    </>
  );
}
