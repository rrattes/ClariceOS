# ClariceOS — Arquitetura do Instalador + Pós-Instalação

Data: 2026-04-10

## 1) Objetivo do documento

Definir com clareza:

- **Fluxo atual** do instalador (Calamares) e dos scripts de pós-instalação.
- **Fluxo alvo** (roadmap) para modularidade, confiabilidade e menor risco de regressão.
- Pontos de integração entre módulos de instalação, bootloader (Limine), desktop setup e customização visual.

---

## 2) Fluxo atual (estado real)

## 2.1 Pipeline Calamares (alto nível)

A sequência principal de execução está definida em `settings.conf` e segue este encadeamento:

1. particionamento/mount/unpack
2. configuração base de sistema (fstab, locale, keyboard, hooks)
3. setup de bootloader (chroot)
4. configuração de usuários/DE/pós-install
5. deploy final do Limine fora do chroot
6. umount/finalização

### Ordem relevante para boot e pós-install

```text
... -> shellprocess@bootloader
    -> users
    -> shellprocess (configure-de.sh)
    -> shellprocess@secureboot
    -> networkcfg
    -> shellprocess@limine-deploy
    -> umount
```

Essa ordem garante que o `limine.cfg` e demais artefatos sejam gerados no sistema-alvo, e o deploy final em disco/EFI ocorra no host live antes do unmount.

## 2.2 Bootloader (Limine)

### Passo A — `install-bootloader.sh` (chroot)

Responsável por:

- detectar root device/UUID e tipo de FS;
- resolver disco físico alvo para instalação BIOS;
- gerar `limine.cfg` para UEFI/BIOS;
- instalar arquivos EFI/MBR conforme modo de boot;
- integrar snapshots em btrfs com `snapper` + `limine-snapper-sync`.

### Passo B — `limine-deploy.sh` (fora do chroot)

Responsável por:

- executar a escrita final do bootstrap BIOS no MBR com acesso direto ao bloco;
- garantir cópia/registro de EFI em UEFI;
- habilitar `limine-snapper-sync.path` no sistema instalado quando aplicável.

## 2.3 Pós-instalação de desktop (`configure-de.sh`)

Responsável por:

- selecionar display manager com base no DE instalado;
- aplicar defaults GNOME/KDE;
- instalar temas (Fluent para GNOME, Layan-kde para KDE, Tela icons);
- configurar shell/zsh para usuários e root;
- configurar Chaotic-AUR;
- instalar Pamac com fallback (`pamac` -> `pamac-aur` -> `yay`);
- configurar Flatpak/Flathub;
- detectar GPU e instalar drivers.

---

## 3) Principais problemas de arquitetura no estado atual

1. **Script monolítico no pós-install** (`configure-de.sh`) concentra muitas responsabilidades.
2. **Acoplamento alto entre tema, pacote, driver e shell** na mesma etapa.
3. **Baixa observabilidade**: logs são informativos, mas sem estrutura padronizada por etapa/resultado.
4. **Validação funcional depende de QA manual** (falta suíte de validação por cenário de instalação).

---

## 4) Fluxo alvo (arquitetura desejada)

## 4.1 Princípios

- **Idempotência**: reexecução segura sem efeitos colaterais imprevisíveis.
- **Modularidade**: cada área (DE, tema, boot, pacotes, segurança) em módulo separado.
- **Observabilidade**: logs padronizados por etapa (`START/OK/WARN/FAIL`).
- **Fail-soft controlado**: continuar onde for não crítico, falhar cedo no que impacta boot.

## 4.2 Estrutura alvo de módulos pós-install

```text
/etc/calamares/scripts/postinstall/
  10-display-manager.sh
  20-gnome-theme.sh
  21-kde-theme.sh
  30-shell-defaults.sh
  40-repositories.sh
  41-pamac.sh
  50-flatpak.sh
  60-gpu-drivers.sh
  70-security.sh
  80-finalize.sh
```

`configure-de.sh` passa a ser apenas orquestrador chamando módulos em ordem.

## 4.3 Contratos de módulo

Cada módulo deve:

- exportar código de saída claro (0 sucesso, >0 erro);
- registrar logs em `/var/log/clariceos-postinstall.log`;
- aceitar variáveis de contexto (`GNOME_INSTALLED`, `KDE_INSTALLED`, `UEFI`, etc.);
- não alterar arquivos fora de seu escopo sem justificativa.

---

## 5) Riscos e mitigação

### Risco A: regressão de boot
- Mitigação: preservar dupla etapa Limine (chroot + outside-chroot) e testes BIOS/UEFI em cada release.

### Risco B: inconsistência visual GNOME/libadwaita
- Mitigação: validar presença de assets `gtk-4.0` do tema e manter fallback definido.

### Risco C: fragilidade de rede (download de temas)
- Mitigação: fallback explícito para tema padrão e logs claros para suporte.

---

## 6) Matriz mínima de validação (por release)

1. GNOME offline + boot OK
2. KDE online + tema aplicado no primeiro login
3. BIOS install + boot Limine
4. UEFI install + boot Limine
5. btrfs + snapper + limine-snapper-sync
6. ext4 + fluxo sem snapshot
7. NVIDIA/AMD/Intel (ao menos 1 cenário por release)

---

## 7) Entregáveis da fase 1 (este ciclo)

1. Documento de arquitetura (este arquivo)
2. Refatoração incremental para modelo modular (sem quebrar fluxo atual)
3. Checklist de QA com evidências por cenário
4. Critério de aceite para "instala e boota" antes de merge

---

## 8) Critério de aceite do documento

- Fluxo atual e fluxo alvo descritos;
- Mapeamento claro de responsabilidades por script;
- Riscos e mitigação documentados;
- Matriz mínima de validação definida.

---

## 9) Fluxo de melhorias no Calamares (proposta prática)

Este é o fluxo sugerido para implementar as melhorias sem quebrar o instalador:

## 9.1 Fluxo da interface (wizard)

1. **Welcome**
   - Exibir checks de pré-requisito (UEFI/BIOS, RAM, rede).
2. **Locale/Keyboard**
   - Manter como está.
3. **Partition**
   - Manter, mas com dicas contextuais para btrfs/ext4.
4. **Users**
   - Incluir aviso de autologin pós-instalação quando aplicável.
5. **Perfis (novo)**
   - Substituir seleção “solta” por perfis: Base, Dev, Gaming, Creator.
6. **Desktop Choice**
   - Escolha exclusiva GNOME ou KDE com resumo visual do tema aplicado.
7. **Resumo**
   - Mostrar claramente: bootloader, FS, DE, perfil, repositórios extras.

## 9.2 Fluxo de execução (backend)

```text
partition -> mount -> unpackfs
-> machineid/fstab/locale/keyboard
-> netinstall (perfil + DE)
-> shellprocess@bootloader (chroot)
-> users
-> shellprocess (orquestrador pós-install)
   -> 10-display-manager
   -> 20-theme-gnome | 21-theme-kde
   -> 30-shell
   -> 40-repos
   -> 41-pamac
   -> 50-flatpak
   -> 60-drivers
   -> 70-security
-> shellprocess@secureboot
-> shellprocess@limine-deploy (outside chroot)
-> umount
```

## 9.3 Estratégia de rollout (PRs pequenos)

- **PR 1**: módulos de tema (sem alterar pacotes).
- **PR 2**: perfis de netinstall.
- **PR 3**: modularização do `configure-de.sh` (orquestrador + includes).
- **PR 4**: observabilidade (log único + status por etapa).
- **PR 5**: QA matrix automatizada (smoke em VM).

## 9.4 Critérios de aceite por fase

- **Fase UI**: usuário entende em 1 tela o que será instalado.
- **Fase Backend**: reexecução não quebra estado (idempotência).
- **Fase Boot**: BIOS/UEFI com boot confirmado.
- **Fase DE**: GNOME/KDE sobem já com tema correto no primeiro login.

## 9.5 Status da trilha (iniciado)

- ✅ **PR 1 iniciado**: temas extraídos para módulos dedicados (`20-theme-gnome.sh` e `21-theme-kde.sh`) com `configure-de.sh` atuando como orquestrador.
- ✅ **PR 2 iniciado**: repositórios/pacotes extraídos para módulos (`40-repositories.sh`, `41-pamac.sh`, `50-flatpak.sh`).
- ⏳ Próximo passo: separar módulos de shell/drivers mantendo comportamento atual.
