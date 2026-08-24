import s from './debug.module.css';

export function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className={s.row} data-testid={`row-${label}`}>
      <span className={s.key}>{label}</span>
      <span className={s.val} data-testid="row-value">
        {value}
      </span>
    </div>
  );
}
