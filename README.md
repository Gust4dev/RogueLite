# FPS Roguelite - Godot 4.3+

Um jogo de tiro em primeira pessoa roguelite desenvolvido em Godot 4.3+.

## Características

**Fase 1 - MVP Implementado:**
- ✅ FPS Controller funcional (WASD + mouse look + jump + sprint)
- ✅ Sistema de armas com raycast shooting
- ✅ Pistola semi-automática
- ✅ Sistema de munição e reload
- ✅ Inimigo zombie com pathfinding
- ✅ Timer de 15 minutos
- ✅ HUD (HP, ammo, timer, crosshair)
- ✅ VFX básicos (muzzle flash, impact particles)
- ✅ Arena de teste com navmesh

**Mecânicas Planejadas (Fases Futuras):**
- Timer de 15 minutos por run
- 4 mini-bosses (3, 6, 9, 12 minutos)
- Sistema de chaves e boss final
- Sistema de upgrades (até 3 ativos + passivos)
- 6 armas diferentes (pistol, dual pistols, SMG, shotgun, sniper, LMG)
- Mapa procedural

## Estrutura do Projeto

```
res://
├── player/          # Player controller, stats, camera effects
├── weapons/         # Sistema de armas (BaseWeapon, Pistol, etc)
├── enemies/         # Inimigos (BaseEnemy, Zombie, etc)
├── managers/        # Singletons (GameManager, SpawnManager, AudioManager)
├── ui/              # Interface (HUD, menus)
├── vfx/             # Efeitos visuais
├── audio/           # Sons e música
└── scenes/          # Cenas principais (main, test_arena)
```

## Como Executar

1. Instale o [Godot 4.3+](https://godotengine.org/download)
2. Abra o Godot
3. Clique em "Import" e selecione a pasta do projeto
4. Abra a cena `res://scenes/main.tscn`
5. Pressione F5 ou clique no botão Play

## Controles

| Ação | Tecla |
|------|-------|
| Movimento | WASD |
| Olhar | Mouse |
| Pular | Space |
| Correr | Shift |
| Atirar | Mouse Esquerdo |
| Recarregar | R |
| Pausar/Liberar Mouse | ESC |

## Arquitetura Técnica

### Managers (Singletons)

- **GameManager**: Gerencia estado do jogo, timer, vitória/derrota
- **SpawnManager**: Controla spawn de inimigos
- **AudioManager**: Gerencia sons e música

### Sistema de Armas

- **BaseWeapon**: Classe base abstrata com sistema de tiro raycast
- **Pistol**: Herda de BaseWeapon, arma inicial

### Sistema de Inimigos

- **BaseEnemy**: Classe base com pathfinding e combate
- **Zombie**: Inimigo melee básico

### Player

- **PlayerController**: Movimento FPS e input
- **PlayerStats**: HP e stats
- **CameraEffects**: Recoil e screen shake

## Gameplay

1. O jogo inicia com um timer de 15:00
2. O player spawna na arena com uma pistola
3. Zombies spawnam automaticamente
4. Sobreviva e elimine inimigos
5. O jogo termina quando o timer chega a 0:00 ou o player morre

## Configurações

Todas as variáveis importantes estão marcadas como `@export` e podem ser editadas no Inspector do Godot:

- Stats do player (HP, velocidade)
- Stats das armas (dano, fire rate, ammo)
- Stats dos inimigos (HP, velocidade, dano)

## Próximos Passos Recomendados

### Fase 2 - Combat Loop
1. Adicionar mais tipos de inimigos
2. Implementar sistema de ondas
3. Adicionar drops de munição/vida
4. Implementar sistema de score

### Fase 3 - Boss System
1. Implementar mini-bosses
2. Sistema de spawns em timings específicos
3. Sistema de chaves
4. Boss final

### Fase 4 - Upgrade System
1. Sistema de upgrades
2. Transformações visuais das armas
3. Upgrades ativos e passivos

### Fase 5 - Weapon Variety
1. Dual pistols
2. SMG
3. Shotgun
4. Sniper
5. LMG

### Fase 6 - Procedural Generation
1. Gerador procedural de mapas
2. Sistema de rooms
3. Variação de layouts

## Debug

- O mouse é capturado automaticamente ao iniciar
- Pressione ESC para liberar o mouse (útil para debug)
- O NavigationMesh pode precisar ser re-baked se modificar a arena
  - Selecione NavigationRegion3D na cena
  - Clique em "Bake NavigationMesh" no topo

## Requisitos

- Godot 4.3 ou superior
- GDScript
- Vulkan renderer
- PC (Windows/Linux)

## Licença

Este projeto é para fins educacionais.
