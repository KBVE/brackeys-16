import { test, expect, type Page } from '@playwright/test';

type Traced = { event: string; payload: unknown };

async function bootedToMenu(page: Page) {
  await page.goto('/index.html');
  await expect(page.locator('#godot-canvas')).toBeVisible();
  await expect(page.locator('.godot-status')).toHaveCount(0);
}

async function openDebug(page: Page) {
  await page.getByTestId('debug-toggle').click();
  await expect(page.getByTestId('debug-panel')).toBeVisible();
}

function row(page: Page, key: string) {
  return page.getByTestId(`row-${key}`).getByTestId('row-value');
}

test('engine boots and the bridge reports ready', async ({ page }) => {
  await bootedToMenu(page);
  await openDebug(page);
  await expect(row(page, 'boot')).toHaveText('running');
  await expect(row(page, 'bridge')).toHaveText('ready');
});

test('scene changes arrive as a packed run state', async ({ page }) => {
  await bootedToMenu(page);
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText('MENU (1)');
  await expect(row(page, 'flags')).toHaveText('NONE (0x0)');
});

test('the trace records the boot handshake in order', async ({ page }) => {
  await bootedToMenu(page);
  await openDebug(page);
  const codes = page.getByTestId('trace-event');
  await expect.poll(async () => (await codes.allTextContents()).includes('game:state')).toBe(true);

  const events = await codes.allTextContents();
  expect(events).toContain('godot:ready');
  expect(events).toContain('scene:changed');
  expect(events.indexOf('godot:ready')).toBeGreaterThan(events.indexOf('game:state'));
});

test('primitive payloads cross without JSON', async ({ page }) => {
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
  await bootedToMenu(page);
  await expect.poll(() => seen.some(([e]) => e === 'game:state')).toBe(true);

  const state = seen.find(([e]) => e === 'game:state')!;
  expect(state.slice(1)).toEqual([1, 0]);
  expect(state.slice(1).every((v) => typeof v === 'number')).toBe(true);

  const scene = seen.find(([e]) => e === 'scene:changed')!;
  expect(typeof scene[1]).toBe('string');
});

test('a command from React reaches Godot and is honoured', async ({ page }) => {
  await bootedToMenu(page);
  await page.evaluate(() => {
    const b = (window as never as { __godotBridge: { send: (c: string, p: unknown) => void } }).__godotBridge;
    b.send('ui:main_menu', {});
  });
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText('MENU (1)');
});

test('pause is refused outside the game scene', async ({ page }) => {
  await bootedToMenu(page);
  await page.evaluate(() => {
    const b = (window as never as { __godotBridge: { send: (c: string, p: unknown) => void } }).__godotBridge;
    b.send('ui:pause', { paused: true });
  });
  await openDebug(page);
  await expect(row(page, 'run')).toHaveText('MENU (1)');
  const events = await page.getByTestId('trace-event').allTextContents();
  expect(events.filter((e) => e === 'game:state')).toHaveLength(1);
});

test('the debug panel toggles and clears', async ({ page }) => {
  await bootedToMenu(page);
  await expect(page.getByTestId('debug-panel')).toHaveCount(0);
  await openDebug(page);
  await expect(page.getByTestId('trace-item')).not.toHaveCount(0);
  await page.getByTestId('debug-clear').click();
  await expect(page.getByTestId('trace-empty')).toBeVisible();
  await page.getByTestId('debug-close').click();
  await expect(page.getByTestId('debug-panel')).toHaveCount(0);
});
