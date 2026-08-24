/**
 * Schemas for everything authored as MDX under shared/data.
 *
 * &why -> a mistyped trigger or a missing field would not crash anything; the
 *         article would just never print and the passenger would just never
 *         appear. Validation at compile time turns that into a build error.
 * &one -> both runtimes read the compiled output, so this is the only place the
 *         shape of game content is stated
 */
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// &resolve -> zod is a devDependency of vite/, and this file sits in tools/, so
//             node would look in a repo-root node_modules that does not exist.
//             One install location, resolved explicitly, beats a second one.
const require = createRequire(
  join(dirname(fileURLToPath(import.meta.url)), '../vite/package.json'),
);
const { z } = require('zod');

const clock = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'expected an in-world time like "23:00"');

/**
 * Prose compiled from the MDX body.
 * &split -> everything before the first `##` is the lede and its follow-on
 *           paragraphs; each heading becomes an addressable section, so game
 *           code asks for `sections.alibi` instead of parsing a blob
 */
const section = z.object({
  heading: z.string().min(1),
  paragraphs: z.array(z.string()),
  bullets: z.array(z.string()),
});

const prose = {
  lede: z.string().min(1),
  body: z.array(z.string()),
  sections: z.record(z.string(), section).default({}),
};

/**
 * Where someone can be, as a locations id.
 *
 * &ref -> not an enum. A room is authored under shared/data/locations, so the
 *         vocabulary IS the collection and gen-content checks every location
 *         against it the way it already checks item.owner. A room spelt wrong
 *         is a build error naming the file, not a passenger who quietly never
 *         appears.
 */
const locationId = z.string().min(1);

export const article = z.object({
  id: z.string().min(1),
  when: z
    .object({
      boot: z.boolean().optional(),
      level: z.string().optional(),
      after: clock.optional(),
      before: clock.optional(),
    })
    .refine((w) => w.boot !== undefined || w.level !== undefined, {
      message: 'when: needs at least a boot or a level, or nothing can print it',
    }),
  priority: z.number().int().default(0),
  kicker: z.string().min(1),
  title: z.string().min(1),
  caption: z.string().min(1),
  ...prose,
});

export const passenger = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  /** How the passenger list prints them; defaults to the name. */
  listed: z.string().optional(),
  role: z.string().min(1),
  berth: z.string().min(1),
  boarded: z.object({ at: clock, where: z.string().min(1) }),
  /** Where they are found when nothing else has moved them. */
  location: locationId,
  suspect: z.boolean().default(false),
  /** Short, playable descriptors an NPC system can branch on. */
  traits: z.array(z.string()).default([]),
  relationships: z
    .array(z.object({ who: z.string().min(1), tie: z.string().min(1) }))
    .default([]),
  /**
   * &truth -> where this passenger actually was, hour by hour. What they SAY
   *           lives in the `## Alibi` section, so the contradiction between the
   *           two is authored, not computed by accident
   */
  timeline: z
    .array(z.object({ at: clock, where: locationId, note: z.string().min(1) }))
    .default([]),
  ...prose,
});

export const item = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  kind: z.enum(['document', 'key', 'personal', 'weapon', 'curio']),
  /** Present in the player's effects from the start. */
  carried: z.boolean().default(false),
  /** Passenger id this belongs to, when it is not the player's. */
  owner: z.string().optional(),
  /** Where it is found, when it is not carried. */
  location: locationId.optional(),
  /** Reading it, opening it or turning it over reveals this. */
  reveals: z.array(z.string()).default([]),
  ...prose,
});

/**
 * Somewhere on the train, or off it.
 *
 * &carriage -> a location with a carriage index is a place in the consist, at
 *         position along the train; SOccupancy resolves a world position into
 *              that one. Without it the location is off the train, so nobody
 *         and the ECS never spawns a carriage for it.
 */
export const location = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  carriage: z.number().int().min(0).optional(),
  ...prose,
});

/**
 * Directory name under shared/data -> schema for every .mdx inside it.
 *
 * &order -> locations first; every other collection points into it, so it has
 *           to be compiled before the references can be checked
 */
export const collections = {
  locations: location,
  articles: article,
  passengers: passenger,
  items: item,
};
