import { useEffect, useRef, useState } from 'react';
import { installGodotBridge } from './bridge';
import {
  boot,
  logEngine,
  useBoot,
  useProgress,
  useBootError,
  useLoading,
  useRun,
} from '../state/gameStore';
import { RunState } from './state';
import { useView } from '../state/paperStore';
import { useFrameStyle } from '../paper/frame';


function loadEngineScript(source: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const alreadyLoaded = document.querySelector(`script[data-godot="${source}"]`);
    if (alreadyLoaded) {
      resolve();
      return;
    }
    const scriptElement = document.createElement('script');
    scriptElement.src = source;
    scriptElement.async = true;
    scriptElement.dataset.godot = source;
    scriptElement.onload = () => resolve();
    scriptElement.onerror = () => reject(new Error(`failed to load ${source}`));
    document.body.appendChild(scriptElement);
  });
}


const injectedGlobals = window as unknown as {
  __godotConfig?: Record<string, unknown>;
  __godotLoader?: string;
};

const ENGINE_LOADER_SOURCE = injectedGlobals.__godotLoader ?? 'godot/index.js';

const FALLBACK_CONFIG = {
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

const CORES = navigator.hardwareConcurrency || 4;
const tuning = new URLSearchParams(window.location.search);
const readOverride = (key: string, fallback: number) => {
  const raw = tuning.get(key);
  const parsed = raw === null ? Number.NaN : Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const ENGINE_CONFIG = {
  ...(injectedGlobals.__godotConfig ?? FALLBACK_CONFIG),
  emscriptenPoolSize: readOverride('pool', Math.max(2, Math.min(8, CORES))),
  godotPoolSize: readOverride('gpool', Math.max(1, Math.min(4, CORES - 1))),
};

const PAGES_PER_MB = 16;
const SHARED_MEMORY_MB = readOverride('maxmb', 512);

function reserveSharedMemory() {
  (globalThis as unknown as { __godotMaxPages: number }).__godotMaxPages =
    SHARED_MEMORY_MB * PAGES_PER_MB;
}

const bootBytes = { loaded: 0, total: 0, lastAdvanceSeconds: 0 };
const bootFaults: string[] = [];
const bootStartedAt = performance.now();
const sinceBoot = () => Math.round((performance.now() - bootStartedAt) / 1000);

function noteFault(text: string) {
  const line = `${sinceBoot()}s ${text}`.slice(0, 220);
  if (bootFaults[bootFaults.length - 1] !== line) bootFaults.push(line);
}

function watchForFaults() {
  window.addEventListener('error', (event) =>
    noteFault(`err ${event.message} @ ${event.filename?.split('/').pop() ?? '?'}:${event.lineno}`),
  );
  window.addEventListener('unhandledrejection', (event) =>
    noteFault(`reject ${String((event.reason as Error)?.message ?? event.reason)}`),
  );
}

export function GodotGame() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const hasStartedRef = useRef(false);

  useEffect(() => {
    if (hasStartedRef.current) return;
    hasStartedRef.current = true;
    boot.start();
    watchForFaults();
    reserveSharedMemory();

    installGodotBridge();

    loadEngineScript(ENGINE_LOADER_SOURCE)
      .then(async () => {
        const EngineConstructor = window.Engine;
        if (!EngineConstructor) {
          throw new Error('Godot loader did not attach window.Engine');
        }

        const missingFeatures = EngineConstructor.getMissingFeatures?.({ ...ENGINE_CONFIG }) ?? [];
        if (missingFeatures.length > 0) {
          throw new Error(
            `Browser is missing required features: ${missingFeatures.join(', ')}`,
          );
        }

        const engine = new EngineConstructor({ ...ENGINE_CONFIG });
        await engine.startGame({
          canvas: canvasRef.current!,
          onProgress: (loadedBytes: number, totalBytes: number) => {
            bootBytes.loaded = loadedBytes;
            bootBytes.total = totalBytes;
            bootBytes.lastAdvanceSeconds = sinceBoot();
            boot.progress(
              totalBytes > 0 ? Math.round((loadedBytes / totalBytes) * 100) : null,
            );
          },
          onPrintError: (...messageParts: unknown[]) => {
            const engineLine = messageParts.join(' ');
            noteFault(`engine ${engineLine}`);
            logEngine(engineLine);
            if (engineLine.includes('Blocking on the main thread')) console.trace(engineLine);
            else console.error(...messageParts);
          },
        });
        boot.running();
      })
      .catch((reason: unknown) =>
        boot.fail(reason instanceof Error ? reason.message : String(reason)),
      );
  }, []);

  return <GodotLayer canvasRef={canvasRef} />;
}

function GodotLayer({ canvasRef }: { canvasRef: React.RefObject<HTMLCanvasElement | null> }) {
  const view = useView();
  const layerRef = useRef<HTMLDivElement>(null);
  const style = useFrameStyle(layerRef);

  return (
    <div
      ref={layerRef}
      className={`godot-layer${view === 'paper' ? ' is-plate' : ''}`}
      style={style}
    >
      <canvas ref={canvasRef} id="godot-canvas" />
      <div className="halftone" aria-hidden />
      <BootCurtain />
    </div>
  );
}

function BootCurtain() {
  const bootPhase = useBoot();
  const bootProgress = useProgress();
  const bootError = useBootError();
  const sceneLoading = useLoading();
  const run = useRun();

  const engineReady = bootPhase === 'running';
  const sceneLive = run !== RunState.BOOTING;
  const failed = bootPhase === 'failed' || sceneLoading?.status === 'failed';

  const liftedOnce = useRef(false);
  if (sceneLive && !failed) liftedOnce.current = true;
  const lifted = liftedOnce.current;

  if (failed) {
    return (
      <div className="godot-curtain is-error" role="alert">
        <p className="curtain-kicker">The presses have jammed</p>
        <pre className="curtain-detail">
          {bootError ?? `Could not load ${sceneLoading?.scene ?? 'the scene'}`}
        </pre>
      </div>
    );
  }

  const percent = engineReady
    ? sceneLoading
      ? Math.round(sceneLoading.progress * 100)
      : null
    : bootProgress;
  const caption = engineReady ? 'Inking the plate' : 'Setting the presses';
  const known = percent !== null;

  return (
    <div
      className={`godot-curtain${lifted ? ' is-lifted' : ''}`}
      aria-hidden={lifted}
      aria-busy={!lifted}
      data-testid="boot-curtain"
    >
      <p className="curtain-kicker">{caption}</p>
      <div className={`curtain-rule${known ? '' : ' is-indeterminate'}`} aria-hidden>
        <span style={known ? { width: `${Math.max(2, Math.min(100, percent))}%` } : undefined} />
      </div>
      <p className="curtain-percent" data-testid="boot-curtain-percent">
        {known ? `${percent}%` : 'Please wait'}
      </p>
      <BootDiagnostic bootPhase={bootPhase} engineReady={engineReady} />
    </div>
  );
}

function BootDiagnostic({ bootPhase, engineReady }: { bootPhase: string; engineReady: boolean }) {
  const [, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTick((n) => n + 1), 500);
    return () => clearInterval(id);
  }, []);

  const w = window as unknown as { Engine?: unknown; crossOriginIsolated?: boolean };
  const mb = (bytes: number) => (bytes / 1048576).toFixed(1);
  const downloaded = bootBytes.total > 0
    ? `${mb(bootBytes.loaded)}/${mb(bootBytes.total)}MB @${bootBytes.lastAdvanceSeconds}s`
    : 'no progress events';

  const lines = [
    `phase ${bootPhase}${engineReady ? ' / engine up' : ''}`,
    `isolated ${String(w.crossOriginIsolated)} · SAB ${typeof SharedArrayBuffer}`,
    `Engine ${w.Engine ? 'attached' : 'missing'}`,
    `pool ${ENGINE_CONFIG.emscriptenPoolSize}/${ENGINE_CONFIG.godotPoolSize} · mem ${SHARED_MEMORY_MB}MB · hw ${navigator.hardwareConcurrency ?? '?'} · dpr ${window.devicePixelRatio}`,
    `bytes ${downloaded}`,
    `t+${sinceBoot()}s`,
  ];

  return (
    <div className="curtain-diagnostic">
      <p>{lines.join(' · ')}</p>
      {bootFaults.length > 0 && (
        <p className="curtain-faults">{bootFaults.slice(-4).join(' | ')}</p>
      )}
    </div>
  );
}
