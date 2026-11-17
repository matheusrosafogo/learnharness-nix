# LearnHarness para Nix/NixOS

Empacota o **LearnHarness 0.6.1** (`LearnHarness-0.6.1-amd64.deb`) como um
pacote Nix, com um módulo NixOS para instalação declarativa.

O `.deb` **não** fica no repositório: ele é baixado do release oficial via
`fetchurl`, com hash fixo. Isso mantém o repositório pequeno e compatível com o
limite de 100 MB por arquivo do GitHub.

## Uso rápido

```bash
nix build
./result/bin/learnharness

# sem criar o link result
nix run .
```

## Repositório publicado

O repositório remoto é
[matheusrosafogo/learnharness-nix](https://github.com/matheusrosafogo/learnharness-nix)
(público, branch `main`). O `.deb` não é versionado. O repositório contém
apenas:

```
flake.nix
flake.lock
package.nix
default.nix
README.md
.gitignore
```

Para enviar alterações futuras:

```bash
cd /home/matheus/Projects/learnharness-nix
git status   # confirme que nenhum .deb aparece na lista
git add .
git commit -m "Atualiza LearnHarness"
git push
```

## Usar como input de flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    learnharness.url = "github:matheusrosafogo/learnharness-nix";
  };

  outputs = { self, nixpkgs, learnharness, ... }: {
    nixosConfigurations.minha-maquina = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        learnharness.nixosModules.default
        # ...
      ];
    };
  };
}
```

## Usar no NixOS clássico (o caso deste repositório)

Como o Multipass e o OnlyOffice, o flake pode ser carregado de forma impura com
`builtins.getFlake`. Em `/etc/nixos/packages/pkgs.nix`:

```nix
let
  var = import ../variables.nix;
  mp = builtins.getFlake "github:matheusrosafogo/multipass-nix";
  oo = builtins.getFlake "github:matheusrosafogo/onlyoffice-nix";
  lh = builtins.getFlake "github:matheusrosafogo/learnharness-nix";
in
{
  imports = [
    mp.nixosModules.default
    oo.nixosModules.default
    lh.nixosModules.default   # adiciona o LearnHarness ao systemPackages
  ];

  # O restante do módulo continua igual.
}
```

Também é possível instalar sem o módulo, adicionando o pacote diretamente:

```nix
environment.systemPackages = [
  lh.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Ou usar o overlay para expor `pkgs.learnharness`:

```nix
nixpkgs.overlays = [ lh.overlays.default ];
```

Para fixar um commit específico (recomendado para reprodutibilidade):

```nix
lh = builtins.getFlake "github:matheusrosafogo/learnharness-nix/SEU_COMMIT";
```

`builtins.getFlake` exige a feature experimental `flakes` habilitada. O
Multipass já usa esse mesmo recurso, então a configuração atual atende.

## Instalar no perfil do usuário

```bash
nix profile install github:matheusrosafogo/learnharness-nix
```

## Atualizar a versão

1. Descubra a nova tag no repositório
   [amosblomqvist/learnharness](https://github.com/amosblomqvist/learnharness/releases).
2. Atualize a URL em `package.nix` (`/v0.6.1/` e `version`).
3. Recalcule o hash:

   ```bash
   nix-prefetch-url --type sha256 \
     https://github.com/amosblomqvist/learnharness/releases/download/v0.6.1/LearnHarness-0.6.1-amd64.deb
   ```

   Converta para SRI com:

   ```bash
   nix hash convert --hash-algo sha256 --to sri <hash-base32>
   ```

4. Atualize `version` e o `hash` em `package.nix`.
5. Valide com `nix build` e `nix flake check`.

## Como o pacote funciona

- O `.deb` é desempacotado com `dpkg-deb -x`.
- O `autoPatchelfHook` é aplicado **somente** aos ELF de nível superior do
  Electron (`learnharness`, `chrome-sandbox`, `chrome_crashpad_handler` e as
  bibliotecas soltas). O `node_modules` embutido no servidor Next.js fica
  intocado: o `sharp` traz o próprio `libvips` com RPATH `$ORIGIN`, e reescrever
  esse RPATH quebraria o carregamento.
- Um wrapper adiciona as bibliotecas de runtime do Electron ao
  `LD_LIBRARY_PATH`, o `xdg-utils` ao `PATH` e ativa Wayland quando
  `NIXOS_OZONE_WL` e `WAYLAND_DISPLAY` estão definidos.
- O módulo NixOS apenas adiciona o pacote a `environment.systemPackages`.

## Observações

- Apenas `x86_64-linux`.
- O módulo é silenciosamente ignorado em outras arquiteturas porque o pacote
  não as suporta.
- Dados, chats, grafo e chaves de API ficam em `~/.config/LearnHarness` (fora do
  Nix store) e não são removidos ao atualizar o pacote.
- **Atualizações:** o app tem auto-update embutido do electron-updater. Em uma
  instalação Nix o diretório do app é somente leitura, então a atualização deve
  ser feita pelo Nix (novo commit/tag deste repositório ou `nix profile upgrade`).
  Enquanto a versão instalada for a mais recente do release, o updater apenas
  registra "update not available". Se quiser silenciar as verificações, desative
  a atualização automática em **Settings → General** no app.
- Se o sandbox do Chromium reclamar em algum sistema sem user namespaces, rode
  `learnharness --no-sandbox` como alternativa.
- O hash do `.deb` do release oficial é
  `sha256-LIZbewtw8c6p/EBVivA5l2i3uZZFf7b4HWKLLdJCzl0=`.
- Licença do pacote upstream: AGPL-3.0-only (binário, `sourceProvenance =
  binaryNativeCode`).

## Cache binário (opcional, recomendado)

O ambiente do app ocupa cerca de 500 MB descompactado. Para não baixar o `.deb`
e reconstruir em cada máquina:

1. Crie um cache no [Cachix](https://app.cachix.org), por exemplo
   `matheusrosafogo-learnharness`.
2. Adicione um workflow do GitHub Actions que rode `nix build` e `cachix push`.
3. Cadastre o cache em `/etc/nixos/system/substituters.nix`, como já existe
   para o Multipass.

Sem cache, a primeira instalação em outra máquina baixa o `.deb` e monta o
pacote localmente.
