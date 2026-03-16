# ClariceOS

ClariceOS é uma distribuição Linux baseada em Arch Linux, com foco em usabilidade e estética. Vem com instalador gráfico completo, tema Dracula por padrão, suporte a GNOME e KDE Plasma, bootloader Limine moderno e suporte nativo a btrfs com snapshots automáticos.

---

## Características

- **Base:** Arch Linux (x86_64)
- **Instalador:** Calamares com interface gráfica completa
- **Bootloader:** Limine (BIOS e UEFI)
- **Ambientes de desktop:** GNOME (padrão) ou KDE Plasma (opcional)
- **Tema:** Dracula em GTK3, GTK4, GNOME Shell e KDE Plasma
- **Sistema de arquivos:** ext4, btrfs, xfs, f2fs
- **Gerenciador de pacotes:** pacman + yay (AUR) + pamac (GUI)
- **Snapshots:** snapper + limine-snapper-sync (btrfs) / Timeshift rsync (ext4)
- **Áudio:** PipeWire + WirePlumber (Bluetooth, JACK e PulseAudio compatíveis)
- **Swap comprimida:** zRAM com ZSTD (até 4 GB, melhora performance com pouca RAM)
- **Firewall:** firewalld ativo por padrão (zona public)
- **Firmware:** fwupd para atualização de BIOS/SSD/periféricos
- **Apps containerizados:** Flatpak + Flathub + Distrobox + Podman
- **Gaming:** grupo opcional com Steam, Proton, MangoHUD, GameMode, Lutris
- **GPU:** detecção automática de NVIDIA/AMD/Intel com instalação de drivers
- **Boot splash:** Plymouth com tema bgrt
- **Wayland:** portais XDG, Qt5/Qt6 Wayland, MOZ_ENABLE_WAYLAND

---

## Instalador

O instalador gráfico Calamares guia o usuário pelos seguintes passos:

1. **Boas-vindas** — verificação de requisitos mínimos
2. **Localização** — idioma, fuso horário e teclado
3. **Particionamento** — manual ou automático, com suporte a ext4, btrfs, xfs e f2fs
4. **Usuário** — criação de conta e senha
5. **Ambiente de desktop** — escolha entre GNOME e KDE Plasma
6. **Resumo** — revisão antes de instalar
7. **Instalação** — cópia do sistema, bootloader, configuração de serviços

---

## Ambientes de Desktop

### GNOME (padrão, offline)
Instalado por padrão sem necessidade de internet. Inclui:
- GNOME Shell + GDM
- Nautilus, GNOME Terminal, GNOME Text Editor
- Tema Dracula no GTK3, GTK4 e GNOME Shell via dconf

### KDE Plasma (opcional, requer internet)
Selecionável na tela de netinstall. Inclui:
- Plasma Desktop + SDDM
- Dolphin, Konsole, Kate, KCalc
- Tema Dracula via kdeglobals, plasmarc, kwinrc e breezerc

---

## Bootloader: Limine

O ClariceOS utiliza o [Limine](https://limine-bootloader.org/) no lugar do GRUB:

- **BIOS:** instalado no MBR do disco alvo
- **UEFI:** binário `BOOTX64.EFI` copiado para a ESP, entrada registrada via `efibootmgr`
- Configuração gerada automaticamente em `limine.cfg` com entradas para kernel principal e fallback

### Suporte a btrfs + snapshots

Quando o sistema de arquivos root é **btrfs**, o instalador configura automaticamente:

- Subvolumes: `@` (root), `@home`, `@log`, `@pkg`
- **snapper** com configuração para o root e timers automáticos (timeline + cleanup)
- **snap-pac** para snapshots automáticos em transações do pacman
- **limine-snapper-sync** (AUR) — monitora `/.snapshots/` e gera entradas de boot para cada snapshot, permitindo rollback direto pelo menu do Limine

---

## Gerenciamento de Pacotes

| Ferramenta | Descrição |
|---|---|
| `pacman` | Gerenciador oficial do Arch Linux |
| `yay` | AUR helper em linha de comando |
| `pamac` | Interface gráfica para pacman e AUR |

O **pamac** é instalado automaticamente no pós-instalação com AUR habilitado (`EnableAUR = true`).

---

## Estrutura do Projeto

```
releng/
├── profiledef.sh              # Definições do perfil da ISO
├── packages.x86_64            # Pacotes incluídos na ISO live
├── pacman.conf                # Configuração do pacman
├── customize_airootfs.sh      # Script de customização do ambiente live
├── airootfs/
│   └── etc/
│       ├── calamares/
│       │   ├── settings.conf           # Sequência do instalador
│       │   ├── branding/clariceos/     # Branding do Calamares
│       │   ├── modules/                # Configurações dos módulos
│       │   │   ├── partition.conf
│       │   │   ├── mount.conf          # Subvolumes btrfs
│       │   │   ├── fstab.conf
│       │   │   ├── packages.conf
│       │   │   ├── shellprocess@bootloader.conf
│       │   │   ├── shellprocess@btrfshooks.conf
│       │   │   └── ...
│       │   ├── scripts/
│       │   │   ├── install-bootloader.sh   # Instala Limine
│       │   │   ├── configure-de.sh         # Configura DE + tema + pamac
│       │   │   └── btrfs-hooks.sh          # Injeta hook btrfs no mkinitcpio
│       │   └── netinstall.yaml             # Grupos GNOME / KDE
│       ├── os-release
│       └── hostname
```

---

## Compilando a ISO

### Requisitos

- Arch Linux (ou derivado)
- Pacotes: `archiso`, `git`
- Acesso root

### Build

```bash
git clone https://github.com/rrattes/ClariceOS.git
cd ClariceOS
sudo mkarchiso -v -w /tmp/clariceos-work -o /tmp/clariceos-out releng/
```

A ISO gerada estará em `/tmp/clariceos-out/ClariceOS-YYYY.MM.DD-x86_64.iso`.

### Testando em VM (UEFI)

```bash
# Criar disco virtual
qemu-img create -f qcow2 clariceos-test.img 20G

# Iniciar VM UEFI
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
