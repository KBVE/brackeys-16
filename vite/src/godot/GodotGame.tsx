import { useEffect, useRef } from 'react';
import { installGodotBridge } from './bridge';
import { boot, useBoot, useProgress, useBootError } from '../state/gameStore';


function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-godot="${src}"]`);
    if (existing) {
      resolve();
      return;
    }
    const el = document.createElement('script');
    el.src = src;
    el.async = true;
    el.dataset.godot = src;
    el.onload = () => resolve();
    el.onerror = () => reject(new Error(`failed to load ${src}`));
    document.body.appendChild(el);
  });
}

/**
 * &relative -> executable/mainPack are relative ON PURPOSE. Godot derives its
 *              base from document.currentScript.src, which is null for a
 *              dynamically injected async <script> -> wrong root for index.wasm.
 *           -> relative resolves against the document base: works at the origin
 *              root and under itch's CDN subpath alike
 */
const ENGINE_CONFIG = {
  executable: 'godot/index',
  mainPack: 'godot/index.pck',
  canvasResizePolicy: 2,
  ensureCrossOriginIsolationHeaders: true,
  experimentalVK: false,
  focusCanvas: true,
  gdextensionLibs: [],
  emscriptenPoolSize: 8,
  godotPoolSize: 4,
  args: [],
} as const;

export function GodotGame() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const startedRef = useRef(false); // &guards -> ducking StrictMode still throwin a double mount

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    boot.start();

    // &order -> must exist before boot, autoload reads it in _ready(), nope time to loop back around and maybe go through the pointers.
    installGodotBridge();

    // &nocancel -[0]> startedRef already guarantees one boot across StrictMode's [<T> & <t>] TNT!
    //               mount -[1]> cleanup -[2]> mount; cancelling on the init cleanup would abort the only boot before startGame runs
    loadScript('godot/index.js')
      .then(async () => {
        const Engine = window.Engine;
        if (!Engine) throw new Error('Godot loader did not attach window.Engine');

        const missing = Engine.getMissingFeatures?.({ ...ENGINE_CONFIG }) ?? [];
        if (missing.length > 0) {
          throw new Error(`Browser is missing required features: ${missing.join(', ')}`);
        }

        const engine = new Engine({ ...ENGINE_CONFIG });
        await engine.startGame({
          canvas: canvasRef.current!,
          onProgress: (current: number, total: number) => {
            if (total > 0) boot.progress(Math.round((current / total) * 100));
          },
        });
        boot.running();
      })
      .catch((e: unknown) => boot.fail(e instanceof Error ? e.message : String(e)));
  }, []);

  return (
    <div className="godot-layer">
      <canvas ref={canvasRef} id="godot-canvas" />
      <BootStatus />
    </div>
  );
}

function BootStatus() {
  const phase = useBoot();
  const progress = useProgress();
  const error = useBootError();

  if (phase === 'failed') {
    return (
      <div className="godot-status godot-error">
        <strong>Failed to start</strong>
        <pre>{error}</pre>
      </div>
    );
  }
  if (phase === 'running') return null;
  return <div className="godot-status">Loading {progress}%</div>;
}
