import { useEffect, useState } from 'react';
import { GodotGame } from './godot/GodotGame';
import { installGodotBridge } from './godot/bridge';
import type { GodotToJs } from './godot/events';

export default function App() {
  const [player, setPlayer] = useState<GodotToJs['player:state'] | null>(null);

  useEffect(() => {
    const bridge = installGodotBridge();
    return bridge.on('player:state', setPlayer);
  }, []);

  return (
    <div className="app">
      <GodotGame />
      <div className="ui-layer">
        {player && (
          <div className="hud">
            HP {player.health} / {player.max_health}
          </div>
        )}
      </div>
    </div>
  );
}
