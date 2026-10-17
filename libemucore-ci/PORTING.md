# Jak dostat nejnovější PCSX2 do `libemucore.so` (porting roadmapa)

Stav zjištěný v říjnu 2026:
- **Upstream PCSX2** (2.6.x stable / 2.7 nightly) je desktop (Win/macOS/Linux); Android target nemá. Nativní ARM64 dynarec je v upstreamu zatím **částečný** (`pcsx2/arm64/`: VIF dynarec + NEON + stuby; EE/VU/IOP JIT jsou pořád x86-64).
- **ARMSX2** ([ARMSX2/ARMSX2](https://github.com/ARMSX2/ARMSX2)) je aktivní GPLv3 fork PCSX2 pro ARM64 (Android/iOS/macOS/Linux/Win-ARM), dnes na **jádru PCSX2 2.7** s vlastním **nativním ARM64 JIT** („Refresh" řada) + `pcsx2-libretro` core. Dělá přesně to, co popisuje Cesta 2 níže. (Pozor: projekt má kontroverzní reputaci — spory o původu kódu; přebírat z něj kód obezřetně a s atribucí.)
- **NetherSX2-classic** běží na AetherSX2 jádře (PCSX2 1.7-dev linie) a volá ho přes JNI `xyz.aethersx2.android.NativeLibrary` (33 metod + `JNI_OnLoad`/`Unload`).

## Cesta 1 — rebase v rámci 1.7 linie (ponechat `libAetherSX2.a`)

*rychlejší, ale se stropem ~konec 1.7-dev (2023); žádné 2.x*

Uzavřený `pcsx2/libAetherSX2.a` je přeložený proti interní C++ ABI tehdejšího PCSX2
(`Host::*`, `GSDevice`, `BaseVUmicroCPU::ExecuteBlock`, `ApplyLoadedPatches`, `CDVDsys_*`, …).
Dokud tyto symboly zůstanou linkovatelné a ABI-stabilní, lze jádro aktualizovat
cherry-picky z upstreamu a `.a` se dále slinkuje beze změn.

1. **ABI kontrakt**: `nm --undefined-only pcsx2/libAetherSX2.a | c++filt` = přesný seznam
   symbolů, které jádro musí poskytovat. Ulož jako checklist a hlídej při každém rebase.
2. `git remote add upstream https://github.com/PCSX2/pcsx2` v našem build stromu,
   cherry-pick fixů (GS, EE/VU, GameDB) — vyhýbej se commitům, které mění zmíněná rozhraní.
3. Build v CI (pipeline v tomto repu to umí) → test v NetherSX2-classic.

## Cesta 2 — nový JNI můstek na PCSX2 2.x (skutečně „nejnovější")

*řádově týdny práce; výsledek = moderní jádro v NetherSX2 UI*

Proč nelze použít `libAetherSX2.a`: neobsahuje jen JNI můstek, ale i Vulkan GS device
a kousky ARM dynarecu — vše přeložené proti starému ABI. S 2.x jádrem se to neslinkuje
(jiné třídy, jiná rozhraní). Můstek se tedy píše znovu a `.a` se nepoužije vůbec.

Stavby:
1. **Jádro**: PCSX2 2.x cross-build pro Android arm64 (CMake + NDK, bez `pcsx2-qt`).
   Vzor/citace: ARMSX2 (GPLv3, stejná licence jako PCSX2 — přebírání kódu je legální
   s atribucí a povinností dodat zdrojáky při distribuci).
2. **JNI bridge** — implementovat 33 exportů z `libemucore-ci/scripts/expected_exports.txt`
   (ten soubor je přesná specifikace; `verify_so.py` v CI ji pohlídá) + směr native→Java:
   `FileHelper` (soubory), OSD zprávy, progress callbacky, `changeSurface` lifecycle.
3. **Nastavení**: mapa klíčů SharedPreferences (app) ↔ ini klíče PCSX2 2.x (hodně se
   přejmenovaly a přestěhovaly) — nutná překladová tabulka.
4. **Render**: moderní open-source Vulkan GS → `ANativeWindow`/HostDisplay glue;
   GLES fallback volitelný (AetherSX2 GL byl pro GLES upravený — moderní GS čeká desktop GL).
5. **Audio/vstup**: cubeb (má AAudio backend) + mapa `setPadAxis`/`setPadButton`
   na InputManager.
6. **GameList/BIOS/savestaty/patche**: mapovat na `System`/`GameList` API.
   ⚠ Savestaty z NetherSX2 (staré jádro) novým jádrem **nenahraješ** — jiný formát.

První milník (doporučený): v appce nabootovat hru — tj. `initialize`, `changeSurface`,
`runVMThread`, pad — a iterovat dál (nastavení, savestaty, GameList…).

## Cesta 3 — pragmatická: použít ARMSX2

Pokud cílem je „hrát s nejnovějším jádrem", ne „zůstat v NetherSX2 UI":
ARMSX2 dnes nabízí PCSX2 2.7 jádro + nativní ARM64 JIT, APK na GitHubu i Play Storu,
nightly přes GitHub Actions. Není to ale frontend NetherSX2-classic.

## Doporučení

- Trváš na NetherSX2-classic UI → **Cesta 2** (začít scaffoldem JNI bridge + CI buildem
  2.x jádra; `expected_exports.txt` slouží jako smlouva o rozhraní).
- Jde o jádro / co nejlepší emulaci → **Cesta 3**.
- Chceš jen postupné vylepšení dnešního buildu → **Cesta 1**.

Licenční poznámka: PCSX2 i ARMSX2 jsou GPLv3 — osobní build v pohodě; při jakékoliv
distribuci APK s takovým jádrem musíš dodat zdrojáky (a nepoužívat uzavřený
`libAetherSX2.a`, který je CC BY-NC-ND — Cesta 2 ho tím pádem nesmí obsahovat).
