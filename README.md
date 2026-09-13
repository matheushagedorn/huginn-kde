# Huginn

Uma shell de desktop em [QuickShell](https://quickshell.outfoxxed.me/) para **KDE Plasma 6 no Wayland**,
com a paleta Tokyo Night.

Huginn é um dos corvos de Odin: voa pelo mundo e volta contando o que viu. É mais
ou menos o que uma barra de status faz.

> A maioria dos rices de QuickShell por aí é feita para Hyprland ou Niri. Este
> roda **sobre o KDE Plasma**, convivendo com o KWin em vez de substituí-lo.

## O que vem junto

- **Barra superior** — clima, relógio com calendário, player de mídia, bandeja
  do sistema, volume, brilho, rede e Bluetooth.
- **Dock inferior** com auto-hide — apps fixados e janelas abertas, separados
  por um divisor, com preview de janelas ao clicar e reordenação por arrastar.
- **Launcher de aplicativos** com busca e calculadora embutida.
- **OSD** de volume e brilho.
- **Widget de monitoramento** no desktop — CPU, GPU, memória, disco e rede, com
  gráficos e leitura real do hardware (nada fixo no código).
- **Motor de temas** que propaga a paleta para GTK, Konsole, Alacritty, btop,
  Starship, VS Code e outros.

## Requisitos

- KDE Plasma 6 em sessão **Wayland**
- [QuickShell](https://quickshell.outfoxxed.me/) instalado (`quickshell` no AUR)
- PipeWire + WirePlumber
- Python 3 com `python-dbus` (obrigatório: sem ele o dock não enxerga janelas abertas)

O instalador tenta resolver o resto (`playerctl`, `brightnessctl`, `ddcutil`,
`wl-clipboard`, `papirus-icon-theme`, `fastfetch`, entre outros) via `pacman`,
`dnf` ou `apt`, e avisa explicitamente o que faltou em vez de falhar em silêncio.

## Instalação

```bash
git clone https://github.com/<seu-usuario>/huginn.git ~/Projects/huginn
cd ~/Projects/huginn
./install.sh
```

O `~/.config/quickshell` vira um symlink para o repositório, então `git pull`
atualiza a configuração direto. Configurações que já existiam são movidas para
`.bak.<timestamp>` em vez de sobrescritas.

Depois da instalação, falta só um passo manual: criar os atalhos de teclado em
**System Settings → Keyboard → Shortcuts → Add New → Command or Script**,
apontando para os scripts em `~/.local/bin/huginn-*`. O instalador imprime a
lista no fim.

Para a dock não brigar por espaço com o painel do KDE, remova o painel nativo
(clique direito nele → Remove Panel).

## Personalização

- **Monitor** — as janelas são fixadas em um monitor específico (por padrão,
  `DP-2`). Se o seu tiver outro nome (`kscreen-doctor -o` lista), ajuste a linha
  `screen:` em `quickshell/shell.qml` e nos módulos de launcher e lockscreen.
- **Tema** — o tema ativo fica em `~/.config/quickshell_current_theme.txt`.
  As paletas disponíveis estão em `quickshell/theme/Theme.qml` (Tokyo Night,
  Catppuccin, Gruvbox, Nord, Rosé Pine, Everforest, Solarized e outras).
- **Apps fixados na dock** — editáveis por arrastar, ou em
  `quickshell/services/TaskService.qml`.

## Limitações conhecidas

- **A tela de bloqueio não é tematizável.** Nas versões recentes do Plasma, o
  greeter só expõe wallpaper, relógio e controles de mídia
  (System Settings → Security & Privacy → Screen Locking). E o protocolo de
  session lock do Wayland impede que qualquer aplicação comum desenhe por cima
  da tela travada, então uma tela de bloqueio própria não é possível aqui.
- **OSD de volume duplicado.** Quem dispara o OSD nativo do Plasma é o módulo
  `audioshortcutsservice` do `kded`, que também processa as teclas de volume.
  O instalador oferece desativá-lo; aí as teclas passam a ser reapontadas para
  os scripts do Huginn.
- **Widget de monitoramento fica atrás das janelas**, por design (camada
  `Bottom`, como um Conky). Só aparece com a área de trabalho livre.

## Licença

[MIT](LICENSE), cobrindo as modificações e adições deste repositório. O projeto
de origem foi publicado sem licença explícita — o material herdado dele segue
sob os termos do autor original.

## Créditos

Derivado de [Isshi0417/quickshell-rice](https://github.com/Isshi0417/quickshell-rice),
com correções e mudanças substanciais: detecção real de hardware no lugar de
valores fixos, resolução de monitor em todas as janelas, menu de contexto e
arraste da dock funcionando, dock com auto-hide, indicadores que só aparecem se
o hardware existir, e a remoção do escalonamento por `sudo` que o instalador
original disparava em loop.
