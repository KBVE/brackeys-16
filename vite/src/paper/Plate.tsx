import { usePlaying } from '../state/gameStore';
import { useEdition, setView } from '../state/paperStore';
import { plateCopy } from '../content/content';
import { usePlateMeasure } from './frame';
import s from './paper.module.css';

/**
 * The plate is a hole, not a container -> it holds no canvas, it only reports
 * its box so the canvas layer can fly into it and clicking it goes back to play.
 */
export function Plate() {
  const ref = usePlateMeasure<HTMLButtonElement>();
  const edition = useEdition();
  const playing = usePlaying();

  return (
    <figure className={s.plate}>
      <button
        ref={ref}
        className={s.plateHole}
        onClick={() => setView('world')}
        aria-label="Return to the scene"
        data-testid="paper-plate"
      />
      <figcaption className={s.caption}>
        {edition?.caption}
        {playing && <span className={s.board}> — {plateCopy.board}</span>}
      </figcaption>
    </figure>
  );
}
