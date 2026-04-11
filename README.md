# ClariceOS

ClariceOS é uma distribuição Linux baseada em Arch Linux, com foco em usabilidade e estética coesa. Vem com instalador gráfico completo, tema **Fluent** no GNOME e **Layan-kde** no KDE, além de identidade Clarice no terminal/boot splash, suporte a GNOME e KDE Plasma, bootloader Limine moderno e suporte nativo a btrfs com snapshots automáticos.

---

## Características

### Sistema base
| Componente | Detalhe |
|---|---|
| **Base** | Arch Linux (x86_64) |
| **Kernel** | `linux` + `linux-zen` (baixa latência, melhor para desktop/gaming) |
| **Instalador** | Calamares com interface gráfica completa |
| **Bootloader** | Limine (BIOS e UEFI) |
| **Áudio** | PipeWire + WirePlumber (Bluetooth, JACK e PulseAudio compatíveis) |
| **Swap comprimida** | zRAM com ZSTD (até 4 GB) |
| **Firewall** | firewalld ativo por padrão (zona public) |
| **Firmware** | fwupd para atualização de BIOS/SSD/periféricos |
| **Apps containerizados** | Flatpak + Flathub + Distrobox + Podman |
| **Segurança** | AppArmor (MAC) + Secure Boot via sbctl |

### Visual — Fluent (GNOME) + Layan-kde (KDE)
| Componente | Detalhe |
|---|---|
| **Tema GTK (GNOME)** | Fluent-Dark (GTK3 + GTK4) |
| **Tema de ícones** | Tela-dark |
| **Tema de cursor** | Adwaita |
| **Fonte do sistema** | JetBrains Mono 11 (UI, monospace, documentos) |
| **Terminal** | Kitty — tema Clarice completo, tab bar powerline |
| **Fonte do terminal** | JetBrainsMono Nerd Font 12pt |
| **Shell** | ZSH + autosuggestions + syntax-highlighting + history-substring-search |
| **Prompt** | Starship — paleta Clarice (diretório cyan, branch pink, `❯` green) |
| **Boot splash** | Plymouth tema `clariceos` (fundo `#282a36`, barra `#bd93f9`) |
| **KDE** | Layan-kde via kdeglobals, plasmarc e kwinrc |
| **GNOME** | Fluent-Dark via dconf system-wide database |

### Gaming (opcional)
- Steam, Proton, MangoHUD, GameMode, Lutris, wine, winetricks
- Detecção automática de GPU NVIDIA/AMD/Intel com instalação de drivers

### Gerenciamento de pacotes
| Ferramenta | Descrição |
|---|---|
| `pacman` | Gerenciador oficial do Arch Linux |
| `yay` | AUR helper em linha de comando |
| `pamac` / `pamac-aur` | Interface gráfica para pacman + AUR (instalada automaticamente no sistema final) |
| **Chaotic-AUR** | Repositório de pacotes AUR pré-compilados |

---

## Ambientes de Desktop

### GNOME (padrão, offline)
Instalado por padrão sem necessidade de internet. Inclui:
- GNOME Shell + GDM
- Nautilus, GNOME Text Editor, EOG
- Tema Fluent-Dark aplicado via dconf system-wide database
- Kitty como terminal padrão (`org.gnome.desktop.default-applications.terminal`)
- JetBrains Mono 11 em `font-name`, `monospace-font-name`, `document-font-name` e `titlebar-font`
- Ícones Tela-dark

### KDE Plasma (opcional, requer internet)
Selecionável na tela de netinstall. Inclui:
- Plasma Desktop + Plasma Login Manager
- Dolphin, Kate, KCalc e Falkon (navegador padrão no KDE)
- Kitty como terminal padrão (`TerminalApplication=kitty`)
- Layan-kde aplicado via kdeglobals/plasmarc/kwinrc com JetBrains Mono
- Ícones Tela-dark

---

## Shell: ZSH + Starship

O ClariceOS usa **ZSH** como shell padrão para todos os usuários, com os seguintes componentes instalados via repositórios oficiais do Arch:

| Pacote | Função |
|---|---|
| `zsh-autosuggestions` | Sugestão automática do histórico |
| `zsh-syntax-highlighting` | Colorização de comandos em tempo real |
| `zsh-history-substring-search` | Busca no histórico por prefixo com ↑↓ |
| `zsh-completions` | Completions extras para centenas de comandos |
| `starship` | Prompt rápido escrito em Rust |

O prompt **Starship** usa a paleta Clarice completa e exibe: diretório, branch git, status git, linguagem do projeto e duração do último comando.

---

## Terminal: Kitty

- **Emulador:** Kitty (GPU-accelerated)
- **Fonte:** JetBrainsMono Nerd Font 12pt (suporte completo a ícones Nerd Font)
- **Tema:** Clarice — cores alinhadas com todo o sistema (borda ativa `#bd93f9`, marks com cores do accent)
- **Tab bar:** powerline style, cores Clarice
- **Scrollback:** 10.000 linhas
- Configurado como terminal padrão no GNOME (dconf) e KDE (kdeglobals)
- `TERMINAL=kitty` em `/etc/environment`

---

## Boot Splash: Plymouth

O ClariceOS usa o tema `clariceos` (módulo `script` do Plymouth):

- **Fundo:** `#282a36` (Clarice background)
- **Barra de progresso:** `#bd93f9` (Clarice accent)
- **Trilho da barra:** `#44475a` (Clarice neutral)
- **Texto:** `#f8f8f2` (Clarice foreground)

Os assets PNG são gerados automaticamente via Python3 stdlib durante o build da ISO.

---

## Bootloader: Limine

O ClariceOS utiliza o [Limine](https://limine-bootloader.org/) no lugar do GRUB:

- **BIOS:** instalado no MBR do disco alvo
- **UEFI:** binário `BOOTX64.EFI` copiado para a ESP, entrada registrada via `efibootmgr`
- Configuração gerada automaticamente em `limine.cfg` com entradas para kernel principal e fallback

### Suporte a btrfs + snapshots

Quando o sistema de arquivos root é **btrfs**, o instalador configura automaticamente:

- Subvolumes: `@` (root), `@home`, `@log`, `@pkg`
- **snapper** com timers automáticos (timeline + cleanup)
- **snap-pac** para snapshots automáticos em transações do pacman
- **limine-snapper-sync** (AUR) — gera entradas de boot para cada snapshot, permitindo rollback direto pelo menu do Limine

Para sistemas **ext4**, o **Timeshift** é configurado no modo rsync com snapshots semanais e mensais.

---

## Instalador

O instalador gráfico Calamares guia o usuário pelos seguintes passos:

1. **Boas-vindas** — verificação de requisitos mínimos
2. **Localização** — idioma, fuso horário e teclado
3. **Particionamento** — manual ou automático, com suporte a ext4, btrfs, xfs e f2fs
4. **Usuário** — criação de conta e senha
5. **Perfil de uso** — escolha entre Desktop, Gaming, Desenvolvimento e opcionais de driver
6. **Ambiente gráfico (DE)** — escolha entre GNOME (offline) ou KDE Plasma (requer internet)
7. **Resumo** — revisão antes de instalar
8. **Instalação** — cópia do sistema, bootloader, pós-configuração automática

### Pós-instalação automática (`configure-de.sh`)
O script executa dentro do chroot do sistema instalado e realiza:
- Configuração do display manager (GDM ou Plasma Login Manager)
- Instalação e registro do tema Tela-dark e Plymouth `clariceos`
- Instalação do tema KDE **Layan-kde** quando a opção KDE é escolhida
- Detecção de GPU e instalação de drivers (NVIDIA dkms, AMD Vulkan, Intel media)
- Configuração do Chaotic-AUR e instalação automática do Pamac (`pamac`/`pamac-aur`, com fallback)
- Adição do Flathub ao Flatpak
- `chsh -s zsh` para todos os usuários e root
- Aplicação de dotfiles (kitty, starship, zsh, GTK, KDE) para cada usuário, com perfil KDE (Layan-kde) forçado para primeiro boot já customizado
- Rebuild do initramfs com hook Plymouth

---

## Estrutura do Projeto

```
releng/
├── profiledef.sh              # Definições do perfil da ISO + permissões de arquivos
├── packages.x86_64            # Pacotes incluídos na ISO live
├── pacman.conf                # Configuração do pacman
├── customize_airootfs.sh      # Customização do ambiente live (temas, shell, fonte)
├── airootfs/
│   ├── etc/
│   │   ├── calamares/
│   │   │   ├── settings.conf
│   │   │   ├── branding/clariceos/        # Logo, cores e slides do instalador
│   │   │   ├── modules/                   # Configurações dos módulos Calamares
│   │   │   ├── scripts/
│   │   │   │   ├── configure-de.sh        # Pós-install: DE, temas, drivers, shell
│   │   │   │   ├── install-bootloader.sh  # Instala Limine (BIOS + UEFI)
│   │   │   │   ├── btrfs-hooks.sh         # Hook btrfs no mkinitcpio
│   │   │   │   └── setup-secureboot.sh    # Configura Secure Boot via sbctl
│   │   │   ├── netinstall-profile.yaml    # Etapa 1: perfil de uso (Desktop/Gaming/Dev/NVIDIA)
│   │   │   └── netinstall-desktop.yaml    # Etapa 2: ambiente gráfico (GNOME/KDE)
│   │   ├── dconf/db/local.d/
│   │   │   └── 00-clariceos-theme         # Defaults GNOME: Fluent-Dark, Tela-dark, Kitty, JetBrains Mono
│   │   ├── plymouth/
│   │   │   └── plymouthd.conf             # Theme=clariceos
│   │   ├── skel/.config/
│   │   │   ├── kitty/kitty.conf           # Tema Clarice + JetBrainsMono Nerd Font
│   │   │   ├── starship.toml              # Prompt Starship paleta Clarice
│   │   │   ├── gtk-3.0/settings.ini
│   │   │   ├── gtk-4.0/settings.ini
│   │   │   └── kdeglobals                 # KDE: Layan, Tela-dark, JetBrains Mono, Kitty
│   │   ├── skel/.zshrc                    # ZSH: plugins + starship init
│   │   ├── environment                    # TERMINAL=kitty, Wayland flags
│   │   └── systemd/zram-generator.conf
│   └── usr/share/plymouth/themes/clariceos/
│       ├── clariceos.plymouth
│       └── clariceos.script               # Tema Clarice para boot splash
```

---

## Compilando a ISO

### Requisitos

- Arch Linux (ou derivado)
- Pacotes: `archiso`, `git`, `curl`
- Acesso root
- Conexão com internet (necessária para baixar temas em `customize_airootfs.sh`)

### Build

```bash
git clone https://github.com/rrattes/ClariceOS.git
cd ClariceOS
sudo mkarchiso -v -w /tmp/clariceos-work -o /tmp/clariceos-out releng/
```

A ISO gerada estará em `/tmp/clariceos-out/ClariceOS-YYYY.MM.DD-x86_64.iso`.

### Testando em VM (UEFI)

```bash
qemu-img create -f qcow2 clariceos-test.img 20G

qemu-system-x86_64 \
  -enable-kvm -m 4G -smp 2 \
  -bios /usr/share/ovmf/OVMF.fd \
  -cdrom /tmp/clariceos-out/ClariceOS-*.iso \
  -drive file=clariceos-test.img,format=qcow2
```

### Testando em VM (BIOS)

```bash
qemu-system-x86_64 \
  -enable-kvm -m 4G -smp 2 \
  -cdrom /tmp/clariceos-out/ClariceOS-*.iso \
  -drive file=clariceos-test.img,format=qcow2
```

---

## Licença

Distribuído sob a licença [GPL-2.0](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html), seguindo a base do archiso.
