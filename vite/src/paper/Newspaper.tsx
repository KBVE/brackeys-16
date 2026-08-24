import { Dossier } from './Dossier';
import { LeadStory } from './LeadStory';
import { Masthead } from './Masthead';
import { Plate } from './Plate';
import { Sidebar, Telegrams } from './Sidebar';
import { useView } from '../state/paperStore';
import s from './paper.module.css';


export function Newspaper() {
  const view = useView();

  return (
    <div
      className={`${s.sheet}${view === 'paper' ? ` ${s.open}` : ''}`}
      aria-hidden={view !== 'paper'}
      data-testid="newspaper"
      data-view={view}
    >
      <Masthead />
      <div className={s.body}>
        <div className={s.main}>
          <Plate />
          <LeadStory />
        </div>
        <Sidebar />
      </div>
      <Telegrams />
      <Dossier />
    </div>
  );
}
