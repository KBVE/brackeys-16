import { useEdition } from '../state/paperStore';
import s from './paper.module.css';

export function LeadStory() {
  const edition = useEdition();
  if (!edition) return null;

  return (
    <article className={s.lead}>
      <p className={s.kicker}>{edition.kicker}</p>
      <h2 className={s.headline} data-testid="paper-headline">
        {edition.title}
      </h2>
      <div className={s.columns}>
        <p className={s.dropCap}>{edition.lede}</p>
        {edition.body.map((para) => (
          <p key={para.slice(0, 32)}>{para}</p>
        ))}
      </div>
    </article>
  );
}
