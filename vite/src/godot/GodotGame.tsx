import { useEffect, useRef, useState } from 'react';
import { installGodotBridge } from './bridge';

/** Inject a classic <script> once; resolve on load. */
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
 * Mirrors the exported index.html's GODOT_CONFIG.
 *
 * `executable` and `mainPack` are RELATIVE on purpose. Godot's loader normally
 * derives its base from `document.currentScript.src`, but that is null for a
 * dynamically injected async <script>, so it would resolve index.wasm against
 * the wrong root. Relative paths resolve against the document base URL, which
 * works at the local origin root and under itch's CDN subpath alike.
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
  const startedRef = useRef(false); // guards StrictMode's double mount
  const [progress, setProgress] = useState(0);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;

    // Must exist before the engine boots: the GDScript autoload looks it up in _ready().
    installGodotBridge();

    // No `cancelled` flag on purpose: startedRef already guarantees a single
    // boot across StrictMode's mount -> cleanup -> mount, and cancelling on the
    // interim cleanup would abort the only boot before startGame runs.
    loadScript('godot/index.js')
      .then(async () => {
        const Engine = window.Engine;
        if (!Engine) throw new Error('Godot loader did not attach window.Engine');

        // Turns the classic black-canvas failure into something readable.
        const missing = Engine.getMissingFeatures?.({ ...ENGINE_CONFIG }) ?? [];
        if (missing.length > 0) {
          throw new Error(`Browser is missing required features: ${missing.join(', ')}`);
        }

        const engine = new Engine({ ...ENGINE_CONFIG });
        await engine.startGame({
          canvas: canvasRef.current!,
          onProgress: (current: number, total: number) => {
            if (total > 0) setProgress(Math.round((current / total) * 100));
          },
        });
        setReady(true);
      })
      .catch((e: unknown) => setError(e instanceof Error ? e.message : String(e)));
  }, []);

  return (
    <div className="godot-layer">
      <canvas ref={canvasRef} id="godot-canvas" />
      {!ready && !error && <div className="godot-status">Loading {progress}%</div>}
      {error && (
        <div className="godot-status godot-error">
          <strong>Failed to start</strong>
          <pre>{error}</pre>
        </div>
      )}
    </div>
  );
}
