# Análise: inclusão de KDE Plasma no instalador com foco no novo gerenciador de janelas

## Situação atual
O instalador já possui a opção **KDE Plasma** no `netinstall.yaml`.

## Objetivo
Fortalecer a opção KDE para o cenário atual do Plasma (Wayland + KWin), reduzindo ambiguidade de sessão após instalação.

## Ajustes aplicados
1. **Netinstall KDE atualizado** para destacar Plasma 6 com KWin/Wayland.
2. Inclusão explícita de `plasma-workspace` e `kwin` na seleção KDE para garantir componentes centrais da sessão.
3. No `configure-de.sh`, o instalador habilita `plasmalogin.service` (Plasma Login Manager) em vez de SDDM para instalações KDE.

## Benefícios
- Melhora a clareza para o usuário no momento da instalação.
- Reduz risco de pós-instalação abrir em sessão inesperada.
- Mantém compatibilidade: se a sessão Wayland não existir, não força sessão inválida.

## Riscos / Observações
- Dependências podem variar conforme snapshot dos repositórios Arch no momento do build.
- Em ambientes com drivers proprietários e hardware antigo, Wayland pode exigir ajustes adicionais.

## Próximos passos sugeridos
- Validar em VM com duas execuções: opção GNOME e opção KDE.
- Confirmar tela de login do Plasma Login Manager iniciando sessão Plasma conforme esperado.
- (Opcional) adicionar teste smoke específico para presença de `/usr/share/wayland-sessions/plasma.desktop` no sistema instalado.
