import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { setPlate, usePlate, useView } from '../state/paperStore';

const viewport = () => ({ w: window.innerWidth, h: window.innerHeight });

export function usePlateMeasure<T extends HTMLElement>() {
  const ref = useRef<T>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const measure = () => {
      const r = el.getBoundingClientRect();
      setPlate({ x: r.x, y: r.y, w: r.width, h: r.height });
    };

    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    window.addEventListener('resize', measure);
    return () => {
      ro.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, []);

  return ref;
}

export function useFrameStyle(): CSSProperties {
  const view = useView();
  const plate = usePlate();
  const [vp, setVp] = useState(viewport);

  useEffect(() => {
    const onResize = () => setVp(viewport());
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  if (view === 'world' || !plate || plate.w === 0 || plate.h === 0) {
    return { transform: 'translate3d(0px, 0px, 0) scale(1)' };
  }

  const scale = Math.min(plate.w / vp.w, plate.h / vp.h);
  const x = plate.x + (plate.w - vp.w * scale) / 2;
  const y = plate.y + (plate.h - vp.h * scale) / 2;

  return { transform: `translate3d(${x}px, ${y}px, 0) scale(${scale})` };
}
