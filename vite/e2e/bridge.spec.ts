import { test, expect, type Page } from '@playwright/test';

// &boot -> boot.tscn loads train.scn, and /train/ maps to PLAYING; there is no menu on the way in
const RUN_PLAYING = 'PLAYING (2)';
// &alive -> Train._start_level() sets PLAYER_ALIVE as the carriage comes up, and
//           boot goes straight there, so the player is alive from the first frame
const FLAGS_ALIVE = 'ALIVE (0x1)';
const RUN_PAUSED = 'PAUSED (3)';
const RUN_MENU = 'MENU (1)';

async function booted(page: Page) {
  await page.goto('/index.html');
  await expect(page.locator('#godot-canvas')).toBeVisible();
  await expect(page.locator('.godot-status')).toHaveCount(0);
}

// &why -> the debug trace is a 60-entry ring, and the train scene evicts the handshake out of it
async function recordEmits(page: Page): Promise<unknown[][]> {
  const seen: unknown[][] = [];
  await page.exposeFunction('__record', (args: unknown[]) => {
    seen.push(args);
  });
  await page.addInitScript(() => {
    const iv = setInterval(() => {
      const b = (window as never as { __godotBridge?: Record<string, unknown> }).__godotBridge;
      if (!b) return;
      clearInterval(iv);
      const original = b.emit as (...a: unknown[]) => void;
      b.emit = (...a: unknown[]) => {
        (window as never as { __record: (x: unknown[]) => void }).__record(a);
        return original(...a);
      };
    }, 20);
  });
  return seen;
}

async function send(page: Page, cmd: string, payload: unknown) {
  await page.evaluate(
    ([c, p]) => {
      const b = (window as never as { __godotBridge: { send: (c: string, p: unknown) => void } }).__godotBridge;
      b.send(c as string, p);
    },
    [cmd, payload] as const,
  );
}

async function openDebug(page: Page) {
  await page.getByTestId('debug-toggle').click();
  await expect(page.getByTestId('debug-panel')).toBeVisible();
}

function row(page: Page, key: string) {
  return page.getByTestId(`row-${key}`).getByTestId('row-value');
}

test('engine boots and the bridge reports ready', async ({ page }) => {
  await booted(page);
  await openDebug(page);
  await expect(row(page, 'boot')).toHaveText('running');
  await expect(row(page, 'bridge')).toHaveText('ready');
});

test('scene changes arrive as a packed run state', async ({ page }) => {
  await booted(page);
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText(RUN_PLAYING);
  await expect(row(page, 'flags')).toHaveText(FLAGS_ALIVE);
});

test('the trace records the boot handshake in order', async ({ page }) => {
  const seen = await recordEmits(page);
  await booted(page);
  await expect.poll(() => seen.some(([e]) => e === 'game:state')).toBe(true);
  await expect.poll(() => seen.some(([e]) => e === 'scene:changed')).toBe(true);

  // &order -> chronological here, unlike the newest-first debug trace
  const events = seen.map(([e]) => e as string);
  expect(events).toContain('godot:ready');
  expect(events.indexOf('godot:ready')).toBeLessThan(events.indexOf('game:state'));
});

test('primitive payloads cross without JSON', async ({ page }) => {
  const seen = await recordEmits(page);
  await booted(page);
  await expect.poll(() => seen.some(([e]) => e === 'game:state')).toBe(true);

  const state = seen.find(([e]) => e === 'game:state')!;
  expect(state.slice(1).every((v) => typeof v === 'number')).toBe(true);

  const scene = seen.find(([e]) => e === 'scene:changed')!;
  expect(typeof scene[1]).toBe('string');
});

test('a command from React reaches Godot and is honoured', async ({ page }) => {
  await booted(page);
  await send(page, 'ui:main_menu', {});
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText(RUN_MENU);
});

test('pause is honoured inside the game scene', async ({ page }) => {
  await booted(page);
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText(RUN_PLAYING);
  await send(page, 'ui:pause', { paused: true });
  await expect(row(page, 'run')).toHaveText(RUN_PAUSED);
  await send(page, 'ui:pause', { paused: false });
  await expect(row(page, 'run')).toHaveText(RUN_PLAYING);
});

test('pause is refused outside the game scene', async ({ page }) => {
  await booted(page);
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText(RUN_PLAYING);
  await send(page, 'ui:main_menu', {});
  await expect(row(page, 'run')).toHaveText(RUN_MENU);

  await send(page, 'ui:pause', { paused: true });
  await expect(row(page, 'run')).toHaveText(RUN_MENU);
});

test('the debug panel toggles and clears', async ({ page }) => {
  await booted(page);
  await expect(page.getByTestId('debug-panel')).toHaveCount(0);
  await openDebug(page);
  await expect(page.getByTestId('trace-item')).not.toHaveCount(0);
  await page.getByTestId('debug-clear').click();
  await expect(page.getByTestId('trace-empty')).toBeVisible();
  await page.getByTestId('debug-close').click();
  await expect(page.getByTestId('debug-panel')).toHaveCount(0);
});
